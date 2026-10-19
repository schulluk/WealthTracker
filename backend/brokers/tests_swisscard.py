"""Swisscard integration: flow logic with the browser layer stubbed out.

The real login needs a phone, so the browser is replaced by a fake page that
answers the SPA's REST calls. What is verified here is the part that can break
silently: which call happens when, that the SMS is not re-sent while the user
holds a code, and how the portal's numbers map onto the app's model.
"""
from datetime import date, timedelta
from decimal import Decimal
from unittest.mock import patch

from django.test import TestCase

from brokers.integrations.swisscard import (
    ACCOUNTS_PATH,
    FETCH_DAYS,
    OTP_PATH,
    PASSWORD_PATH,
    SwisscardIntegration,
)

_ACCOUNTS = [{
    'id': '40007155878',
    'currency': 'CHF',
    'baseProduct': {'shortName': 'Cashback AMEX'},
    'cycleBalance': {
        'postedBalance': {'value': 2560.85, 'currency': 'CHF'},
        'pendingBalance': {'value': 0.0, 'currency': 'CHF'},
    },
}]

# The SPA's transaction feed: purchases positive, credits negative, each row
# carrying the portal's own id.
_TRANSACTIONS = {
    'summary': {'count': 3},
    'transactions': [
        {'id': 'tx-1', 'description': 'TEST SHOP GENEVA', 'state': 'POSTED',
         'amount': {'value': 42.50, 'currency': 'CHF'},
         'effectiveDate': '2026-08-23', 'postingDate': '2026-08-25',
         'merchant': {'name': 'TEST SHOP', 'category': 'Groceries'}},
        {'id': 'tx-2', 'description': 'IHRE ZAHLUNG – BESTEN DANK',
         'state': 'POSTED', 'amount': {'value': -1200.00, 'currency': 'CHF'},
         'effectiveDate': '2026-08-20', 'postingDate': '2026-08-20',
         'merchant': {}},
        {'id': 'tx-3', 'description': 'NOT YET POSTED', 'state': 'PENDING',
         'amount': {'value': 5.00, 'currency': 'CHF'},
         'effectiveDate': '2026-08-24', 'postingDate': None, 'merchant': {}},
    ],
}


class FakePage:
    """Answers the SPA's REST calls and records what was asked."""

    def __init__(self, password_status=200, otp_status=200, next_step='MTAN_OTP_REQUIRED'):
        self.calls = []
        self.password_status = password_status
        self.otp_status = otp_status
        self.next_step = next_step

    # -- playwright surface used by the integration --------------------
    def goto(self, url, **kwargs):
        self.calls.append(('goto', url))

    def on(self, event, handler):
        # Pretend Anomaly Shield signed the probe so the transport is settled.
        class _Req:
            method = 'POST'
            headers = {'x-42': 'signed'}
        self._handler = handler
        handler(_Req())

    def remove_listener(self, event, handler):
        pass

    def evaluate(self, script, args):
        method, path, body, _headers = args
        self.calls.append((method, path, body))
        if path.endswith('/access'):
            return {'status': 401, 'text': '{}'}
        if path == PASSWORD_PATH:
            return {'status': self.password_status, 'text':
                    '{"data": {"attributes": {"nextAuthStep": "%s", '
                    '"phoneNumber": "+41 79 ***"}}}' % self.next_step}
        if path == OTP_PATH:
            return {'status': self.otp_status, 'text': '{"data": {"id": "x"}}'}
        if path == ACCOUNTS_PATH:
            import json as jsonlib
            return {'status': 200, 'text': jsonlib.dumps(_ACCOUNTS)}
        if path.endswith('/transactions'):
            import json as jsonlib
            return {'status': 200, 'text': jsonlib.dumps(_TRANSACTIONS)}
        return {'status': 404, 'text': ''}


class _PagedPage(FakePage):
    """Serves the transaction feed as two pages joined by an x-next cursor."""

    def __init__(self, second_status=200, **kwargs):
        super().__init__(**kwargs)
        self.second_status = second_status

    def evaluate(self, script, args):
        method, path, body, _headers = args
        if '/transactions' not in path:
            return super().evaluate(script, args)
        import json as jsonlib
        self.calls.append((method, path, body))
        if 'cursor=' not in path:
            return {'status': 200, 'next': 'page two', 'text': jsonlib.dumps({
                'summary': {'count': 2},
                'transactions': [_TRANSACTIONS['transactions'][0]],
            })}
        return {'status': self.second_status, 'next': None,
                'text': jsonlib.dumps({
                    'summary': {'count': 2},
                    'transactions': [_TRANSACTIONS['transactions'][1]],
                })}


class FakeContext:
    def __init__(self, page):
        self._page = page
        self.closed = False

    def new_page(self):
        return self._page

    def set_default_timeout(self, ms):
        pass

    def storage_state(self):
        return {'cookies': [{'name': 'ncs-S', 'value': 'x'}]}

    def close(self):
        self.closed = True


class SwisscardFlowTests(TestCase):
    def _integration(self, page, **creds):
        integration = SwisscardIntegration(
            {'username': 'u', 'password': 'p', **creds})
        context = FakeContext(page)

        class _Browser:
            def close(self_inner):
                pass

        def fake_open(playwright, storage_state=None, url=None):
            return _Browser(), context, page

        integration._playwright = lambda: _NullPlaywright()
        integration._open = fake_open
        integration._context = context
        return integration

    def test_password_step_asks_for_the_sms_code(self):
        page = FakePage()
        integration = self._integration(page)
        result = integration.authenticate()
        self.assertFalse(result.success)
        self.assertTrue(result.requires_2fa)
        self.assertEqual(result.two_fa_type, 'sms')
        # The cookies of the half-finished flow travel to the second step.
        self.assertIn('storage_state', result.session_data)
        self.assertIn('+41 79 ***', result.challenge_data['message'])
        # The password was posted exactly once — one SMS, not two.
        self.assertEqual(
            [c for c in page.calls if c[1] == PASSWORD_PATH].__len__(), 1)

    def test_wrong_password_reports_instead_of_asking_for_a_code(self):
        integration = self._integration(FakePage(password_status=401))
        result = integration.authenticate()
        self.assertFalse(result.success)
        self.assertFalse(result.requires_2fa)

    def test_missing_credentials_do_not_open_a_browser(self):
        integration = SwisscardIntegration({'username': '', 'password': ''})
        integration._playwright = lambda: self.fail('browser must not start')
        result = integration.authenticate()
        self.assertFalse(result.success)
        self.assertIn('username', result.error_message)

    def test_otp_step_completes_and_pulls_the_data(self):
        page = FakePage()
        integration = self._integration(page)
        result = integration.complete_2fa('123456', {
            'storage_state': {'cookies': []}, 'transport': 'fetch'})
        self.assertTrue(result.success, result.error_message)
        # Accounts and the CSV export were fetched inside the same session.
        paths = [c[1] for c in page.calls]
        self.assertIn(ACCOUNTS_PATH, paths)
        self.assertTrue(any(p.endswith('/transactions') for p in paths))
        # The password step was NOT repeated (that would send a second SMS).
        self.assertNotIn(PASSWORD_PATH, paths)

    def test_rejected_code_is_reported(self):
        integration = self._integration(FakePage(otp_status=400))
        result = integration.complete_2fa('000000', {
            'storage_state': {'cookies': []}})
        self.assertFalse(result.success)
        self.assertIn('code', result.error_message.lower())

    def test_empty_code_is_refused_before_opening_a_browser(self):
        integration = SwisscardIntegration({'username': 'u', 'password': 'p'})
        integration._playwright = lambda: self.fail('browser must not start')
        result = integration.complete_2fa('', {'storage_state': {}})
        self.assertFalse(result.success)

    def test_card_balance_is_carried_as_a_liability(self):
        page = FakePage()
        integration = self._integration(page)
        integration.complete_2fa('123456', {'storage_state': {'cookies': []}})
        balance = integration.get_balance('40007155878')
        # The portal reports 2560.85 owed; net worth must see it as negative.
        self.assertEqual(balance.balance, Decimal('-2560.85'))
        self.assertEqual(balance.currency, 'CHF')

    def test_transactions_are_parsed_with_the_swisscard_signs(self):
        page = FakePage()
        integration = self._integration(page)
        integration.complete_2fa('123456', {'storage_state': {'cookies': []}})
        rows = integration.get_transactions(
            '40007155878', date(2026, 1, 1), date(2026, 12, 31))
        # The pending row is left out; it changes when it posts.
        self.assertEqual(len(rows), 2)
        by_date = {r.booking_date: r for r in rows}
        self.assertEqual(by_date[date(2026, 8, 23)].amount, Decimal('-42.50'))
        self.assertEqual(by_date[date(2026, 8, 20)].amount, Decimal('1200.00'))
        # The portal's own id gives exact dedup instead of a content hash.
        self.assertEqual(by_date[date(2026, 8, 23)].external_id, 'tx-1')
        # Outside the fetched range nothing is invented.
        self.assertEqual(
            integration.get_transactions(
                '40007155878', date(2025, 1, 1), date(2025, 2, 1)),
            [])

    def test_transaction_feed_is_read_to_the_last_page(self):
        # The feed answers 50 rows at a time and names the next page in an
        # x-next header. Before that header was followed, a year of card use
        # came back as its newest month.
        page = _PagedPage()
        integration = self._integration(page)
        integration.complete_2fa('123456', {'storage_state': {'cookies': []}})
        rows = integration.get_transactions(
            '40007155878', date(2026, 1, 1), date(2026, 12, 31))
        self.assertEqual({r.external_id for r in rows}, {'tx-1', 'tx-2'})
        # The cursor went back as a query parameter, the window unchanged.
        feed_calls = [c for c in page.calls if '/transactions' in c[1]]
        self.assertEqual(len(feed_calls), 2)
        self.assertNotIn('cursor', feed_calls[0][1])
        self.assertIn('?cursor=page+two', feed_calls[1][1])
        self.assertEqual(feed_calls[0][2], feed_calls[1][2])

    def test_a_failed_later_page_keeps_the_pages_already_read(self):
        page = _PagedPage(second_status=502)
        integration = self._integration(page)
        integration.complete_2fa('123456', {'storage_state': {'cookies': []}})
        rows = integration.get_transactions(
            '40007155878', date(2026, 1, 1), date(2026, 12, 31))
        self.assertEqual([r.external_id for r in rows], ['tx-1'])

    def test_the_login_window_is_offered_to_the_importer(self):
        integration = self._integration(FakePage())
        # Nothing fetched yet, nothing to offer.
        self.assertIsNone(integration.prefetched_transactions_from())
        integration.complete_2fa('123456', {'storage_state': {'cookies': []}})
        self.assertEqual(integration.prefetched_transactions_from(),
                         date.today() - timedelta(days=FETCH_DAYS))

    def test_a_recent_login_is_reused_instead_of_texting_again(self):
        from brokers.integrations import swisscard as mod
        mod._SESSIONS.clear()
        self.addCleanup(mod._SESSIONS.clear)

        page = FakePage()
        first = self._integration(page)
        first.account_id = 42
        first.complete_2fa('123456', {'storage_state': {'cookies': []}})

        # A second sync of the same account, minutes later.
        page2 = FakePage()
        second = self._integration(page2)
        second.account_id = 42
        result = second.authenticate()

        self.assertTrue(result.success, result.error_message)
        self.assertFalse(result.requires_2fa)
        # No password, no SMS — the warm session answered.
        paths = [c[1] for c in page2.calls]
        self.assertNotIn(PASSWORD_PATH, paths)
        self.assertNotIn(OTP_PATH, paths)
        self.assertIn(ACCOUNTS_PATH, paths)
        # And the data is there for the sync that follows.
        self.assertEqual(second.get_balance('40007155878').balance,
                         Decimal('-2560.85'))

    def test_an_expired_session_falls_back_to_a_fresh_login(self):
        from brokers.integrations import swisscard as mod
        mod._SESSIONS.clear()
        self.addCleanup(mod._SESSIONS.clear)
        # Stored, but already past its time-to-live.
        mod._SESSIONS[7] = (0.0, {'state': {}, 'transport': 'fetch'})

        page = FakePage()
        integration = self._integration(page)
        integration.account_id = 7
        result = integration.authenticate()

        self.assertTrue(result.requires_2fa)
        self.assertIn(PASSWORD_PATH, [c[1] for c in page.calls])

    def test_a_dead_session_is_dropped_and_not_reused(self):
        from brokers.integrations import swisscard as mod
        mod._SESSIONS.clear()
        self.addCleanup(mod._SESSIONS.clear)
        mod._remember(9, {'state': {}, 'transport': 'fetch'})

        # The portal rejects the cookies (Airlock expired them server-side).
        class Rejecting(FakePage):
            def evaluate(self, script, args):
                if args[1] == ACCOUNTS_PATH:
                    self.calls.append((args[0], args[1], None))
                    return {'status': 401, 'text': ''}
                return super().evaluate(script, args)

        integration = self._integration(Rejecting())
        integration.account_id = 9
        result = integration.authenticate()

        self.assertTrue(result.requires_2fa)  # asks for a code again
        self.assertIsNone(mod._recall(9))     # and the dead session is gone

    def test_does_not_reauthenticate_before_the_code_step(self):
        self.assertFalse(
            SwisscardIntegration({}).requires_reauth_before_2fa())

    def test_accounts_are_exposed_for_discovery(self):
        page = FakePage()
        integration = self._integration(page)
        integration.complete_2fa('123456', {'storage_state': {'cookies': []}})
        accounts = integration.get_accounts()
        self.assertEqual(accounts[0].identifier, '40007155878')
        self.assertEqual(accounts[0].account_type, 'credit_card')


class _NullPlaywright:
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class SwisscardFactoryTests(TestCase):
    def test_factory_returns_the_integration(self):
        from brokers.integrations import get_broker_integration
        from brokers.models import Broker
        broker = Broker.objects.create(
            code='swisscard', name='Swisscard', integration_type='rest')
        integration = get_broker_integration(
            broker, {'username': 'u', 'password': 'p'}, account_id=1)
        self.assertIsInstance(integration, SwisscardIntegration)
        self.assertTrue(integration.supports_transactions())


class SwisscardViewFlowTests(TestCase):
    """The auth view must not restart the login before submitting the code."""

    @patch('brokers.integrations.swisscard.SwisscardIntegration.authenticate')
    def test_view_skips_reauth_for_interactive_brokers(self, m_auth):
        integration = SwisscardIntegration({'username': 'u', 'password': 'p'})
        # Mirrors AccountAuthView's branch.
        if integration.requires_reauth_before_2fa():
            integration.authenticate()
        m_auth.assert_not_called()
