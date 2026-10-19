"""Swisscard (credit card) — password plus an SMS one-time code.

Swisscard's portal runs Ergon Airlock IAM with a mandatory second factor and
issues nothing but session cookies: no device trust, no refresh token, no
storable long-lived credential. A sync therefore cannot run unattended; it is
user-initiated and completes only once the SMS code is entered:

1. :meth:`authenticate` submits username and password, which makes Airlock
   send the SMS, and returns ``requires_2fa`` together with the cookies of the
   half-finished flow.
2. :meth:`complete_2fa` restores those cookies, posts the code, and pulls
   accounts and transactions straight away — the session is short-lived, so
   everything is fetched in that one window and cached. The transaction feed
   is paged (50 rows, next cursor in an ``x-next`` header) and read to the end.

Everything runs inside a real browser page. The portal's ``42.js`` (Airlock
Anomaly Shield) signs each POST with an ``x-42`` header computed at runtime,
so requests are issued from the page rather than rebuilt from the outside. No
CSS selectors are involved — the SPA's own REST endpoints are called directly,
which survives redesigns of the login screen.
"""
import json
import logging
import os
import time
from datetime import date, timedelta
from decimal import Decimal
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlencode

from .base import (
    AccountInfo,
    AuthResult,
    BalanceInfo,
    BrokerIntegrationBase,
    TransactionInfo,
)

logger = logging.getLogger(__name__)

ORIGIN = 'https://app.swisscard.ch'
FLOW = '2fa_cardholder'
LOGIN_PAGE = f'{ORIGIN}/auth/ui/app/auth/flow/{FLOW}/password'
APP_PAGE = f'{ORIGIN}/'

ACCESS_PATH = f'/auth/rest/public/authentication/applications/{FLOW}/access'
PASSWORD_PATH = '/auth/rest/public/authentication/password/check'
OTP_PATH = '/auth/rest/public/authentication/mtan/otp/check'
ACCOUNTS_PATH = '/api/v1/accounts'

# How much history one interactive login pulls. The session dies within
# minutes, so everything that may be asked for later is fetched up front.
FETCH_DAYS = 400

# The transaction feed answers 50 rows per call and names the next page in an
# ``x-next`` response header, which the SPA hands back as ``?cursor=``. A year
# of card use is a handful of pages; the cap only stops a cursor that never
# ends.
MAX_TRANSACTION_PAGES = 200

DEFAULT_TIMEOUT_MS = 60_000

# A finished login is kept for a few minutes so a second action (syncing again,
# or backfilling history right after) does not cost another SMS. In memory
# only: session cookies are as good as a login, and writing them to the
# database would leave them at rest long after the session itself is dead.
# The web container runs a single worker, so one process sees them all.
SESSION_TTL_SECONDS = int(os.environ.get('SWISSCARD_SESSION_TTL', '300'))

# account_id -> (expires_at monotonic, {'state': storage_state, 'transport': ...})
_SESSIONS: Dict[Any, Tuple[float, Dict[str, Any]]] = {}


def _remember(account_id, session: Dict[str, Any]) -> None:
    if account_id is None:
        return
    _SESSIONS[account_id] = (time.monotonic() + SESSION_TTL_SECONDS, session)


def _recall(account_id) -> Optional[Dict[str, Any]]:
    if account_id is None:
        return None
    entry = _SESSIONS.get(account_id)
    if not entry:
        return None
    expires_at, session = entry
    if time.monotonic() >= expires_at:
        _SESSIONS.pop(account_id, None)
        return None
    return session


def _forget(account_id) -> None:
    _SESSIONS.pop(account_id, None)


class SwisscardLoginError(RuntimeError):
    """Login failed in a way the user can act on (wrong password, wrong code)."""


class SwisscardUnavailable(RuntimeError):
    """The browser stack needed for the login is missing."""


# Issue requests from the page so Anomaly Shield instruments them. Which
# transport it hooks (fetch or XMLHttpRequest) is a deployment detail, so the
# caller probes once with a harmless call and sticks to what worked.
_FETCH_JS = """
async ([method, path, body, headers]) => {
  const res = await fetch(path, {
    method,
    credentials: 'same-origin',
    headers: Object.assign(
      {'accept': 'application/json, text/plain, */*'},
      body ? {'content-type': 'application/json'} : {},
      headers || {}),
    body: body ? JSON.stringify(body) : undefined,
  });
  return {status: res.status, text: await res.text(),
          next: res.headers.get('x-next')};
}
"""

_XHR_JS = """
([method, path, body, headers]) => new Promise((resolve) => {
  const xhr = new XMLHttpRequest();
  xhr.open(method, path, true);
  xhr.withCredentials = true;
  xhr.setRequestHeader('accept', 'application/json, text/plain, */*');
  if (body) xhr.setRequestHeader('content-type', 'application/json');
  for (const [k, v] of Object.entries(headers || {})) xhr.setRequestHeader(k, v);
  xhr.onloadend = () => resolve({status: xhr.status, text: xhr.responseText,
                                 next: xhr.getResponseHeader('x-next')});
  xhr.send(body ? JSON.stringify(body) : null);
})
"""


class SwisscardIntegration(BrokerIntegrationBase):
    """Interactive Swisscard sync (password + SMS code)."""

    def __init__(self, credentials: Dict[str, Any], account_id: Any = None):
        super().__init__(credentials)
        self.account_id = account_id
        self._accounts: Optional[List[Dict[str, Any]]] = None
        self._transactions: Optional[List[TransactionInfo]] = None
        self._fetched_from: Optional[date] = None

    # -- capabilities -----------------------------------------------------

    def requires_reauth_before_2fa(self) -> bool:
        """The SMS was already sent; re-running the password step sends another."""
        return False

    def supports_transactions(self) -> bool:
        return True

    # -- browser plumbing -------------------------------------------------

    def _playwright(self):
        try:
            from playwright.sync_api import sync_playwright
        except ImportError as exc:  # pragma: no cover - depends on deploy image
            raise SwisscardUnavailable(
                'Playwright is not installed. Add `playwright` to requirements '
                'and run `playwright install --with-deps chromium`.'
            ) from exc
        return sync_playwright()

    def _open(self, playwright, storage_state=None, url=LOGIN_PAGE):
        headless = os.environ.get('SWISSCARD_HEADLESS', '1') != '0'
        browser = playwright.chromium.launch(headless=headless)
        context = browser.new_context(
            storage_state=storage_state,
            locale='en-CH',
        )
        context.set_default_timeout(DEFAULT_TIMEOUT_MS)
        page = context.new_page()
        # networkidle: 42.js must have run before anything is posted.
        page.goto(url, wait_until='networkidle')
        return browser, context, page

    def _pick_transport(self, page) -> str:
        """Return 'fetch' or 'xhr' — whichever Anomaly Shield signs.

        Probes with the SPA's own flow-start call, which answers 401 by design
        and changes no state.
        """
        for transport, script in (('fetch', _FETCH_JS), ('xhr', _XHR_JS)):
            signed = {'ok': False}

            def _watch(request, signed=signed):
                if request.method == 'POST' and 'x-42' in request.headers:
                    signed['ok'] = True

            page.on('request', _watch)
            try:
                page.evaluate(script, [
                    'POST', ACCESS_PATH, {}, {'x-same-domain': '1'},
                ])
            except Exception:  # pragma: no cover - transport simply unusable
                logger.debug('Swisscard: %s transport unusable', transport)
            finally:
                page.remove_listener('request', _watch)
            if signed['ok']:
                return transport
        # Nothing signed the probe; the header may not be enforced. Carry on
        # with fetch rather than failing before we have learned anything.
        logger.warning('Swisscard: no x-42 header observed on the probe call')
        return 'fetch'

    def _call_raw(self, page, transport, method, path, body=None,
                  headers=None) -> Dict[str, Any]:
        """One request from inside the page: ``{status, text, next}``."""
        script = _FETCH_JS if transport == 'fetch' else _XHR_JS
        return page.evaluate(script, [method, path, body, headers or {}]) or {}

    def _call(self, page, transport, method, path, body=None, headers=None):
        result = self._call_raw(page, transport, method, path, body, headers)
        text = result.get('text') or ''
        return result.get('status'), self._json(text), text

    @staticmethod
    def _json(text) -> Any:
        if not text:
            return None
        try:
            return json.loads(text)
        except ValueError:
            return None

    # -- authentication ---------------------------------------------------

    def authenticate(self) -> AuthResult:
        # A login from the last few minutes is still good: reuse it instead of
        # asking the bank to text another code.
        resumed = self._resume()
        if resumed is not None:
            return resumed

        username = (self.credentials.get('username') or '').strip()
        password = self.credentials.get('password') or ''
        if not username or not password:
            return AuthResult(
                success=False,
                error_message='Swisscard needs a username and password.',
            )

        with self._playwright() as playwright:
            browser, context, page = self._open(playwright)
            try:
                transport = self._pick_transport(page)
                status, payload, _ = self._call(
                    page, transport, 'POST', PASSWORD_PATH,
                    {'username': username, 'password': password},
                    {'x-same-domain': '1', 'x-continue-flow': 'true'},
                )
                if status != 200:
                    return AuthResult(
                        success=False,
                        error_message=self._message(
                            payload, 'Swisscard rejected the username or password.'),
                    )
                meta = self._meta(payload)
                next_step = (meta.get('nextAuthStep') or '').upper()
                if 'MTAN' not in next_step and 'OTP' not in next_step:
                    # No SMS step (or the deployment changed): nothing to ask
                    # the user, so treat it as a failure rather than pretend.
                    return AuthResult(
                        success=False,
                        error_message=f'Unexpected authentication step "{next_step}".',
                    )
                # The cookies carry the half-finished flow; the OTP step
                # continues it in a fresh browser.
                state = context.storage_state()
                phone = meta.get('phoneNumber') or ''
                return AuthResult(
                    success=False,
                    requires_2fa=True,
                    two_fa_type='sms',
                    session_data={'storage_state': state, 'transport': transport},
                    challenge_data={
                        'message': f'Enter the code sent to {phone}' if phone
                                   else 'Enter the code sent by SMS',
                        'phone_number': phone,
                    },
                )
            finally:
                context.close()
                browser.close()

    def _resume(self) -> Optional[AuthResult]:
        """Reuse a recent login, or None when there is nothing usable.

        Airlock expires sessions server-side on its own schedule, so a cached
        session is only trusted after it answers a real request.
        """
        session = _recall(self.account_id)
        if not session:
            return None
        try:
            with self._playwright() as playwright:
                browser, context, page = self._open(
                    playwright, storage_state=session['state'], url=APP_PAGE)
                try:
                    transport = session.get('transport', 'fetch')
                    status, payload, _ = self._call(
                        page, transport, 'GET', ACCOUNTS_PATH)
                    if status != 200 or not isinstance(payload, list):
                        _forget(self.account_id)
                        logger.info('Swisscard: cached session no longer valid')
                        return None
                    self._session = session
                    self._accounts = payload
                    self._load_transactions(page, transport)
                    # Sliding window: a session in use stays warm.
                    _remember(self.account_id, session)
                    return AuthResult(success=True)
                finally:
                    context.close()
                    browser.close()
        except Exception as exc:  # a broken cache must never block a fresh login
            logger.info('Swisscard: could not resume the session (%s)', exc)
            _forget(self.account_id)
            return None

    def complete_2fa(self, auth_code: Optional[str],
                     session_data: Dict[str, Any]) -> AuthResult:
        code = (auth_code or '').strip()
        if not code:
            return AuthResult(success=False, error_message='Enter the SMS code.')
        state = (session_data or {}).get('storage_state')
        if not state:
            return AuthResult(
                success=False,
                error_message='The login session expired — start the sync again.',
            )

        with self._playwright() as playwright:
            browser, context, page = self._open(
                playwright, storage_state=state,
                url=f'{ORIGIN}/auth/ui/app/auth/flow/{FLOW}/mtan',
            )
            try:
                transport = (session_data.get('transport')
                             or self._pick_transport(page))
                status, payload, _ = self._call(
                    page, transport, 'POST', OTP_PATH, {'otp': code},
                    {'x-same-domain': '1', 'x-continue-flow': 'true'},
                )
                if status != 200:
                    return AuthResult(
                        success=False,
                        error_message=self._message(
                            payload, 'That SMS code was not accepted.'),
                    )
                # The session is live but short — pull everything now, and
                # keep it for a few minutes so syncing again or backfilling
                # right after does not cost another SMS.
                page.goto(APP_PAGE, wait_until='networkidle')
                self._load_data(page, transport)
                self._session = {
                    'state': context.storage_state(),
                    'transport': transport,
                }
                _remember(self.account_id, self._session)
                return AuthResult(success=True)
            finally:
                context.close()
                browser.close()

    # -- data -------------------------------------------------------------

    def _load_data(self, page, transport) -> None:
        status, payload, _ = self._call(page, transport, 'GET', ACCOUNTS_PATH)
        if status != 200 or not isinstance(payload, list):
            raise SwisscardLoginError('Could not read the Swisscard accounts.')
        self._accounts = payload
        self._load_transactions(page, transport)

    def _load_transactions(self, page, transport,
                           start: Optional[date] = None) -> None:
        end = date.today()
        start = start or end - timedelta(days=FETCH_DAYS)
        self._transactions = []
        for account in self._accounts or []:
            identifier = str(account.get('id') or '')
            if not identifier:
                continue
            self._transactions.extend(
                self._fetch_transactions(page, transport, identifier, start, end))
        self._fetched_from = start

    def _fetch_transactions(self, page, transport, identifier, start, end):
        """Read the SPA's own transaction feed for one account, page by page.

        The JSON feed is preferred over the CSV export: every entry carries a
        stable id, which makes dedup exact instead of text-based. It is paged:
        the first call answers the newest 50 rows and an ``x-next`` header
        naming the cursor of the page after, until the last page carries none.
        The summary's count is the total over all pages.
        """
        base_path = f'{ACCOUNTS_PATH}/{identifier}/transactions'
        window = {'dateMin': start.isoformat(), 'dateMax': end.isoformat()}
        rows: List[Dict[str, Any]] = []
        reported = None
        cursor = None
        for page_no in range(1, MAX_TRANSACTION_PAGES + 1):
            path = base_path
            if cursor:
                path = f'{base_path}?{urlencode({"cursor": cursor})}'
            result = self._call_raw(page, transport, 'POST', path, window)
            status = result.get('status')
            payload = self._json(result.get('text'))
            if status != 200 or not isinstance(payload, dict):
                logger.warning(
                    'Swisscard: transaction fetch failed for %s '
                    '(status %s, page %d)', identifier, status, page_no)
                if not rows:
                    return []
                # Keep the pages already read; the next sync fetches again
                # and dedup drops what is already stored.
                break
            page_rows = payload.get('transactions') or []
            rows.extend(page_rows)
            if reported is None:
                reported = (payload.get('summary') or {}).get('count')
            cursor = result.get('next')
            if not cursor or not page_rows:
                break
        else:
            logger.warning(
                'Swisscard: gave up on %s after %d pages',
                identifier, MAX_TRANSACTION_PAGES)

        if reported is not None and reported != len(rows):
            logger.warning(
                'Swisscard: %s reports %s transactions but returned %d',
                identifier, reported, len(rows))

        infos = []
        for row in rows:
            if (row.get('state') or 'POSTED').upper() != 'POSTED':
                continue  # pending entries change on posting
            amount = (row.get('amount') or {})
            value = amount.get('value')
            booking = self._as_date(row.get('effectiveDate'))
            if value is None or booking is None:
                continue
            merchant = row.get('merchant') or {}
            # Purchases are reported positive and credits negative — the
            # opposite of the sign convention everywhere else in the app.
            infos.append(TransactionInfo(
                booking_date=booking,
                amount=-Decimal(str(value)),
                currency=amount.get('currency') or self._currency_of(identifier),
                value_date=self._as_date(row.get('postingDate')),
                counterparty=merchant.get('name') or row.get('description') or '',
                description=row.get('description') or '',
                external_id=row.get('id') or None,
                raw_data={
                    'account': identifier,
                    'category': merchant.get('category') or '',
                },
            ))
        return infos

    @staticmethod
    def _as_date(value) -> Optional[date]:
        if not value:
            return None
        try:
            return date.fromisoformat(str(value)[:10])
        except ValueError:
            return None

    def _account(self, identifier: str) -> Dict[str, Any]:
        for account in self._accounts or []:
            if str(account.get('id')) == str(identifier):
                return account
        raise SwisscardLoginError(f'Swisscard account {identifier} not found.')

    def _currency_of(self, identifier: str) -> str:
        for account in self._accounts or []:
            if str(account.get('id')) == str(identifier):
                return account.get('currency') or 'CHF'
        return 'CHF'

    def get_accounts(self) -> List[AccountInfo]:
        return [
            AccountInfo(
                identifier=str(a.get('id')),
                name=(a.get('baseProduct') or {}).get('shortName') or 'Swisscard',
                account_type='credit_card',
                currency=a.get('currency') or 'CHF',
            )
            for a in self._accounts or []
        ]

    def get_balance(self, account_identifier: str) -> BalanceInfo:
        account = self._account(account_identifier)
        posted = ((account.get('cycleBalance') or {}).get('postedBalance') or {})
        # The portal reports what is OWED as a positive number; as a balance in
        # a net-worth view a card is a liability, so it is carried negative.
        amount = Decimal(str(posted.get('value') or 0))
        return BalanceInfo(
            balance=-amount,
            currency=posted.get('currency') or account.get('currency') or 'CHF',
            balance_date=date.today(),
            raw_data={'posted_balance': str(amount)},
        )

    def prefetched_transactions_from(self) -> Optional[date]:
        """The login pulled FETCH_DAYS of history; the importer may keep it all."""
        return self._fetched_from if self._transactions is not None else None

    def get_transactions(self, account_identifier: str, start_date: date,
                         end_date: date) -> List[TransactionInfo]:
        if self._transactions is None:
            return []
        if self._fetched_from and start_date < self._fetched_from:
            logger.info(
                'Swisscard: %s requested but only %s onwards was fetched',
                start_date, self._fetched_from)
        return [
            info for info in self._transactions
            if (info.raw_data or {}).get('account') == str(account_identifier)
            and start_date <= info.booking_date <= end_date
        ]

    def get_transactions_for_range(self, account_identifier: str,
                                   start_date: date,
                                   end_date: date) -> List[TransactionInfo]:
        """Backfill: ask the portal for the window instead of the cache.

        Needs a live session, which is either still warm from a recent sync or
        was just established by answering the SMS challenge the backfill raised.
        """
        if self._fetched_from and start_date >= self._fetched_from:
            return self.get_transactions(account_identifier, start_date, end_date)
        session = self._session or _recall(self.account_id)
        if not session:
            return self.get_transactions(account_identifier, start_date, end_date)
        with self._playwright() as playwright:
            browser, context, page = self._open(
                playwright, storage_state=session['state'], url=APP_PAGE)
            try:
                rows = self._fetch_transactions(
                    page, session.get('transport', 'fetch'),
                    str(account_identifier), start_date, end_date)
            finally:
                context.close()
                browser.close()
        return [r for r in rows if start_date <= r.booking_date <= end_date]

    # -- helpers ----------------------------------------------------------

    @staticmethod
    def _meta(payload) -> Dict[str, Any]:
        """Airlock answers with a JSON:API document; the useful bits are flat."""
        if not isinstance(payload, dict):
            return {}
        found: Dict[str, Any] = {}

        def collect(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    if isinstance(value, (dict, list)):
                        collect(value)
                    elif key not in found:
                        found[key] = value
            elif isinstance(node, list):
                for item in node:
                    collect(item)

        collect(payload)
        return found

    @classmethod
    def _message(cls, payload, fallback: str) -> str:
        meta = cls._meta(payload)
        for key in ('detail', 'title', 'message', 'code'):
            value = meta.get(key)
            if isinstance(value, str) and value:
                return f'{fallback} ({value})'
        return fallback
