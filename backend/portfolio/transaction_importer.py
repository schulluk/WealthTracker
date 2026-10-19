"""Shared transaction importer.

One place that turns broker ``TransactionInfo`` entries into ``Transaction`` rows,
idempotently. Used by the sync path after the balance snapshot, for every integration
that reports ``supports_transactions()``.

Dedup strategy (per account):
- Entries with a bank-side unique reference (camt.053 ``AcctSvcrRef``, a real MT940
  bank reference) get ``ref:<reference>`` as their key — exact, order-independent.
- Entries without one get a content hash over (booking date, amount, currency,
  counterparty, counterparty account, description) plus an *ordinal*: the occurrence
  index of that exact tuple within the fetched batch. Two identical coffee purchases
  on the same day therefore both survive, while re-importing an overlapping statement
  range maps them onto the same keys again. This relies on sources delivering whole
  booked days (camt.053 and MT940 statements do), so the ordinals are reproducible.
"""
import hashlib
import logging
import re
from collections import Counter
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

# How far back to ask on the first import of an account.
DEFAULT_LOOKBACK_DAYS = 365
# Re-request this many days before the newest imported transaction so late-booked
# entries around the boundary are not missed. Dedup makes the overlap free.
OVERLAP_DAYS = 5

# A backfill counts as truncated when the oldest entry the bank served is more than
# this many days after the requested start. Slack, because an account legitimately
# opened mid-window — or simply quiet over the new year — is not a truncation.
TRUNCATION_SLACK_DAYS = 31

# Broker integration_type -> Transaction.source
_SOURCE_BY_INTEGRATION_TYPE = {
    'ebics': 'camt053',
    'fints': 'fints',
}


def _content_hash(info, ordinal: int) -> str:
    payload = '|'.join([
        info.booking_date.isoformat(),
        str(info.amount),
        info.currency,
        info.counterparty,
        info.counterparty_account,
        info.description,
        str(ordinal),
    ])
    return 'h:' + hashlib.sha256(payload.encode()).hexdigest()[:40]


def _dedup_keys(infos):
    """Compute the per-entry dedup keys for one fetched batch, in order."""
    seen_counts = {}
    keys = []
    for info in infos:
        if info.external_id:
            keys.append(f'ref:{info.external_id}'[:128])
            continue
        tuple_key = (
            info.booking_date, str(info.amount), info.currency,
            info.counterparty, info.counterparty_account, info.description,
        )
        ordinal = seen_counts.get(tuple_key, 0)
        seen_counts[tuple_key] = ordinal + 1
        keys.append(_content_hash(info, ordinal))
    return keys


# Two feeds describing ONE payment share most words ("Debit TWINT: ALTERMATT,
# MANUEL +41…" vs "Belastung TWINT: ALTERMATT, MANUEL +41…" ≈ 0.67). Two
# DIFFERENT payments that merely share a day and an amount do not — two Riester
# contracts debiting 10 EUR on the 1st share only the word "Riester" (≈ 0.33).
# Below this threshold, an entry is treated as its own payment: a visible
# duplicate is recoverable, a silently dropped transaction is not.
SIMILARITY_THRESHOLD = 0.4

# Two feeds can book one payment a day or two apart (ZKB's camt.053 dates the
# TWINT debit a day before the account's own CSV export does). Same-day
# matches are always paired first, so a window this wide only catches what is
# left over.
DUPLICATE_WINDOW_DAYS = 4


# Contract, card, mandate or end-to-end numbers. Two entries whose numbers are
# entirely different are different payments even when the rest of the text
# matches: two Riester contracts share the payee AND the word "Riester", and
# differ only in "05-0885318-88" vs "05-0885320-90".
_IDENTIFIER_RE = re.compile(r'\d{4,}')


def _tokens(*parts) -> set:
    """Words of a booking text, for comparing two feeds' wording of one entry."""
    text = ' '.join(parts).lower()
    return {t for t in re.split(r'[^a-z0-9äöüàéèç]+', text) if len(t) >= 3}


# A bank writes most of a booking text itself. Every ZKB card purchase reads
# "Purchase ZKB Visa Debit card no. xxxx 7890, <merchant>", so two UNRELATED
# merchants on the same card already share six words — 0.5 similarity from
# template alone, above the threshold, with the merchant name outvoted. Tokens
# that recur across this account's bookings are therefore dropped before
# comparing: identity lives in what the bank did not write.
BOILERPLATE_SHARE = 0.2
# Below this many texts the frequency is noise (three bookings at a bakery
# would make "bakery" look like template), so nothing is dropped.
BOILERPLATE_MIN_TEXTS = 8


def boilerplate_tokens(texts) -> frozenset:
    """Tokens common enough in these booking texts to be the bank's template."""
    texts = list(texts)
    if len(texts) < BOILERPLATE_MIN_TEXTS:
        return frozenset()
    counts = Counter()
    for text in texts:
        counts.update(_tokens(text))
    cutoff = max(2, int(len(texts) * BOILERPLATE_SHARE))
    return frozenset(t for t, n in counts.items() if n >= cutoff)


def _identifying(a: set, b: set, boilerplate) -> tuple:
    """Both token sets reduced to what identifies the payment.

    Falls back to the full sets when the reduction empties one side — a
    booking whose text is *only* template still has to be comparable.
    """
    a_id, b_id = a - boilerplate, b - boilerplate
    return (a_id, b_id) if a_id and b_id else (a, b)


def looks_like_same_entry(a_counterparty, a_description,
                          b_counterparty, b_description,
                          boilerplate=frozenset()) -> bool:
    """Do two booking texts describe the same payment in two feeds' wording?"""
    a_text = f'{a_counterparty or ""} {a_description or ""}'
    b_text = f'{b_counterparty or ""} {b_description or ""}'
    a_ids = set(_IDENTIFIER_RE.findall(a_text))
    b_ids = set(_IDENTIFIER_RE.findall(b_text))
    if a_ids and b_ids and not (a_ids & b_ids):
        return False  # different contract / card / reference numbers

    a, b = _tokens(a_text), _tokens(b_text)
    if not a and not b:
        # Neither side carries text — the count is the only available signal.
        return True
    if not a or not b:
        return False
    a, b = _identifying(a, b, boilerplate)
    return len(a & b) / len(a | b) >= SIMILARITY_THRESHOLD


def _similarity(a: set, b: set, boilerplate=frozenset()) -> float:
    if not a or not b:
        return 0.0
    a, b = _identifying(a, b, boilerplate)
    return len(a & b) / len(a | b)


def cross_source_duplicate_indices(account, infos, source) -> set:
    """Indices in ``infos`` that another source already stored.

    The same bank entry can arrive through two paths (an EBICS camt.053 sync
    and a CSV export of the same account). Their dedup keys only coincide when
    both carry the bank's reference; ZKB's CSV and camt differ in wording
    ("Belastung" vs "Debit"), so the content-hash fallback yields two rows for
    one payment — sometimes even dated a day apart.

    Entries are grouped by (amount, currency) — what both feeds always agree
    on — and each already-stored entry claims the incoming entry that reads
    like the same payment, same-day candidates first and only then ones within
    ``DUPLICATE_WINDOW_DAYS``. A day holding two unrelated 10 EUR debits (two
    Riester contracts) therefore keeps them apart, and an entry the other feed
    never reported is still imported. Matching on count alone silently deleted
    such payments.
    """
    from .models import Transaction

    incoming = {}
    for index, info in enumerate(infos):
        incoming.setdefault((info.amount, info.currency), []).append(index)
    if not incoming:
        return set()

    dates = [info.booking_date for info in infos if info.booking_date]
    if not dates:
        return set()
    window = timedelta(days=DUPLICATE_WINDOW_DAYS)
    existing = list(
        Transaction.objects
        .filter(
            account=account,
            booking_date__gte=min(dates) - window,
            booking_date__lte=max(dates) + window,
        )
        .exclude(source=source)
        .exclude(source='manual')  # hand-entered rows are the user's own truth
        .order_by('booking_date', 'id')
        .values_list('booking_date', 'amount', 'currency',
                     'counterparty', 'description')
    )

    # The bank's own template words, so the merchant decides the match rather
    # than the boilerplate. Learned from the whole account, not the comparison
    # window: a handful of bookings around one date cannot tell a template
    # apart from a coincidence.
    boilerplate = boilerplate_tokens(
        [f'{c} {d}' for c, d in Transaction.objects.filter(account=account)
         .values_list('counterparty', 'description')]
        + [f'{i.counterparty} {i.description}' for i in infos],
    )

    duplicates = set()
    for booking_date, amount, currency, counterparty, description in existing:
        candidates = incoming.get((amount, currency))
        if not candidates:
            continue
        match = None
        for index in candidates:
            info = infos[index]
            distance = abs(info.booking_date - booking_date)
            if distance > window:
                continue
            if not looks_like_same_entry(
                    counterparty, description,
                    info.counterparty, info.description, boilerplate):
                continue  # same amount, but a different payment
            score = _similarity(
                _tokens(counterparty or '', description or ''),
                _tokens(info.counterparty, info.description),
                boilerplate)
            # Closest date wins, then the most similar wording — so two
            # same-amount payments on neighbouring days pair with their own
            # counterpart rather than swapping.
            key = (distance, -score)
            if match is None or key < match[0]:
                match = (key, index)
        if match is not None:
            candidates.remove(match[1])  # one stored row, one incoming entry
            duplicates.add(match[1])
    return duplicates


def store_transactions(account, infos, source=None) -> int:
    """Persist a fetched batch idempotently. Returns the number of new rows.

    ``source`` overrides the integration-derived provenance (the CSV import
    stores 'csv' — its rows did not come through the broker integration).
    """
    from .models import Transaction

    source = source or _SOURCE_BY_INTEGRATION_TYPE.get(
        getattr(account.broker, 'integration_type', '') or '', 'broker',
    )
    duplicates = cross_source_duplicate_indices(account, infos, source)

    created_count = 0
    for index, (info, dedup_key) in enumerate(zip(infos, _dedup_keys(infos))):
        # Already stored under this exact key: the normal idempotent path.
        if Transaction.objects.filter(
                account=account, dedup_key=dedup_key).exists():
            continue
        # Same payment already present from another feed, under a key that
        # cannot match (different wording, or one side has no bank reference).
        if index in duplicates:
            logger.info(
                'Skipping %s %s on %s for %s — already imported from another source',
                info.amount, info.currency, info.booking_date, account.name,
            )
            continue
        _, created = Transaction.objects.get_or_create(
            account=account,
            dedup_key=dedup_key,
            defaults={
                'booking_date': info.booking_date,
                'value_date': info.value_date,
                'amount': info.amount,
                'currency': info.currency,
                'counterparty': info.counterparty[:255],
                'counterparty_account': info.counterparty_account[:64],
                'description': info.description,
                'source': source,
                'external_id': (info.external_id or '')[:128],
                'raw_data': info.raw_data,
            },
        )
        if created:
            created_count += 1
    return created_count


@dataclass
class BackfillResult:
    """Outcome of one dated backfill, including what the bank actually served.

    Banks routinely honour a dated request only partially — EBICS archives start at
    subscriber activation, FinTS usually caps at ~90 days. The importer cannot tell
    "you have no older transactions" from "the bank would not give them to me", so it
    reports the covered span and lets the caller say so out loud. Reporting only the
    imported count reads as "your 15 months are complete" when it was really 7 weeks.
    """

    imported: int = 0
    fetched: int = 0
    requested_start: Optional[date] = None
    requested_end: Optional[date] = None
    covered_start: Optional[date] = None
    covered_end: Optional[date] = None

    @property
    def is_truncated(self) -> bool:
        """True when the served span starts materially later than requested."""
        if self.covered_start is None or self.requested_start is None:
            return False
        return (self.covered_start - self.requested_start).days > TRUNCATION_SLACK_DAYS

    def describe(self) -> str:
        if not self.fetched:
            return (
                'No transactions were returned for that period. The bank may not '
                're-serve statements that far back.'
            )
        message = f'{self.imported} new transactions imported'
        if self.imported != self.fetched:
            message += f' ({self.fetched} fetched, the rest were already stored)'
        message += f'. The bank served {self.covered_start} to {self.covered_end}'
        if self.is_truncated:
            message += (
                f' — short of the requested {self.requested_start}, so the months '
                'before that stay empty in the spending report.'
            )
        else:
            message += '.'
        return message


def backfill_account_transactions(account, integration, start_date, end_date) -> BackfillResult:
    """Fetch and store transactions for an explicit date range.

    Same idempotent storage as the incremental import — re-running an
    overlapping range creates nothing new. Also classifies what arrived.
    """
    result = BackfillResult(requested_start=start_date, requested_end=end_date)
    if not integration.supports_transactions():
        return result

    # Not get_transactions(): backfill must query the period explicitly, which for
    # some feeds (EBICS) is a different request than the regular sync's.
    infos = integration.get_transactions_for_range(
        account.account_identifier, start_date, end_date,
    )
    if not infos:
        return result

    booking_dates = [info.booking_date for info in infos if info.booking_date]
    result.fetched = len(infos)
    result.covered_start = min(booking_dates) if booking_dates else None
    result.covered_end = max(booking_dates) if booking_dates else None
    result.imported = store_transactions(account, infos)

    if result.imported:
        from .classification import apply_rules, detect_transfers
        apply_rules(account.user)
        detect_transfers(account.user)

    logger.info(
        'Backfilled %d new transactions for %s (%d fetched, requested %s to %s, '
        'bank served %s to %s)',
        result.imported, account.name, result.fetched, start_date, end_date,
        result.covered_start, result.covered_end,
    )
    return result


def import_account_transactions(account, integration) -> int:
    """Fetch and store booked transactions for one account. Returns the created count.

    Never raises on a per-entry problem; a failure of the fetch itself propagates so
    the caller can decide (the sync views log it and keep the balance sync's result).
    """
    from .models import Transaction

    if not integration.supports_transactions():
        return 0

    end_date = date.today()
    latest = (
        Transaction.objects
        .filter(account=account)
        .exclude(source='manual')
        .order_by('-booking_date')
        .values_list('booking_date', flat=True)
        .first()
    )
    if latest:
        start_date = latest - timedelta(days=OVERLAP_DAYS)
    else:
        start_date = end_date - timedelta(days=DEFAULT_LOOKBACK_DAYS)
    # A broker that already holds a longer history (pulled with the login)
    # gives it away for free: take all of it, so an account whose syncs only
    # ever covered the recent days fills up without a manual backfill.
    held_from = integration.prefetched_transactions_from()
    if held_from and held_from < start_date:
        start_date = held_from

    infos = integration.get_transactions(account.account_identifier, start_date, end_date)
    if not infos:
        return 0

    created_count = store_transactions(account, infos)

    logger.info(
        'Imported %d new transactions for %s (%d fetched, %s to %s)',
        created_count, account.name, len(infos), start_date, end_date,
    )

    # Classify what just arrived: category rules + transfer pairing. Both are
    # idempotent and skip user-overridden rows.
    if created_count:
        from .classification import apply_rules, detect_transfers
        apply_rules(account.user)
        detect_transfers(account.user)

    return created_count
