"""
Manually test the Morgan Stanley headless-browser login end-to-end.

Runs the real integration path (browser login -> JWT mint -> optional balance
fetch). Defaults to HEADFUL so you can watch the flow and adjust the 2FA/"trust
this device" selectors in morganstanley_browser.py if they miss.

Examples:
    # headful, watch the flow (creds via env to avoid shell history)
    MS_TEST_PASSWORD=... MS_TEST_TOTP_SECRET=... \
        python manage.py test_ms_login --username YOUR_LOGIN --balance

    # headless, persisting device-trust state for account 12 under /tmp/ms-state
    python manage.py test_ms_login --username U --password P --totp-secret S \
        --account-id 12 --state-dir /tmp/ms-state --headless --balance
"""
import os

from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Test the Morgan Stanley headless-browser login end-to-end."

    def add_arguments(self, parser):
        parser.add_argument('--username', required=True, help='MS at Work login (account number / username)')
        parser.add_argument('--password', default=os.environ.get('MS_TEST_PASSWORD'),
                            help='MS password (or set MS_TEST_PASSWORD)')
        parser.add_argument('--totp-secret', default=os.environ.get('MS_TEST_TOTP_SECRET'),
                            help='Base32 TOTP seed (or set MS_TEST_TOTP_SECRET)')
        parser.add_argument('--account-id', type=int, default=None,
                            help='FinancialAccount id to key/persist device-trust state by')
        parser.add_argument('--state-dir', default=None,
                            help='Override MS_BROWSER_STATE_DIR for this run')
        parser.add_argument('--headless', action='store_true',
                            help='Run headless (default: headful so you can watch)')
        parser.add_argument('--balance', action='store_true',
                            help='Also fetch the portfolio balance after login')

    def handle(self, *args, **opts):
        if not opts['password'] or not opts['totp_secret']:
            raise CommandError(
                "password and totp-secret are required "
                "(pass --password/--totp-secret or set MS_TEST_PASSWORD/MS_TEST_TOTP_SECRET)."
            )

        # Drive headless mode + state dir through the same env the integration reads.
        os.environ['MS_HEADLESS'] = '1' if opts['headless'] else '0'
        if opts['state_dir']:
            os.environ['MS_BROWSER_STATE_DIR'] = opts['state_dir']
        # A manual run is a deliberate (re-)enrollment: bypass the OTP throttle so it
        # proceeds even if an OTP was done recently.
        os.environ.setdefault('MS_FORCE_OTP', '1')

        from brokers.integrations.morganstanley import MorganStanleyIntegration

        creds = {
            'username': opts['username'],
            'password': opts['password'],
            'totp_secret': opts['totp_secret'],
        }
        integration = MorganStanleyIntegration(creds, account_id=opts['account_id'])

        self.stdout.write(self.style.MIGRATE_HEADING(
            f"Authenticating (headless={opts['headless']}, account_id={opts['account_id']})..."
        ))
        try:
            result = integration.authenticate()
            if not result.success:
                raise CommandError(f"Login failed: {result.error_message}")

            jwt = integration._jwt_token or ''
            self.stdout.write(self.style.SUCCESS("✓ Login succeeded"))
            self.stdout.write(f"  employee_id : {integration.employee_id}")
            self.stdout.write(f"  jwt (prefix): {jwt[:24]}…  (len {len(jwt)})")
            self.stdout.write(f"  state dir   : {integration._browser_state_dir()}")

            if opts['balance']:
                self.stdout.write(self.style.MIGRATE_HEADING("Fetching balance..."))
                bal = integration.get_balance('')
                self.stdout.write(self.style.SUCCESS(
                    f"✓ Balance: {bal.balance} {bal.currency} (as of {bal.balance_date})"
                ))
                if bal.raw_data:
                    self.stdout.write(f"  raw: {bal.raw_data}")
        finally:
            integration.close()
