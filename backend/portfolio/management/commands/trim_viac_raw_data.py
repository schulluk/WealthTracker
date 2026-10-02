"""Drop the daily history from the raw_data of stored VIAC snapshots.

A VIAC sync used to store the whole /rest/web/wealth/summary response with each
snapshot. That response repeats the account's full daily history several times
over, so every snapshot carried megabytes of JSON, once a day per account, and
every backup copied it. Syncs now keep only the summary totals
(brokers.integrations.viac.trim_wealth_summary); this applies the same trim to
the snapshots stored before.

Balances and dates are untouched, and a trimmed snapshot comes out unchanged, so
the command is safe to re-run. Sizes are those of the JSON text, which is what a
dumpdata backup holds. PostgreSQL stores it compressed, so the table shrinks by
less, and only hands the space back to the disk after a VACUUM FULL.
"""
import json

from django.core.management.base import BaseCommand

from brokers.integrations.viac import trim_wealth_summary
from portfolio.models import AccountSnapshot


def _json_bytes(value):
    return len(json.dumps(value).encode())


class Command(BaseCommand):
    help = "Drop the daily history from VIAC snapshots' raw_data (balances are kept)."

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Report the rows and bytes that would be trimmed without changing anything',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        ids = list(
            AccountSnapshot.objects
            .filter(account__broker__code='viac', raw_data__isnull=False)
            .order_by('id')
            .values_list('id', flat=True)
        )

        # One row at a time: a single untrimmed raw_data parses into tens of MB.
        trimmed_rows = before = after = 0
        for done, pk in enumerate(ids, start=1):
            snapshot = AccountSnapshot.objects.only('raw_data').get(pk=pk)
            raw = snapshot.raw_data
            if isinstance(raw, dict):
                trimmed = trim_wealth_summary(raw)
                if trimmed != raw:
                    trimmed_rows += 1
                    before += _json_bytes(raw)
                    after += _json_bytes(trimmed)
                    if not dry_run:
                        snapshot.raw_data = trimmed
                        snapshot.save(update_fields=['raw_data'])
            if done % 100 == 0:
                self.stdout.write(f'  {done}/{len(ids)} checked')

        saved = before - after
        trim, save = ('Would trim', 'would save') if dry_run else ('Trimmed', 'saved')
        self.stdout.write(
            f'{trim} {trimmed_rows} of {len(ids)} VIAC snapshots with raw data '
            f'({len(ids) - trimmed_rows} had nothing to trim).'
        )
        self.stdout.write(self.style.SUCCESS(
            f'Raw data JSON {before:,} -> {after:,} bytes: {save} {saved:,} bytes '
            f'({saved / 1_000_000:,.1f} MB).'
        ))
        if dry_run:
            self.stdout.write(self.style.WARNING(
                '[DRY RUN] Nothing changed. Run without --dry-run to trim.'))
