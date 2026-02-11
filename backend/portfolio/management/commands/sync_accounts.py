"""
Management command to sync all eligible accounts.

DEPRECATED: This command only works for users who have NOT migrated to
per-user encryption (KEK). For migrated users, syncing requires the user's
KEK which is derived from their password and stored only on their device.

After all users migrate, this command should be removed from crontabs.

Usage:
    python manage.py sync_accounts

This command is designed to be run as a cronjob. It will sync all accounts
that:
- Have auto_sync_enabled=True in user profile
- Are not manual accounts
- Use a broker that supports_auto_sync (no interactive 2FA required)
- User has NOT migrated to per-user encryption (encryption_migrated=False)

Brokers with decoupled TAN (push notification) like DKB are supported -
the command will wait for app approval. Brokers requiring interactive 2FA
(e.g., Commerzbank photoTAN) are excluded.

On failure, sends an email to the admin.
"""
import logging
from datetime import datetime

from django.conf import settings
from django.core.mail import send_mail
from django.core.management.base import BaseCommand
from django.utils import timezone

from brokers.integrations import get_broker_integration
from core.encryption import decrypt_credentials
from portfolio.models import AccountSnapshot, FinancialAccount

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Sync all eligible accounts'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show which accounts would be synced without actually syncing',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']

        self.stdout.write(
            self.style.WARNING(
                'DEPRECATION WARNING: This command only works for non-migrated '
                'users. After all users migrate to per-user encryption, remove '
                'this command from crontabs.'
            )
        )

        # Get all non-manual accounts with auto_sync enabled
        # Only include brokers that support auto sync (decoupled TAN or no 2FA)
        # Excludes brokers requiring interactive 2FA (e.g., photoTAN)
        # Respects both global (user profile) and per-account sync_enabled settings
        # IMPORTANT: Only include users who have NOT migrated to per-user encryption
        accounts = FinancialAccount.objects.filter(
            is_manual=False,
            sync_enabled=True,
            user__profile__auto_sync_enabled=True,
            user__profile__encryption_migrated=False,  # Only non-migrated users
            broker__supports_auto_sync=True,
        ).exclude(
            encrypted_credentials=b''
        ).exclude(
            encrypted_credentials__isnull=True
        ).select_related('user', 'broker')

        self.stdout.write(f'Found {accounts.count()} accounts eligible for sync')

        if dry_run:
            for account in accounts:
                self.stdout.write(f'  - {account.name} ({account.user.username})')
            return

        failures = []
        successes = []

        for account in accounts:
            try:
                self._sync_account(account)
                successes.append(account)
                self.stdout.write(self.style.SUCCESS(f'Synced: {account.name}'))
            except Exception as e:
                error_msg = str(e)
                failures.append((account, error_msg))
                self.stdout.write(self.style.ERROR(f'Failed: {account.name} - {error_msg}'))

                # Update account status
                account.status = 'error'
                account.last_sync_error = error_msg
                account.save()

        # Send failure notification email
        if failures and settings.ADMIN_EMAIL:
            self._send_failure_email(failures, successes)

        self.stdout.write(
            f'Sync complete: {len(successes)} succeeded, {len(failures)} failed'
        )

    def _sync_account(self, account):
        """Sync a single account."""
        credentials = decrypt_credentials(account.encrypted_credentials)
        integration = get_broker_integration(account.broker, credentials)

        # Authenticate
        auth_result = integration.authenticate()
        if not auth_result.success:
            raise RuntimeError(auth_result.error_message or 'Authentication failed')

        if auth_result.requires_2fa:
            raise RuntimeError('2FA required - cannot sync automatically')

        # Get balance
        balance_info = integration.get_balance(account.account_identifier or '')

        # Create snapshot
        AccountSnapshot.objects.update_or_create(
            account=account,
            snapshot_date=balance_info.balance_date,
            defaults={
                'balance': balance_info.balance,
                'currency': balance_info.currency,
            }
        )

        # Update account status
        account.status = 'active'
        account.last_sync_at = timezone.now()
        account.last_sync_error = ''
        account.save()

        integration.close()

    def _send_failure_email(self, failures, successes):
        """Send email notification about sync failures."""
        subject = f'[Wealth Tracker] Account Sync Failures - {len(failures)} failed'

        body_lines = [
            f'Account sync completed at {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}',
            '',
            f'Successes: {len(successes)}',
            f'Failures: {len(failures)}',
            '',
            'Failed accounts:',
        ]

        for account, error in failures:
            body_lines.append(f'  - {account.name} ({account.user.username}): {error}')

        body = '\n'.join(body_lines)

        try:
            send_mail(
                subject=subject,
                message=body,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[settings.ADMIN_EMAIL],
                fail_silently=False,
            )
            self.stdout.write('Failure notification email sent')
        except Exception as e:
            self.stdout.write(self.style.WARNING(f'Failed to send email: {e}'))
