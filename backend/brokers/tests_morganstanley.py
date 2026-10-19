"""Morgan Stanley browser login: how launch failures reach the user.

A Chromium that cannot start (no X server under a restarted container, missing
binary) must surface as that problem, not as the manual-JWT DevTools
instructions, which only apply when no username/password/TOTP is configured.
"""
from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase

from brokers.integrations import morganstanley_browser as msb
from brokers.integrations.morganstanley import MorganStanleyIntegration

# Abridged from Playwright's real launch errors.
_NO_X_SERVER = (
    "BrowserType.launch: Target page, context or browser has been closed\n"
    "Browser logs:\n\n"
    "Looks like you launched a headed browser without having a XServer running.\n"
    "[pid=2827][err] ozone_platform_x11.cc:257] Missing X server or $DISPLAY"
)
_NO_EXECUTABLE = (
    "BrowserType.launch: Executable doesn't exist at "
    "/ms-playwright/chromium-1243/chrome-linux64/chrome\n"
    "Please run the following command to download new browsers:\n"
    "    playwright install"
)
_OTHER_LAUNCH_FAILURE = (
    "BrowserType.launch: Target page, context or browser has been closed\n"
    "Call log:\n  - <launching> /ms-playwright/chromium-1243/chrome-linux64/chrome"
)


def _playwright_failing_with(message):
    pw = MagicMock()
    pw.__enter__.return_value.chromium.launch.side_effect = Exception(message)
    return MagicMock(return_value=pw)


def _login():
    return msb.browser_login(username='u', password='p', headless=False)


class BrowserLaunchFailureTests(SimpleTestCase):
    def test_missing_x_server_is_a_login_error_naming_the_display(self):
        with patch('playwright.sync_api.sync_playwright', _playwright_failing_with(_NO_X_SERVER)), \
                patch.dict('os.environ', {'DISPLAY': ':99'}):
            with self.assertRaises(msb.BrowserLoginError) as ctx:
                _login()
        self.assertIn('no X server on DISPLAY=:99', str(ctx.exception))

    def test_missing_executable_is_unavailable(self):
        with patch('playwright.sync_api.sync_playwright', _playwright_failing_with(_NO_EXECUTABLE)):
            with self.assertRaises(msb.BrowserLoginUnavailable):
                _login()

    def test_other_launch_failure_keeps_only_the_headline(self):
        with patch('playwright.sync_api.sync_playwright', _playwright_failing_with(_OTHER_LAUNCH_FAILURE)):
            with self.assertRaises(msb.BrowserLoginError) as ctx:
                _login()
        self.assertEqual(
            str(ctx.exception),
            'Browser login failed: BrowserType.launch: Target page, context or browser has been closed',
        )


class AuthenticateWhenBrowserUnavailableTests(SimpleTestCase):
    _CREDS = {'username': 'u', 'password': 'p', 'totp_secret': 'JBSWY3DPEHPK3PXP'}

    def _authenticate(self, creds):
        integration = MorganStanleyIntegration(creds, account_id=1)
        unavailable = msb.BrowserLoginUnavailable('Chromium for Playwright is not installed.')
        with patch.object(MorganStanleyIntegration, '_resolve_relay_proxy', return_value='socks5://127.0.0.1:1'), \
                patch.object(msb, 'browser_login', side_effect=unavailable):
            return integration.authenticate()

    def test_reports_the_reason_instead_of_devtools_instructions(self):
        result = self._authenticate(self._CREDS)
        self.assertFalse(result.success)
        self.assertIn('Chromium for Playwright is not installed', result.error_message)
        self.assertNotIn('DevTools', result.error_message)

    def test_falls_back_to_a_configured_manual_jwt(self):
        result = self._authenticate({**self._CREDS, 'jwt_token': 'eyJ.x.y', 'employee_id': '42'})
        self.assertTrue(result.success)
