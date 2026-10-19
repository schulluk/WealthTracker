"""Tests for portfolio models, serializers, and account/snapshot/sync endpoints."""
from datetime import date, timedelta
from decimal import Decimal
from unittest.mock import MagicMock, patch

from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APITestCase

from brokers.integrations.base import AuthResult, BalanceInfo
from brokers.models import Broker
from core.kek_testing import make_kek_user
from core.user_encryption import decrypt_credentials
from exchange_rates.models import ExchangeRate
from portfolio.models import AccountSnapshot, FinancialAccount, PortfolioPosition
from portfolio.serializers import FinancialAccountSerializer


class ModelTests(TestCase):
    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Pillar 3a', currency='CHF',
        )

    def test_latest_snapshot_returns_most_recent(self):
        AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('100'), currency='CHF',
            snapshot_date=date(2026, 1, 1),
        )
        newest = AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('200'), currency='CHF',
            snapshot_date=date(2026, 6, 1),
        )
        self.assertEqual(self.account.latest_snapshot, newest)

    def test_latest_snapshot_none_when_empty(self):
        self.assertIsNone(self.account.latest_snapshot)

    def test_account_str(self):
        self.assertIn('Pillar 3a', str(self.account))

    def test_position_relationship(self):
        snap = AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('500'), currency='CHF',
            snapshot_date=date(2026, 6, 1),
        )
        pos = PortfolioPosition.objects.create(
            snapshot=snap, name='World ETF', quantity=Decimal('10'),
            price_per_unit=Decimal('50'), market_value=Decimal('500'),
            currency='CHF', asset_class='equity',
        )
        self.assertEqual(list(snap.positions.all()), [pos])


class SerializerTests(TestCase):
    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')

    def test_financial_account_serializer_output(self):
        account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Acct', currency='CHF',
        )
        AccountSnapshot.objects.create(
            account=account, balance=Decimal('42'), currency='CHF',
            snapshot_date=date(2026, 6, 1),
        )
        data = FinancialAccountSerializer(account).data
        self.assertEqual(data['name'], 'Acct')
        self.assertEqual(data['broker']['code'], 'viac')
        self.assertEqual(data['latest_snapshot']['balance'], '42.0000')
        self.assertIsNone(data['ebics_credential'])
        # Encrypted credentials must never be exposed.
        self.assertNotIn('encrypted_credentials', data)


class AccountEndpointTests(APITestCase):
    def setUp(self):
        self.user, self.kek, self.user_key = make_kek_user()
        self.broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        self.client.force_authenticate(user=self.user)

    def test_list_only_own_accounts(self):
        FinancialAccount.objects.create(user=self.user, broker=self.broker, name='Mine')
        other, _, _ = make_kek_user(username='bob')
        FinancialAccount.objects.create(user=other, broker=self.broker, name='Theirs')
        resp = self.client.get(reverse('account_list'))
        self.assertEqual(resp.status_code, 200)
        names = [a['name'] for a in resp.data['results']]
        self.assertEqual(names, ['Mine'])

    def test_create_manual_account(self):
        resp = self.client.post(reverse('account_list'), {
            'name': 'Cash', 'broker_code': 'viac', 'is_manual': True,
            'account_type': 'savings', 'currency': 'CHF',
        }, format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        account = FinancialAccount.objects.get(name='Cash')
        self.assertTrue(account.is_manual)

    def test_create_account_with_credentials_encrypts_them(self):
        self.client.credentials(HTTP_X_KEK=self.kek)
        resp = self.client.post(reverse('account_list'), {
            'name': 'VIAC', 'broker_code': 'viac', 'currency': 'CHF',
            'credentials': {'username': 'me', 'password': 's3cr3t'},
        }, format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        account = FinancialAccount.objects.get(name='VIAC')
        self.assertIsNotNone(account.encrypted_credentials)
        # Stored ciphertext must decrypt back to the original credentials.
        self.assertEqual(
            decrypt_credentials(account.encrypted_credentials, self.user_key),
            {'username': 'me', 'password': 's3cr3t'},
        )

    def test_detail_delete(self):
        account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Del',
        )
        resp = self.client.delete(reverse('account_detail', args=[account.pk]))
        self.assertEqual(resp.status_code, 204)
        self.assertFalse(FinancialAccount.objects.filter(pk=account.pk).exists())

    def test_notes_are_editable(self):
        account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Cash', is_manual=True,
        )
        resp = self.client.patch(
            reverse('account_detail', args=[account.pk]),
            {'notes': 'IBAN CH..\nrainy-day fund'}, format='json',
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['notes'], 'IBAN CH..\nrainy-day fund')
        account.refresh_from_db()
        self.assertEqual(account.notes, 'IBAN CH..\nrainy-day fund')

    def test_cannot_access_other_users_account(self):
        other, _, _ = make_kek_user(username='bob')
        account = FinancialAccount.objects.create(
            user=other, broker=self.broker, name='Theirs',
        )
        resp = self.client.get(reverse('account_detail', args=[account.pk]))
        self.assertEqual(resp.status_code, 404)


class SnapshotEndpointTests(APITestCase):
    def setUp(self):
        self.user, _, _ = make_kek_user(base_currency='CHF')
        self.broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Acct', currency='CHF',
        )
        self.client.force_authenticate(user=self.user)

    def test_create_manual_snapshot(self):
        resp = self.client.post(
            reverse('snapshot_list', args=[self.account.pk]),
            {'balance': '1000.00', 'currency': 'CHF', 'snapshot_date': '2026-06-01'},
            format='json',
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        snap = AccountSnapshot.objects.get(account=self.account)
        self.assertEqual(snap.snapshot_source, 'manual')

    def test_duplicate_snapshot_rejected(self):
        payload = {'balance': '1000.00', 'currency': 'CHF', 'snapshot_date': '2026-06-01'}
        url = reverse('snapshot_list', args=[self.account.pk])
        self.assertEqual(self.client.post(url, payload, format='json').status_code, 201)
        dup = self.client.post(url, payload, format='json')
        self.assertEqual(dup.status_code, 400)

    def test_snapshot_converts_to_base_currency(self):
        ExchangeRate.objects.create(
            from_currency='USD', to_currency='CHF', rate=Decimal('0.9'),
            rate_date=date(2026, 6, 1),
        )
        resp = self.client.post(
            reverse('snapshot_list', args=[self.account.pk]),
            {'balance': '100.00', 'currency': 'USD', 'snapshot_date': '2026-06-01'},
            format='json',
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        snap = AccountSnapshot.objects.get(account=self.account)
        self.assertEqual(snap.balance_base_currency, Decimal('90.0000'))
        self.assertEqual(snap.base_currency, 'CHF')


class WealthSummaryTests(APITestCase):
    def setUp(self):
        self.user, _, _ = make_kek_user(base_currency='CHF')
        self.broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        self.client.force_authenticate(user=self.user)

    def test_summary_totals_latest_snapshots(self):
        for name, bal in [('A', '1000'), ('B', '500')]:
            account = FinancialAccount.objects.create(
                user=self.user, broker=self.broker, name=name, currency='CHF',
            )
            AccountSnapshot.objects.create(
                account=account, balance=Decimal(bal), currency='CHF',
                snapshot_date=date(2026, 6, 1),
            )
        resp = self.client.get(reverse('wealth_summary'))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['total_wealth'], 1500.0)
        self.assertEqual(resp.data['base_currency'], 'CHF')
        self.assertEqual(resp.data['account_count'], 2)


class AccountSyncEndpointTests(APITestCase):
    def setUp(self):
        self.user, self.kek, self.user_key = make_kek_user(base_currency='CHF')
        self.broker = Broker.objects.create(
            code='viac', name='VIAC', integration_type='rest', supports_auto_sync=True,
        )
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def _account(self, **kwargs):
        from core.user_encryption import encrypt_credentials
        defaults = dict(
            user=self.user, broker=self.broker, name='VIAC', currency='CHF',
            account_identifier='ID1',
            encrypted_credentials=encrypt_credentials({'u': 'x'}, self.user_key),
        )
        defaults.update(kwargs)
        return FinancialAccount.objects.create(**defaults)

    def test_sync_manual_account_rejected(self):
        account = self._account(is_manual=True, encrypted_credentials=None)
        resp = self.client.post(reverse('account_sync', args=[account.pk]))
        self.assertEqual(resp.status_code, 400)

    def test_sync_without_credentials_rejected(self):
        account = self._account(encrypted_credentials=None)
        resp = self.client.post(reverse('account_sync', args=[account.pk]))
        self.assertEqual(resp.status_code, 400)

    def test_sync_enqueues_task(self):
        account = self._account()
        from portfolio.sync_queue import sync_queue
        with patch.object(sync_queue, 'has_pending_task', return_value=None), \
                patch.object(sync_queue, 'enqueue', return_value='task-xyz') as m_enqueue:
            resp = self.client.post(reverse('account_sync', args=[account.pk]))
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['task_id'], 'task-xyz')
        # Credentials were decrypted on the request thread and handed to the queue.
        self.assertEqual(m_enqueue.call_args.kwargs['credentials'], {'u': 'x'})

    def test_sync_other_user_account_404(self):
        other, _, _ = make_kek_user(username='bob')
        account = FinancialAccount.objects.create(
            user=other, broker=self.broker, name='Theirs', account_identifier='X',
        )
        resp = self.client.post(reverse('account_sync', args=[account.pk]))
        self.assertEqual(resp.status_code, 404)


class NonSyncingBrokerTests(APITestCase):
    """A broker that cannot fetch anything (Commerzbank: photoTAN needs a camera).

    The account still belongs to the broker — that is what identifies its CSV
    export format — but every path that would talk to the bank is closed, and
    the balance is entered by hand. See docs/commerzbank-integration.md.
    """

    def setUp(self):
        self.user, self.kek, self.user_key = make_kek_user(base_currency='EUR')
        self.broker = Broker.objects.create(
            code='commerzbank', name='Commerzbank', integration_type='fints',
            supports_auto_sync=False,
        )
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Commerzbank Giro',
            currency='EUR', account_identifier='DE00', encrypted_credentials=b'x',
            is_manual=False, sync_enabled=True,
        )
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def test_broker_reports_no_sync_support(self):
        self.assertFalse(self.broker.supports_sync)

    def test_interactive_broker_still_supports_sync(self):
        """Stopping for a code is not the same as never fetching."""
        swisscard = Broker.objects.create(
            code='swisscard', name='Swisscard', integration_type='rest',
            supports_auto_sync=False,
        )
        self.assertTrue(swisscard.supports_sync)

    def test_serializer_exposes_supports_sync(self):
        data = FinancialAccountSerializer(self.account).data
        self.assertFalse(data['broker']['supports_sync'])

    def test_sync_rejected(self):
        resp = self.client.post(reverse('account_sync', args=[self.account.pk]))
        self.assertEqual(resp.status_code, 400)
        self.assertIn('by hand', resp.data['error'])

    def test_backfill_rejected(self):
        resp = self.client.post(
            reverse('transaction_backfill', kwargs={'pk': self.account.pk}),
            {'start': '2026-01-01'}, format='json',
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn('CSV', resp.data['error'])

    def test_storing_credentials_rejected(self):
        resp = self.client.put(
            reverse('account_credentials', args=[self.account.pk]),
            {'credentials': {'username': 'x', 'pin': 'y'}}, format='json',
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn('no credentials', resp.data['error'])

    def test_excluded_from_sync_all(self):
        from portfolio.sync_queue import sync_queue
        with patch.object(sync_queue, 'has_pending_task', return_value=None), \
                patch.object(sync_queue, 'enqueue', return_value='task-1') as m_enqueue:
            resp = self.client.post(reverse('sync_all_accounts'))
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['synced_count'], 0)
        m_enqueue.assert_not_called()

    def test_manual_snapshots_still_allowed(self):
        """The whole point: the balance is typed in instead of fetched."""
        resp = self.client.post(
            reverse('snapshot_list', kwargs={'account_id': self.account.pk}),
            {'balance': '1234.56', 'currency': 'EUR', 'snapshot_date': '2026-08-30'},
            format='json',
        )
        self.assertEqual(resp.status_code, 201, resp.data)


class SyncWorkerLogicTests(TestCase):
    """Exercise the sync worker body directly with a mocked broker integration."""

    def setUp(self):
        self.user, _, _ = make_kek_user(base_currency='CHF')
        self.broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='VIAC', currency='CHF',
            account_identifier='ID1',
        )

    def _fake_integration(self, auth=True, balance=None):
        integ = MagicMock()
        integ.authenticate.return_value = AuthResult(success=auth) if auth else \
            AuthResult(success=False, error_message='bad creds')
        integ.get_balance.return_value = balance
        integ.supports_historical_data.return_value = False
        return integ

    @patch('django.db.connections.close_all')
    @patch('brokers.integrations.get_broker_integration')
    def test_sync_creates_snapshot(self, m_factory, _m_close):
        from portfolio.views import _sync_single_account
        m_factory.return_value = self._fake_integration(balance=BalanceInfo(
            balance=Decimal('1234.00'), currency='CHF', balance_date=date(2026, 6, 1),
            raw_data={'source': 'test'},
        ))
        result = _sync_single_account(
            account_id=self.account.id, credentials={'u': 'x'}, base_currency='CHF',
        )
        self.assertEqual(result['status'], 'success')
        snap = AccountSnapshot.objects.get(account=self.account)
        self.assertEqual(snap.balance, Decimal('1234.00'))
        self.account.refresh_from_db()
        self.assertEqual(self.account.status, 'active')
        self.assertIsNotNone(self.account.last_sync_at)

    @patch('django.db.connections.close_all')
    @patch('brokers.integrations.get_broker_integration')
    def test_sync_auth_failure_marks_error(self, m_factory, _m_close):
        from portfolio.views import _sync_single_account
        m_factory.return_value = self._fake_integration(auth=False)
        result = _sync_single_account(
            account_id=self.account.id, credentials={'u': 'x'}, base_currency='CHF',
        )
        self.assertEqual(result['status'], 'error')
        self.account.refresh_from_db()
        self.assertEqual(self.account.status, 'error')
        self.assertEqual(self.account.last_sync_error, 'bad creds')

    @patch('django.db.connections.close_all')
    @patch('brokers.integrations.get_broker_integration')
    def test_sync_no_new_data_is_noop_not_error(self, m_factory, _m_close):
        # A broker reporting "no new data" (e.g. EBICS 090005) must be a benign no-op:
        # keep the account active with its prior snapshot, record no error, no new snapshot.
        from brokers.integrations.base import NoNewDataError
        from portfolio.views import _sync_single_account
        AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('50'), currency='CHF',
            snapshot_date=date(2026, 5, 1),
        )
        integ = self._fake_integration()
        integ.get_balance.side_effect = NoNewDataError('nothing new')
        m_factory.return_value = integ

        result = _sync_single_account(
            account_id=self.account.id, credentials={'u': 'x'}, base_currency='CHF',
        )
        self.assertEqual(result['status'], 'success')
        self.assertIsNone(result['snapshot'])
        # No new snapshot created; the prior one is preserved.
        self.assertEqual(AccountSnapshot.objects.filter(account=self.account).count(), 1)
        self.account.refresh_from_db()
        self.assertEqual(self.account.status, 'active')
        self.assertEqual(self.account.last_sync_error, '')
        self.assertIsNotNone(self.account.last_sync_at)

    @patch('django.db.connections.close_all')
    @patch('brokers.integrations.get_broker_integration')
    def test_sync_all_backfills_every_delivered_day(self, m_factory, _m_close):
        # A broker that delivers multiple days (e.g. an EBICS camt.053 backlog) must
        # snapshot ALL of them on sync-all, not just the latest.
        from portfolio.views import _sync_all_accounts
        integ = self._fake_integration(balance=BalanceInfo(
            balance=Decimal('300'), currency='CHF', balance_date=date(2026, 6, 3), raw_data=None,
        ))
        integ.supports_historical_data.return_value = True
        integ.historical_data_requires_extra_request.return_value = False
        integ.get_historical_balances.return_value = [
            BalanceInfo(balance=Decimal('100'), currency='CHF', balance_date=date(2026, 6, 1), raw_data=None),
            BalanceInfo(balance=Decimal('200'), currency='CHF', balance_date=date(2026, 6, 2), raw_data=None),
            BalanceInfo(balance=Decimal('300'), currency='CHF', balance_date=date(2026, 6, 3), raw_data=None),
        ]
        m_factory.return_value = integ
        _sync_all_accounts(
            account_creds=[(self.account.id, {'u': 'x'})], base_currency='CHF',
        )
        dates = set(
            AccountSnapshot.objects.filter(account=self.account)
            .values_list('snapshot_date', flat=True)
        )
        self.assertEqual(dates, {date(2026, 6, 1), date(2026, 6, 2), date(2026, 6, 3)})

    @patch('django.db.connections.close_all')
    @patch('brokers.integrations.get_broker_integration')
    def test_sync_converts_to_base_currency(self, m_factory, _m_close):
        from portfolio.views import _sync_single_account
        ExchangeRate.objects.create(
            from_currency='USD', to_currency='CHF', rate=Decimal('0.9'),
            rate_date=date(2026, 6, 1),
        )
        m_factory.return_value = self._fake_integration(balance=BalanceInfo(
            balance=Decimal('100.00'), currency='USD', balance_date=date(2026, 6, 1),
            raw_data=None,
        ))
        _sync_single_account(
            account_id=self.account.id, credentials={'u': 'x'}, base_currency='CHF',
        )
        snap = AccountSnapshot.objects.get(account=self.account)
        self.assertEqual(snap.balance_base_currency, Decimal('90.00'))
        self.assertEqual(snap.exchange_rate_used, Decimal('0.9'))


class ExchangeRateModelTests(TestCase):
    def test_same_currency_returns_one(self):
        self.assertEqual(ExchangeRate.get_rate('CHF', 'CHF', date(2026, 6, 1)), Decimal('1.0'))

    def test_exact_date_match(self):
        ExchangeRate.objects.create(
            from_currency='USD', to_currency='CHF', rate=Decimal('0.9'),
            rate_date=date(2026, 6, 1),
        )
        self.assertEqual(
            ExchangeRate.get_rate('USD', 'CHF', date(2026, 6, 1)), Decimal('0.9'),
        )

    def test_falls_back_to_earlier_rate(self):
        ExchangeRate.objects.create(
            from_currency='USD', to_currency='CHF', rate=Decimal('0.85'),
            rate_date=date(2026, 5, 1),
        )
        self.assertEqual(
            ExchangeRate.get_rate('USD', 'CHF', date(2026, 6, 15)), Decimal('0.85'),
        )

    def test_inverse_rate(self):
        ExchangeRate.objects.create(
            from_currency='CHF', to_currency='USD', rate=Decimal('2'),
            rate_date=date(2026, 6, 1),
        )
        self.assertEqual(
            ExchangeRate.get_rate('USD', 'CHF', date(2026, 6, 1)), Decimal('0.5'),
        )

    def test_missing_rate_returns_none(self):
        self.assertIsNone(ExchangeRate.get_rate('JPY', 'CHF', date(2026, 6, 1)))


class SnapshotWriterTests(TestCase):
    """upsert_daily_snapshot: gap-fill by default, overwrite when the source is authoritative."""

    def setUp(self):
        self.user, _, _ = make_kek_user(base_currency='CHF')
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='A', currency='CHF',
        )

    def _bal(self, amount, d, currency='CHF'):
        return BalanceInfo(
            balance=Decimal(amount), currency=currency, balance_date=d, raw_data={'s': 1},
        )

    def test_creates_when_absent(self):
        from portfolio.snapshot_writer import upsert_daily_snapshot
        snap, changed = upsert_daily_snapshot(self.account, self._bal('100', date(2026, 6, 1)), 'CHF')
        self.assertTrue(changed)
        self.assertEqual(snap.balance, Decimal('100'))

    def test_gap_fill_skips_existing(self):
        from portfolio.snapshot_writer import upsert_daily_snapshot
        AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('50'), currency='CHF',
            snapshot_date=date(2026, 6, 1), snapshot_source='manual',
        )
        snap, changed = upsert_daily_snapshot(self.account, self._bal('100', date(2026, 6, 1)), 'CHF')
        self.assertFalse(changed)
        self.assertEqual(snap.balance, Decimal('50'))  # left untouched
        self.assertEqual(AccountSnapshot.objects.filter(account=self.account).count(), 1)

    def test_overwrite_replaces_in_place(self):
        from portfolio.snapshot_writer import upsert_daily_snapshot
        AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('50'), currency='CHF',
            snapshot_date=date(2026, 6, 1), snapshot_source='manual',
        )
        snap, changed = upsert_daily_snapshot(
            self.account, self._bal('100', date(2026, 6, 1)), 'CHF', overwrite=True,
        )
        self.assertTrue(changed)
        snap.refresh_from_db()
        self.assertEqual(snap.balance, Decimal('100'))
        self.assertEqual(snap.snapshot_source, 'auto')
        self.assertEqual(AccountSnapshot.objects.filter(account=self.account).count(), 1)  # no dup

    def test_currency_conversion_applied(self):
        from portfolio.snapshot_writer import upsert_daily_snapshot
        ExchangeRate.objects.create(
            from_currency='USD', to_currency='CHF', rate=Decimal('0.9'), rate_date=date(2026, 6, 1),
        )
        snap, _ = upsert_daily_snapshot(
            self.account, self._bal('100', date(2026, 6, 1), 'USD'), 'CHF',
        )
        self.assertEqual(snap.balance_base_currency, Decimal('90.0'))
        self.assertEqual(snap.exchange_rate_used, Decimal('0.9'))


class EbicsAccountFallbackTests(APITestCase):
    """Until the bank activates the EBICS key exchange (credential state != 'active'),
    an EBICS-linked account must behave like a manual one: no auto-sync, surfaced in
    the app's manual "needs a snapshot" prompt."""

    def setUp(self):
        from brokers.models import EbicsCredential
        self.user, self.kek, self.user_key = make_kek_user(base_currency='CHF')
        self.broker = Broker.objects.create(
            code='zkb', name='ZKB', integration_type='ebics', supports_auto_sync=True,
        )
        self.cred = EbicsCredential.objects.create(
            user=self.user, broker=self.broker, label='ZKB',
            host_id='ZKBKCHZZ', partner_id='PARTNER1', subscriber_id='SUB1',
            url='https://ebicsweb.zkb.ch/ebicsweb', state='new',
        )
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='ZKB Giro', currency='CHF',
            account_identifier='CH00', ebics_credential=self.cred,
            sync_enabled=True, is_manual=False,
        )
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def _activate(self):
        self.cred.state = 'active'
        self.cred.save(update_fields=['state'])

    # --- serializer: effective sync_enabled drives the app's manual-vs-auto UX ---
    def test_serializer_reports_sync_disabled_while_credential_pending(self):
        for state in ('new', 'keys_sent'):
            self.cred.state = state
            self.cred.save(update_fields=['state'])
            data = FinancialAccountSerializer(self.account).data
            self.assertFalse(
                data['sync_enabled'],
                f'sync should be effectively off while credential is {state}',
            )
            self.assertEqual(data['ebics_credential']['state'], state)

    def test_serializer_reports_real_sync_enabled_when_active(self):
        self._activate()
        data = FinancialAccountSerializer(self.account).data
        self.assertTrue(data['sync_enabled'])

    def test_non_ebics_account_sync_flag_untouched(self):
        acct = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Plain',
            currency='CHF', sync_enabled=True,
        )
        data = FinancialAccountSerializer(acct).data
        self.assertTrue(data['sync_enabled'])
        self.assertIsNone(data['ebics_credential'])

    # --- single-account sync guard ---
    def test_single_sync_rejected_while_pending(self):
        resp = self.client.post(reverse('account_sync', args=[self.account.pk]))
        self.assertEqual(resp.status_code, 400)
        self.assertIn('not active', resp.data['error'].lower())

    def test_single_sync_allowed_when_active(self):
        self._activate()
        from portfolio.sync_queue import sync_queue
        from portfolio.views import AccountSyncView
        with patch.object(AccountSyncView, 'decrypt_sync_credentials', return_value={'k': 1}), \
                patch.object(sync_queue, 'has_pending_task', return_value=None), \
                patch.object(sync_queue, 'enqueue', return_value='t1') as m_enqueue:
            resp = self.client.post(reverse('account_sync', args=[self.account.pk]))
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertTrue(m_enqueue.called)

    # --- sync-all filter: pending EBICS accounts are skipped, not errored ---
    def test_sync_all_excludes_pending_ebics(self):
        resp = self.client.post(reverse('sync_all_accounts'))
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['synced_count'], 0)
        self.assertIn('No accounts to sync', resp.data['message'])

    def test_sync_all_includes_active_ebics(self):
        self._activate()
        from portfolio.sync_queue import sync_queue
        from portfolio.views import SyncAllAccountsView
        with patch.object(SyncAllAccountsView, 'decrypt_sync_credentials', return_value={'k': 1}), \
                patch.object(sync_queue, 'has_pending_task', return_value=None), \
                patch.object(sync_queue, 'enqueue', return_value='t2') as m_enqueue:
            resp = self.client.post(reverse('sync_all_accounts'))
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertTrue(m_enqueue.called)
        account_ids = [aid for aid, _ in m_enqueue.call_args.kwargs['account_creds']]
        self.assertEqual(account_ids, [self.account.id])

    def test_sync_all_skips_brokers_that_need_an_sms_code(self):
        """A bulk run must not fire SMS codes nobody is waiting to type."""
        self._activate()
        swisscard = Broker.objects.create(
            code='swisscard', name='Swisscard', integration_type='rest')
        FinancialAccount.objects.create(
            user=self.user, broker=swisscard, name='Card', currency='CHF',
            encrypted_credentials=b'x', sync_enabled=True,
        )
        from portfolio.sync_queue import sync_queue
        from portfolio.views import SyncAllAccountsView
        with patch.object(SyncAllAccountsView, 'decrypt_sync_credentials', return_value={'k': 1}), \
                patch.object(sync_queue, 'has_pending_task', return_value=None), \
                patch.object(sync_queue, 'enqueue', return_value='t3') as m_enqueue:
            resp = self.client.post(reverse('sync_all_accounts'))
        self.assertEqual(resp.status_code, 200, resp.data)
        account_ids = [aid for aid, _ in m_enqueue.call_args.kwargs['account_creds']]
        # Only the EBICS account; the card account syncs on demand instead.
        self.assertEqual(account_ids, [self.account.id])


class TransactionImporterTests(TestCase):
    """Dedup and window logic of the shared transaction importer."""

    def setUp(self):
        from brokers.integrations.base import TransactionInfo
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='CHF',
            account_identifier='CH93',
        )
        self.TransactionInfo = TransactionInfo

    def _fake_integration(self, infos, held_from=None):
        calls = []

        class Fake:
            def supports_transactions(self):
                return True

            def prefetched_transactions_from(self):
                return held_from

            def get_transactions(self, identifier, start, end):
                calls.append((identifier, start, end))
                return infos

        fake = Fake()
        fake.calls = calls
        return fake

    def _info(self, **overrides):
        from decimal import Decimal as D
        defaults = dict(
            booking_date=date(2026, 8, 1), amount=D('-12.50'), currency='CHF',
            counterparty='Coop', description='Lunch',
        )
        defaults.update(overrides)
        return self.TransactionInfo(**defaults)

    def test_import_is_idempotent(self):
        from portfolio.models import Transaction
        from portfolio.transaction_importer import import_account_transactions
        infos = [self._info(external_id='R1'), self._info(external_id='R2')]
        integration = self._fake_integration(infos)
        self.assertEqual(import_account_transactions(self.account, integration), 2)
        self.assertEqual(import_account_transactions(self.account, integration), 0)
        self.assertEqual(Transaction.objects.filter(account=self.account).count(), 2)
        self.assertEqual(
            set(Transaction.objects.values_list('dedup_key', flat=True)),
            {'ref:R1', 'ref:R2'},
        )

    def test_same_entry_from_two_sources_is_not_duplicated(self):
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        # EBICS wording, no bank reference -> content hash.
        store_transactions(self.account, [self._info(
            amount=D('-30'), description='Debit TWINT: ALTERMATT, MANUEL',
        )], source='camt053')
        # The account's CSV export of the same payment: German wording, so the
        # content hash differs and the keys can never match.
        created = store_transactions(self.account, [self._info(
            amount=D('-30'), description='Belastung TWINT: ALTERMATT, MANUEL',
        )], source='csv')
        self.assertEqual(created, 0)
        self.assertEqual(Transaction.objects.filter(account=self.account).count(), 1)

    def test_genuinely_repeated_payment_survives_a_second_source(self):
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        # Two identical payments on one day, as the sync saw them.
        store_transactions(self.account, [
            self._info(amount=D('-30'), description='Debit TWINT: A'),
            self._info(amount=D('-30'), description='Debit TWINT: A'),
        ], source='camt053')
        # The CSV reports the same two — neither is new, none is lost.
        created = store_transactions(self.account, [
            self._info(amount=D('-30'), description='Belastung TWINT: A'),
            self._info(amount=D('-30'), description='Belastung TWINT: A'),
        ], source='csv')
        self.assertEqual(created, 0)
        self.assertEqual(Transaction.objects.filter(account=self.account).count(), 2)

    def test_third_payment_only_in_the_csv_is_still_imported(self):
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        store_transactions(self.account, [
            self._info(amount=D('-30'), description='Debit TWINT: A'),
        ], source='camt053')
        # The CSV covers the same day but holds one more such payment.
        created = store_transactions(self.account, [
            self._info(amount=D('-30'), description='Belastung TWINT: A'),
            self._info(amount=D('-30'), description='Belastung TWINT: A'),
        ], source='csv')
        self.assertEqual(created, 1)
        self.assertEqual(Transaction.objects.filter(account=self.account).count(), 2)

    def test_dedupe_command_removes_existing_cross_source_duplicates(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        common = dict(
            account=self.account, booking_date=date(2026, 8, 21),
            amount=D('-30'), currency='CHF',
        )
        Transaction.objects.create(
            **common, description='Debit TWINT: ALTERMATT',
            source='camt053', dedup_key='ref:ZKB-1',
        )
        Transaction.objects.create(
            **common, description='Belastung TWINT: ALTERMATT',
            source='csv', dedup_key='h:abc',
        )
        # Dry run reports but keeps both.
        out = StringIO()
        call_command('dedupe_transactions', stdout=out)
        self.assertIn('would delete', out.getvalue())
        self.assertEqual(Transaction.objects.count(), 2)

        call_command('dedupe_transactions', '--apply', stdout=StringIO())
        # The row with the bank reference survives.
        remaining = Transaction.objects.get()
        self.assertEqual(remaining.dedup_key, 'ref:ZKB-1')

    # ZKB writes almost the whole card booking text itself, so two unrelated
    # merchants charging the same amount to the same card already share six
    # words. Real case: a 0.50 Mobility charge only EBICS reported was matched
    # against a 0.50 Miteigentuemergemeinschaft charge two days earlier.
    _CARD = 'ZKB Visa Debit card no. xxxx 7890, '
    _CARD_DE = 'ZKB Visa Debit Card Nr. xxxx 7890, '

    def _card_history(self, merchants, source):
        """Enough card bookings for the template to be recognizable as one."""
        from decimal import Decimal as D
        from portfolio.models import Transaction
        for i, merchant in enumerate(merchants):
            Transaction.objects.create(
                account=self.account, booking_date=date(2026, 1, 1 + i),
                amount=D('-9.99'), currency='CHF', source=source,
                description=f'Purchase {self._CARD}{merchant}',
                dedup_key=f'hist-{source}-{i}',
            )

    def test_same_card_and_amount_but_a_different_merchant_is_kept(self):
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        self._card_history(
            ['Aldi Suisse 35 0813', 'Denner Discount 1372', 'Lidl Fil 347',
             'Coop Adliswil 0813', 'Migros MM 0813', 'Kohler 1089 0813',
             'Dosenbach 950 0813', 'k kiosk Sood 0813'], 'csv')
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 22),
            amount=D('-0.50'), currency='CHF', source='csv',
            description=f'Purchase {self._CARD}Miteigentumergemeinschaf',
            dedup_key='h:miteigentum',
        )
        # EBICS reports a DIFFERENT 0.50 charge on the same card two days on.
        created = store_transactions(self.account, [
            self._info(
                booking_date=date(2026, 8, 24), amount=D('-0.50'),
                counterparty='',
                description=f'Online-Einkauf {self._CARD_DE}Mobility Hub Parkservice'),
        ], source='camt053')
        self.assertEqual(created, 1, 'a payment only one feed reported was dropped')

    def test_same_card_amount_and_merchant_is_still_deduplicated(self):
        """The template discount must not stop real duplicates being caught."""
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        self._card_history(
            ['Aldi Suisse 35 0813', 'Denner Discount 1372', 'Lidl Fil 347',
             'Coop Adliswil 0813', 'Migros MM 0813', 'Kohler 1089 0813',
             'Dosenbach 950 0813', 'k kiosk Sood 0813'], 'csv')
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 22),
            amount=D('-0.50'), currency='CHF', source='csv',
            description=f'Purchase {self._CARD}Miteigentumergemeinschaf',
            dedup_key='h:miteigentum',
        )
        created = store_transactions(self.account, [
            self._info(
                booking_date=date(2026, 8, 24), amount=D('-0.50'),
                counterparty='',
                description=f'Einkauf {self._CARD_DE}Miteigentumergemeinschaf'),
        ], source='camt053')
        self.assertEqual(created, 0)

    def test_dedupe_command_keeps_a_different_merchant_on_the_same_card(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        self._card_history(
            ['Aldi Suisse 35 0813', 'Denner Discount 1372', 'Lidl Fil 347',
             'Coop Adliswil 0813', 'Migros MM 0813', 'Kohler 1089 0813',
             'Dosenbach 950 0813', 'k kiosk Sood 0813'], 'csv')
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 22),
            amount=D('-0.50'), currency='CHF', source='csv',
            description=f'Purchase {self._CARD}Miteigentumergemeinschaf',
            dedup_key='h:miteigentum',
        )
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 24),
            amount=D('-0.50'), currency='CHF', source='camt053',
            description=f'Online-Einkauf {self._CARD_DE}Mobility Hub Parkservice',
            dedup_key='ref:MOB-1',
        )
        out = StringIO()
        call_command('dedupe_transactions', '--apply', stdout=out)
        self.assertNotIn('would delete', out.getvalue())
        self.assertTrue(Transaction.objects.filter(dedup_key='ref:MOB-1').exists())
        self.assertTrue(Transaction.objects.filter(dedup_key='h:miteigentum').exists())

    def test_dedupe_dry_run_names_the_row_each_deletion_duplicates(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        common = dict(
            account=self.account, booking_date=date(2026, 8, 21),
            amount=D('-30'), currency='CHF',
        )
        Transaction.objects.create(
            **common, description='Debit TWINT: ALTERMATT',
            source='camt053', dedup_key='ref:ZKB-1')
        Transaction.objects.create(
            **common, description='Belastung TWINT: ALTERMATT',
            source='csv', dedup_key='h:abc')
        out = StringIO()
        call_command('dedupe_transactions', stdout=out)
        # A destructive list is only reviewable next to its justification.
        self.assertIn('duplicate of:', out.getvalue())
        self.assertIn('Debit TWINT: ALTERMATT', out.getvalue())

    def test_two_unrelated_same_amount_payments_stay_apart(self):
        """Two Riester contracts debit 10 EUR on the same day — not copies."""
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        store_transactions(self.account, [
            self._info(amount=D('-10'), description='05-0885318-88 Riester'),
            self._info(amount=D('-10'), description='05-0885320-90 Riester'),
        ], source='fints')
        # The CSV lists them in the other order; each stored row must claim
        # its OWN counterpart, not merely the first candidate.
        created = store_transactions(self.account, [
            self._info(amount=D('-10'), description='05-0885320-90 Riester'),
            self._info(amount=D('-10'), description='05-0885318-88 Riester'),
        ], source='csv')
        self.assertEqual(created, 0)
        self.assertEqual(
            sorted(Transaction.objects.values_list('description', flat=True)),
            ['05-0885318-88 Riester', '05-0885320-90 Riester'],
        )

    def test_entry_the_other_feed_missed_is_still_imported(self):
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        # The sync only caught one of the two contracts.
        store_transactions(self.account, [
            self._info(amount=D('-10'), description='05-0885318-88 Riester'),
        ], source='fints')
        created = store_transactions(self.account, [
            self._info(amount=D('-10'), description='05-0885320-90 Riester'),
            self._info(amount=D('-10'), description='05-0885318-88 Riester'),
        ], source='csv')
        self.assertEqual(created, 1)
        # The missing contract arrived; the known one was not duplicated.
        self.assertEqual(
            sorted(Transaction.objects.values_list('description', flat=True)),
            ['05-0885318-88 Riester', '05-0885320-90 Riester'],
        )

    def test_same_entry_dated_a_day_apart_is_not_duplicated(self):
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        # camt.053 books the TWINT debit a day before the CSV export does.
        store_transactions(self.account, [self._info(
            booking_date=date(2026, 8, 20), amount=D('-16.10'),
            description='Debit TWINT: ADC REGENSDORF')], source='camt053')
        created = store_transactions(self.account, [self._info(
            booking_date=date(2026, 8, 21), amount=D('-16.10'),
            description='Belastung TWINT: ADC REGENSDORF')], source='csv')
        self.assertEqual(created, 0)
        self.assertEqual(Transaction.objects.count(), 1)

    def test_same_merchant_on_neighbouring_days_keeps_both(self):
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        # Two coffees of the same price at the same shop, one day apart —
        # both feeds see both, so nothing may collapse.
        store_transactions(self.account, [
            self._info(booking_date=date(2026, 8, 20), amount=D('-5.00'),
                       description='Debit TWINT: COFFEE BAR'),
            self._info(booking_date=date(2026, 8, 21), amount=D('-5.00'),
                       description='Debit TWINT: COFFEE BAR'),
        ], source='camt053')
        created = store_transactions(self.account, [
            self._info(booking_date=date(2026, 8, 20), amount=D('-5.00'),
                       description='Belastung TWINT: COFFEE BAR'),
            self._info(booking_date=date(2026, 8, 21), amount=D('-5.00'),
                       description='Belastung TWINT: COFFEE BAR'),
        ], source='csv')
        self.assertEqual(created, 0)
        self.assertEqual(
            sorted(Transaction.objects.values_list('booking_date', flat=True)),
            [date(2026, 8, 20), date(2026, 8, 21)],
        )

    def test_dedupe_command_removes_a_twin_dated_a_day_apart(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 20),
            amount=D('-16.10'), currency='CHF', source='camt053',
            description='Debit TWINT: ADC REGENSDORF', dedup_key='h:a')
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 21),
            amount=D('-16.10'), currency='CHF', source='csv',
            description='Belastung TWINT: ADC REGENSDORF', dedup_key='h:b')
        call_command('dedupe_transactions', '--apply', stdout=StringIO())
        self.assertEqual(Transaction.objects.count(), 1)
        self.assertEqual(Transaction.objects.get().source, 'camt053')

    def test_different_payments_same_day_and_amount_are_not_merged(self):
        """One feed has contract A, the other only contract B — both are real."""
        from decimal import Decimal as D
        from portfolio.models import Transaction
        from portfolio.transaction_importer import store_transactions
        store_transactions(self.account, [
            self._info(amount=D('-10'), description='05-0885318-88 Riester'),
        ], source='fints')
        created = store_transactions(self.account, [
            self._info(amount=D('-10'), description='05-0885320-90 Riester'),
        ], source='csv')
        # Same date and amount, but a different contract — not a copy.
        self.assertEqual(created, 1)
        self.assertEqual(Transaction.objects.count(), 2)

    def test_dedupe_command_keeps_differently_worded_payments(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        common = dict(
            account=self.account, booking_date=date(2025, 9, 1),
            amount=D('-10'), currency='EUR',
        )
        Transaction.objects.create(
            **common, description='05-0885318-88 Riester',
            source='fints', dedup_key='h:f1')
        Transaction.objects.create(
            **common, description='05-0885320-90 Riester',
            source='csv', dedup_key='h:c1')
        call_command('dedupe_transactions', '--apply', stdout=StringIO())
        # Two sources, one row each, same date and amount — but two different
        # contracts. Deleting either loses a real payment.
        self.assertEqual(Transaction.objects.count(), 2)

    def test_dedupe_command_keeps_one_row_per_distinct_payment(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        common = dict(
            account=self.account, booking_date=date(2026, 9, 1),
            amount=D('-10'), currency='EUR',
        )
        # Ids interleave across feeds, so a naive "keep the first two" would
        # keep both copies of one contract and delete the other outright.
        Transaction.objects.create(
            **common, description='05-0885318-88 Riester',
            source='fints', dedup_key='h:f1')
        Transaction.objects.create(
            **common, description='05-0885318-88 Riester',
            source='csv', dedup_key='h:c1')
        Transaction.objects.create(
            **common, description='05-0885320-90 Riester',
            source='fints', dedup_key='h:f2')
        Transaction.objects.create(
            **common, description='05-0885320-90 Riester',
            source='csv', dedup_key='h:c2')
        call_command('dedupe_transactions', '--apply', stdout=StringIO())
        self.assertEqual(
            sorted(Transaction.objects.values_list('description', flat=True)),
            ['05-0885318-88 Riester', '05-0885320-90 Riester'],
        )

    def test_dedupe_command_never_deletes_hand_entered_rows(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        common = dict(
            account=self.account, booking_date=date(2026, 8, 21),
            amount=D('-30'), currency='CHF',
        )
        Transaction.objects.create(
            **common, description='Noted by hand', source='manual',
            dedup_key='manual-1',
        )
        Transaction.objects.create(
            **common, description='Debit TWINT', source='camt053',
            dedup_key='ref:ZKB-1',
        )
        call_command('dedupe_transactions', '--apply', stdout=StringIO())
        # The user's own entry cannot be re-imported — it always survives, and
        # it does not count as a feed that also saw the payment.
        self.assertEqual(Transaction.objects.count(), 2)

    def test_dedupe_command_keeps_repeats_from_a_single_source(self):
        from decimal import Decimal as D
        from io import StringIO
        from django.core.management import call_command
        from portfolio.models import Transaction
        for i in range(2):
            Transaction.objects.create(
                account=self.account, booking_date=date(2026, 8, 21),
                amount=D('-30'), currency='CHF', description='Coffee',
                source='camt053', dedup_key=f'h:same-{i}',
            )
        call_command('dedupe_transactions', '--apply', stdout=StringIO())
        self.assertEqual(Transaction.objects.count(), 2)

    def test_identical_entries_without_reference_both_survive(self):
        from portfolio.models import Transaction
        from portfolio.transaction_importer import import_account_transactions
        # Two identical coffee purchases on the same day, no bank reference.
        infos = [self._info(), self._info()]
        integration = self._fake_integration(infos)
        self.assertEqual(import_account_transactions(self.account, integration), 2)
        # Redelivery of the same day maps onto the same ordinal-based keys.
        self.assertEqual(import_account_transactions(self.account, integration), 0)
        self.assertEqual(Transaction.objects.filter(account=self.account).count(), 2)

    def test_source_mapped_from_integration_type(self):
        from portfolio.models import Transaction
        from portfolio.transaction_importer import import_account_transactions
        import_account_transactions(self.account, self._fake_integration([self._info()]))
        self.assertEqual(Transaction.objects.get(account=self.account).source, 'camt053')

    def test_window_starts_before_latest_imported_transaction(self):
        from datetime import timedelta
        from portfolio.transaction_importer import (
            OVERLAP_DAYS, import_account_transactions,
        )
        integration = self._fake_integration([self._info(external_id='R1')])
        import_account_transactions(self.account, integration)
        import_account_transactions(self.account, integration)
        # Second run: start = newest imported booking_date - overlap.
        _, start, _ = integration.calls[1]
        self.assertEqual(start, date(2026, 8, 1) - timedelta(days=OVERLAP_DAYS))

    def test_window_widens_to_what_the_broker_already_holds(self):
        from datetime import timedelta
        from portfolio.transaction_importer import import_account_transactions
        # Swisscard pulls a year with the login; a sync must not throw most of
        # it away just because the newest stored entry is recent.
        held_from = date.today() - timedelta(days=500)
        integration = self._fake_integration(
            [self._info(external_id='R1')], held_from=held_from)
        import_account_transactions(self.account, integration)
        import_account_transactions(self.account, integration)
        for _, start, _ in integration.calls:
            self.assertEqual(start, held_from)

    def test_unsupported_integration_is_noop(self):
        from portfolio.transaction_importer import import_account_transactions

        class NoTx:
            def supports_transactions(self):
                return False

        self.assertEqual(import_account_transactions(self.account, NoTx()), 0)


class TransactionEndpointTests(APITestCase):
    def setUp(self):
        from portfolio.models import Transaction
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='CHF',
        )
        self.imported = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 1),
            amount=Decimal('-25.50'), currency='CHF', counterparty='Migros',
            source='camt053', dedup_key='ref:R1',
        )
        self.client.force_authenticate(user=self.user)

    def _list_url(self):
        return reverse('transaction_list', kwargs={'account_id': self.account.id})

    def test_list_transactions(self):
        resp = self.client.get(self._list_url())
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Migros')

    def test_list_filters_by_date_range(self):
        resp = self.client.get(self._list_url(), {'start': '2026-08-02'})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['results'], [])

    def test_global_list_spans_accounts_and_filters(self):
        from portfolio.models import Transaction, TransactionCategory
        other_account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Zweitkonto', currency='CHF',
        )
        category = TransactionCategory.objects.create(user=self.user, name='Food')
        Transaction.objects.create(
            account=other_account, booking_date=date(2026, 8, 10),
            amount=Decimal('-5'), currency='CHF', counterparty='Coop',
            source='camt053', dedup_key='ref:R2', category=category,
        )
        url = reverse('transaction_list_all')

        # All accounts, newest first.
        resp = self.client.get(url)
        self.assertEqual(resp.data['count'], 2)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Coop')

        # Restricted to one account.
        resp = self.client.get(url, {'account': self.account.id})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Migros')

        # Only uncategorized: the categorized Coop entry disappears.
        resp = self.client.get(url, {'uncategorized': '1'})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Migros')

        # Filtered to one category.
        resp = self.client.get(url, {'category': category.id})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Coop')

        # Transfers only.
        Transaction.objects.create(
            account=other_account, booking_date=date(2026, 8, 11),
            amount=Decimal('-99'), currency='CHF', counterparty='Broker',
            source='camt053', dedup_key='ref:R3', is_transfer=True,
        )
        resp = self.client.get(url, {'category': 'transfer'})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Broker')

    def test_uncategorized_excludes_transfers(self):
        """A transfer has no category by design — it is not awaiting a label.

        Listing transfers under "uncategorized" buries the entries that still
        need a decision under recurring own-account movements.
        """
        from portfolio.models import Transaction
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 5),
            amount=Decimal('-500'), currency='CHF', counterparty='Broker',
            source='camt053', dedup_key='ref:T1', is_transfer=True,
        )
        resp = self.client.get(reverse('transaction_list_all'), {'uncategorized': '1'})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Migros')

    def test_month_filter(self):
        from portfolio.models import Transaction
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 31),
            amount=Decimal('-10'), currency='CHF', counterparty='Coop',
            source='camt053', dedup_key='ref:M1',
        )
        url = reverse('transaction_list_all')

        resp = self.client.get(url, {'month': '2026-08'})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Migros')

        # The day before is a different month, not a rounding question.
        resp = self.client.get(url, {'month': '2026-07'})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Coop')

        # December must roll into the next year, not month 13.
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 12, 24),
            amount=Decimal('-99'), currency='CHF', counterparty='Xmas',
            source='camt053', dedup_key='ref:M2',
        )
        Transaction.objects.create(
            account=self.account, booking_date=date(2027, 1, 2),
            amount=Decimal('-99'), currency='CHF', counterparty='NewYear',
            source='camt053', dedup_key='ref:M3',
        )
        resp = self.client.get(url, {'month': '2026-12'})
        self.assertEqual(resp.data['count'], 1)
        self.assertEqual(resp.data['results'][0]['counterparty'], 'Xmas')

        # Filters combine.
        resp = self.client.get(url, {'month': '2026-08', 'uncategorized': '1'})
        self.assertEqual(resp.data['count'], 1)

    def test_sorting_by_column(self):
        """Sorting happens in the database — the list is paginated."""
        from portfolio.models import Transaction, TransactionCategory
        food = TransactionCategory.objects.create(user=self.user, name='Food')
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 1),
            amount=Decimal('-100'), currency='CHF', counterparty='Aldi',
            source='camt053', dedup_key='ref:S1', category=food,
        )
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 9, 1),
            amount=Decimal('-5'), currency='CHF', counterparty='Zoo',
            source='camt053', dedup_key='ref:S2',
        )
        url = reverse('transaction_list_all')

        def names(**params):
            return [t['counterparty'] for t in self.client.get(url, params).data['results']]

        # Default is unchanged: newest booking first.
        self.assertEqual(names(), ['Zoo', 'Migros', 'Aldi'])
        self.assertEqual(names(ordering='date'), ['Aldi', 'Migros', 'Zoo'])
        self.assertEqual(names(ordering='-date'), ['Zoo', 'Migros', 'Aldi'])
        # Amounts are signed: ascending starts at the biggest expense.
        self.assertEqual(names(ordering='amount'), ['Aldi', 'Migros', 'Zoo'])
        self.assertEqual(names(ordering='-amount'), ['Zoo', 'Migros', 'Aldi'])
        self.assertEqual(names(ordering='text'), ['Aldi', 'Migros', 'Zoo'])
        self.assertEqual(names(ordering='-text'), ['Zoo', 'Migros', 'Aldi'])

    def test_sorting_by_category_puts_uncategorized_last(self):
        """Ascending or descending, a missing category is not a value to sort."""
        from portfolio.models import Transaction, TransactionCategory
        for name, ref in (('Zebra', 'Z1'), ('Alpha', 'A1')):
            category = TransactionCategory.objects.create(user=self.user, name=name)
            Transaction.objects.create(
                account=self.account, booking_date=date(2026, 8, 2),
                amount=Decimal('-9'), currency='CHF', counterparty=name,
                source='camt053', dedup_key=f'ref:{ref}', category=category,
            )
        url = reverse('transaction_list_all')

        # self.imported has no category and must not lead either direction.
        asc = [t['counterparty'] for t in
               self.client.get(url, {'ordering': 'category'}).data['results']]
        desc = [t['counterparty'] for t in
                self.client.get(url, {'ordering': '-category'}).data['results']]
        self.assertEqual(asc, ['Alpha', 'Zebra', 'Migros'])
        self.assertEqual(desc, ['Zebra', 'Alpha', 'Migros'])

    def test_unknown_sort_key_is_rejected(self):
        """A pass-through ordering param could walk relations to other users."""
        resp = self.client.get(
            reverse('transaction_list_all'), {'ordering': 'account__user__password'})
        self.assertEqual(resp.status_code, 400)
        self.assertIn('Unknown sort key', str(resp.data['ordering']))

    def test_bad_month_is_rejected(self):
        resp = self.client.get(reverse('transaction_list_all'), {'month': 'August'})
        self.assertEqual(resp.status_code, 400)
        self.assertIn('YYYY-MM', str(resp.data['period']))

    def test_period_filter_by_quarter_and_year(self):
        from portfolio.models import Transaction
        Transaction.objects.create(
            account=self.account, booking_date=date(2025, 2, 3),
            amount=Decimal('-10'), currency='CHF', counterparty='Old',
            source='camt053', dedup_key='ref:P1',
        )
        url = reverse('transaction_list_all')

        # self.imported is 2026-08-01, so Q3 2026 holds it and Q1 2025 the other.
        self.assertEqual(
            [t['counterparty'] for t in
             self.client.get(url, {'period': '2026-Q3'}).data['results']],
            ['Migros'])
        self.assertEqual(
            [t['counterparty'] for t in
             self.client.get(url, {'period': '2025-Q1'}).data['results']],
            ['Old'])
        self.assertEqual(self.client.get(url, {'period': '2026'}).data['count'], 1)
        self.assertEqual(self.client.get(url, {'period': '2025'}).data['count'], 1)
        self.assertEqual(self.client.get(url, {'period': '2024'}).data['count'], 0)

    def _yearly_bill(self, booking_date, amount='-1200', spread=12, key='ref:S1'):
        from portfolio.models import Transaction
        return Transaction.objects.create(
            account=self.account, booking_date=booking_date,
            amount=Decimal(amount), currency='CHF', counterparty='AXA',
            source='camt053', dedup_key=key, spread_months=spread,
        )

    def test_normalized_period_lists_bills_spread_into_it(self):
        """A 2025 bill spread over a year is part of 2026's spending."""
        self._yearly_bill(date(2025, 7, 1))
        url = reverse('transaction_list_all')

        # Actual mode counts it entirely in its booking year, so 2026 is
        # unchanged — only self.imported (2026-08-01).
        self.assertEqual(
            [t['counterparty'] for t in
             self.client.get(url, {'period': '2026'}).data['results']],
            ['Migros'])

        # Normalized mode spreads July 2025 + 12 months over 2026-01..2026-06.
        results = self.client.get(
            url, {'period': '2026', 'mode': 'normalized'}).data['results']
        self.assertEqual(sorted(t['counterparty'] for t in results),
                         ['AXA', 'Migros'])
        axa = next(t for t in results if t['counterparty'] == 'AXA')
        self.assertEqual(axa['period_slice'],
                         {'months': 6, 'of': 12, 'amount': '-600.00'})
        # An unspread row in its own period has nothing to qualify.
        migros = next(t for t in results if t['counterparty'] == 'Migros')
        self.assertIsNone(migros['period_slice'])

    def test_spread_slice_is_reported_per_granularity(self):
        self._yearly_bill(date(2025, 7, 1))
        url = reverse('transaction_list_all')

        def slice_for(period):
            rows = self.client.get(
                url, {'period': period, 'mode': 'normalized'}).data['results']
            row = next((t for t in rows if t['counterparty'] == 'AXA'), None)
            return row and row['period_slice']

        self.assertEqual(slice_for('2025'), {'months': 6, 'of': 12, 'amount': '-600.00'})
        self.assertEqual(slice_for('2026-Q1'), {'months': 3, 'of': 12, 'amount': '-300.00'})
        self.assertEqual(slice_for('2026-03'), {'months': 1, 'of': 12, 'amount': '-100.00'})
        # July 2026 is past the end of the spread.
        self.assertIsNone(slice_for('2026-07'))

    def test_spread_row_only_reaches_forward_never_back(self):
        """A bill booked after the period never belongs to it."""
        self._yearly_bill(date(2026, 7, 1))
        rows = self.client.get(
            reverse('transaction_list_all'),
            {'period': '2025', 'mode': 'normalized'}).data['results']
        self.assertEqual([t['counterparty'] for t in rows], [])

    def test_normalized_without_a_period_changes_nothing(self):
        self._yearly_bill(date(2025, 7, 1))
        rows = self.client.get(
            reverse('transaction_list_all'), {'mode': 'normalized'}).data['results']
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(t['period_slice'] is None for t in rows))

    def test_spread_list_and_report_agree_on_the_period_total(self):
        """The list is only useful here if it adds up to the chart."""
        from portfolio.models import TransactionCategory
        from portfolio.spending import monthly_spending
        category = TransactionCategory.objects.create(user=self.user, name='Insurance')
        for i, booking in enumerate(
                [date(2025, 7, 1), date(2025, 11, 1), date(2026, 2, 1)]):
            bill = self._yearly_bill(booking, key=f'ref:S{i}')
            bill.category = category
            bill.save()
        report = monthly_spending(self.user, months=3, mode='normalized',
                                  granularity='year')
        charted = next(m['by_category']['Insurance'] for m in report['months']
                       if m['month'] == '2026')
        rows = self.client.get(
            reverse('transaction_list_all'),
            {'period': '2026', 'mode': 'normalized',
             'category': str(category.id)}).data['results']
        listed = sum(Decimal(t['period_slice']['amount']) for t in rows)
        self.assertEqual(charted, float(-listed))

    def _searchable(self):
        from portfolio.models import Transaction
        rows = [
            ('Migros Fil. 234', 'Einkauf', '-13.45'),
            ('Coop Pronto', 'Refund', '13.45'),
            ('Lidl Adliswil', 'Wocheneinkauf', '-99.00'),
            ('SBB', 'Billett Zürich', '-1234.50'),
        ]
        for i, (cp, desc, amount) in enumerate(rows):
            Transaction.objects.create(
                account=self.account, booking_date=date(2026, 8, 5),
                amount=Decimal(amount), currency='CHF', counterparty=cp,
                description=desc, source='camt053', dedup_key=f's{i}',
                counterparty_account='CH9300762011623852957',
            )

    def _search(self, term, **extra):
        resp = self.client.get(
            reverse('transaction_list_all'), {'search': term, **extra})
        self.assertEqual(resp.status_code, 200, resp.data)
        return sorted(t['counterparty'] for t in resp.data['results'])

    def test_search_matches_counterparty_and_description(self):
        self._searchable()
        self.assertEqual(self._search('migros'), ['Migros', 'Migros Fil. 234'])
        self.assertEqual(self._search('wocheneinkauf'), ['Lidl Adliswil'])
        # Case-insensitive and a substring, not a prefix.
        self.assertEqual(self._search('ADLISWIL'), ['Lidl Adliswil'])

    def test_search_matches_an_amount_regardless_of_sign(self):
        """A sign the user never typed must not decide what they find."""
        self._searchable()
        self.assertEqual(self._search('13.45'), ['Coop Pronto', 'Migros Fil. 234'])
        # The Swiss/German decimal comma means the same number.
        self.assertEqual(self._search('13,45'), ['Coop Pronto', 'Migros Fil. 234'])
        # As does the thousands apostrophe the list itself prints.
        self.assertEqual(self._search("1'234.50"), ['SBB'])
        self.assertEqual(self._search('1234,50'), ['SBB'])
        self.assertEqual(self._search('-99'), ['Lidl Adliswil'])

    def test_search_ignores_the_counterparty_iban(self):
        """The account filter covers accounts; IBAN digits would swamp amounts."""
        self._searchable()
        self.assertEqual(self._search('CH9300762011623852957'), [])

    def test_search_combines_with_the_other_filters(self):
        from portfolio.models import TransactionCategory
        self._searchable()
        food = TransactionCategory.objects.create(user=self.user, name='Food')
        from portfolio.models import Transaction
        Transaction.objects.filter(counterparty='Lidl Adliswil').update(category=food)
        self.assertEqual(
            self._search('adliswil', category=str(food.id)), ['Lidl Adliswil'])
        self.assertEqual(self._search('adliswil', period='2020'), [])

    def test_search_that_is_neither_text_nor_a_number_finds_nothing(self):
        self._searchable()
        self.assertEqual(self._search('zzzz'), [])
        # A blank search is not a filter at all.
        self.assertEqual(len(self._search('   ')), 5)

    def test_amount_query_parsing(self):
        from portfolio.views import TransactionListView as V
        for text, expected in (
            ('13.45', Decimal('13.45')),
            ('13,45', Decimal('13.45')),
            ("1'234.50", Decimal('1234.50')),
            ('1.234,50', Decimal('1234.50')),   # German thousands + decimal
            ('1,234.50', Decimal('1234.50')),   # English thousands + decimal
            ('-99', Decimal('99')),
            ('+7', Decimal('7')),
            ('migros', None),
            ('', None),
            ('13.45.67', None),
        ):
            self.assertEqual(V._search_amount(text), expected, text)

    def test_several_categories_at_once(self):
        """The breakdown chips ask for "groceries plus restaurants"."""
        from portfolio.models import Transaction, TransactionCategory
        food = TransactionCategory.objects.create(user=self.user, name='Food')
        travel = TransactionCategory.objects.create(user=self.user, name='Travel')
        other = TransactionCategory.objects.create(user=self.user, name='Other')
        for cat, ref in ((food, 'C1'), (travel, 'C2'), (other, 'C3')):
            Transaction.objects.create(
                account=self.account, booking_date=date(2026, 8, 3),
                amount=Decimal('-7'), currency='CHF', counterparty=cat.name,
                source='camt053', dedup_key=f'ref:{ref}', category=cat,
            )
        resp = self.client.get(
            reverse('transaction_list_all'),
            {'category': f'{food.id},{travel.id}'})
        self.assertEqual(
            sorted(t['counterparty'] for t in resp.data['results']),
            ['Food', 'Travel'])

    def test_foreign_category_id_in_a_list_leaks_nothing(self):
        """One own id next to a foreign one must not widen the query."""
        from portfolio.models import Transaction, TransactionCategory
        mine = TransactionCategory.objects.create(user=self.user, name='Mine')
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 4),
            amount=Decimal('-3'), currency='CHF', counterparty='Mine',
            source='camt053', dedup_key='ref:F1', category=mine,
        )
        other, _, _ = make_kek_user(username='mallory2')
        foreign = TransactionCategory.objects.create(user=other, name='Theirs')
        resp = self.client.get(
            reverse('transaction_list_all'),
            {'category': f'{foreign.id},{mine.id}'})
        self.assertEqual(
            [t['counterparty'] for t in resp.data['results']], ['Mine'])

    def test_category_filter_does_not_leak_other_users_categories(self):
        from portfolio.models import TransactionCategory
        other, _, _ = make_kek_user(username='mallory')
        foreign = TransactionCategory.objects.create(user=other, name='Food')
        resp = self.client.get(
            reverse('transaction_list_all'), {'category': foreign.id})
        self.assertEqual(resp.data['count'], 0)

    def test_global_list_is_scoped_to_the_user(self):
        other, _, _ = make_kek_user(username='eve')
        self.client.force_authenticate(user=other)
        resp = self.client.get(reverse('transaction_list_all'))
        self.assertEqual(resp.data['count'], 0)

    def test_other_users_account_is_empty(self):
        other, _, _ = make_kek_user(username='bob')
        self.client.force_authenticate(user=other)
        resp = self.client.get(self._list_url())
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['results'], [])

    def test_create_manual_transaction_defaults_currency(self):
        from portfolio.models import Transaction
        resp = self.client.post(self._list_url(), {
            'booking_date': '2026-08-05', 'amount': '-9.90', 'description': 'Kiosk',
        }, format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        tx = Transaction.objects.get(pk=resp.data['id'])
        self.assertEqual(tx.source, 'manual')
        self.assertEqual(tx.currency, 'CHF')
        self.assertTrue(tx.dedup_key.startswith('manual:'))

    def test_manual_transaction_can_be_deleted(self):
        resp = self.client.post(self._list_url(), {
            'booking_date': '2026-08-05', 'amount': '-1.00',
        }, format='json')
        detail = reverse('transaction_detail', kwargs={'pk': resp.data['id']})
        self.assertEqual(self.client.delete(detail).status_code, 204)

    def test_imported_transaction_financials_immutable_and_undeletable(self):
        # Classification PATCHes are allowed on imported rows; the bank's own
        # fields are read-only (silently ignored), and deletion is rejected.
        detail = reverse('transaction_detail', kwargs={'pk': self.imported.id})
        resp = self.client.patch(detail, {'description': 'x'}, format='json')
        self.assertEqual(resp.status_code, 200)
        self.imported.refresh_from_db()
        self.assertEqual(self.imported.description, '')
        self.assertEqual(self.client.delete(detail).status_code, 400)


class ClassificationTests(TestCase):
    """Category rules and transfer detection."""

    def setUp(self):
        from portfolio.models import CategoryRule, TransactionCategory
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.checking = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='CHF',
            account_identifier='CH-GIRO',
        )
        self.savings = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Sparen', currency='CHF',
            account_identifier='CH-SPAR',
        )
        self.groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        self.insurance = TransactionCategory.objects.create(user=self.user, name='Insurance')
        CategoryRule.objects.create(user=self.user, match_text='migros', category=self.groceries)
        CategoryRule.objects.create(
            user=self.user, match_text='axa', category=self.insurance, spread_months=12,
        )

    def _tx(self, account=None, **kwargs):
        from portfolio.models import Transaction
        defaults = dict(
            account=account or self.checking, booking_date=date(2026, 8, 1),
            amount=Decimal('-50'), currency='CHF', source='camt053',
        )
        defaults.update(kwargs)
        defaults.setdefault('dedup_key', f"t-{len(Transaction.objects.all())}-{kwargs}")
        return Transaction.objects.create(**defaults)

    def test_rules_match_case_insensitive_and_set_spread(self):
        from portfolio.classification import apply_rules
        grocery_tx = self._tx(counterparty='MIGROS Zuerich')
        insurance_tx = self._tx(description='AXA Jahresrechnung')
        self.assertEqual(apply_rules(self.user), 2)
        grocery_tx.refresh_from_db()
        insurance_tx.refresh_from_db()
        self.assertEqual(grocery_tx.category, self.groceries)
        self.assertEqual(grocery_tx.spread_months, 1)
        self.assertEqual(insurance_tx.category, self.insurance)
        self.assertEqual(insurance_tx.spread_months, 12)

    def test_rules_respect_manual_category(self):
        from portfolio.classification import apply_rules
        tx = self._tx(counterparty='Migros', category=self.insurance, category_manual=True)
        # Also uncategorized-but-manually-cleared rows stay untouched.
        cleared = self._tx(counterparty='Migros', category=None, category_manual=True)
        self.assertEqual(apply_rules(self.user), 0)
        tx.refresh_from_db()
        self.assertEqual(tx.category, self.insurance)
        cleared.refresh_from_db()
        self.assertIsNone(cleared.category)

    def test_transfer_pairing_across_accounts(self):
        from portfolio.classification import detect_transfers
        out_tx = self._tx(amount=Decimal('-500'), booking_date=date(2026, 8, 26))
        in_tx = self._tx(
            account=self.savings, amount=Decimal('500'), booking_date=date(2026, 8, 27),
        )
        unrelated = self._tx(amount=Decimal('-77'), counterparty='Shop')
        self.assertEqual(detect_transfers(self.user), 2)
        out_tx.refresh_from_db(); in_tx.refresh_from_db(); unrelated.refresh_from_db()
        self.assertTrue(out_tx.is_transfer)
        self.assertEqual(out_tx.transfer_peer_id, in_tx.id)
        self.assertTrue(in_tx.is_transfer)
        self.assertFalse(unrelated.is_transfer)

    def test_transfer_by_own_iban(self):
        from portfolio.classification import detect_transfers
        tx = self._tx(amount=Decimal('-300'), counterparty_account='CH-SPAR')
        self.assertEqual(detect_transfers(self.user), 1)
        tx.refresh_from_db()
        self.assertTrue(tx.is_transfer)

    def test_transfer_detection_respects_manual_flag(self):
        from portfolio.classification import detect_transfers
        self._tx(amount=Decimal('-500'), transfer_manual=True)
        self._tx(account=self.savings, amount=Decimal('500'))
        self.assertEqual(detect_transfers(self.user), 0)


class SpendingReportTests(TestCase):
    def setUp(self):
        from portfolio.models import TransactionCategory
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='EUR',
        )
        self.user.profile.base_currency = 'EUR'
        self.user.profile.save()
        self.groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')

    def _tx(self, **kwargs):
        from portfolio.models import Transaction
        defaults = dict(
            account=self.account, booking_date=date.today().replace(day=1),
            amount=Decimal('-100'), currency='EUR', source='camt053',
        )
        defaults.update(kwargs)
        defaults.setdefault('dedup_key', f"t-{Transaction.objects.count()}")
        return Transaction.objects.create(**defaults)

    def test_actual_vs_normalized_amortization(self):
        from portfolio.spending import monthly_spending
        self._tx(amount=Decimal('-1200'), spread_months=12, category=self.groceries)
        self._tx(amount=Decimal('1000'))

        actual = monthly_spending(self.user, months=1, mode='actual')
        self.assertEqual(actual['months'][-1]['expenses'], 1200.0)
        self.assertEqual(actual['months'][-1]['income'], 1000.0)

        normalized = monthly_spending(self.user, months=1, mode='normalized')
        self.assertEqual(normalized['months'][-1]['expenses'], 100.0)
        self.assertEqual(normalized['months'][-1]['by_category'], {'Groceries': 100.0})

    def test_yearly_granularity_sums_the_months_of_each_year(self):
        """"What do I pay for this in a year" is one bucket, not twelve rows."""
        from portfolio.spending import monthly_spending
        today = date.today()
        for month in range(1, today.month + 1):
            self._tx(booking_date=date(today.year, month, 1),
                     amount=Decimal('-10'), category=self.groceries)
        # Last year, so the window must reach back a full calendar year.
        self._tx(booking_date=date(today.year - 1, 6, 15), amount=Decimal('-70'),
                 category=self.groceries)

        report = monthly_spending(self.user, months=2, mode='actual',
                                  granularity='year')
        self.assertEqual(report['granularity'], 'year')
        self.assertEqual([m['month'] for m in report['months']],
                         [str(today.year - 1), str(today.year)])
        self.assertEqual(report['months'][0]['expenses'], 70.0)
        self.assertEqual(report['months'][-1]['expenses'], today.month * 10.0)
        self.assertEqual(report['months'][-1]['by_category'],
                         {'Groceries': today.month * 10.0})

    def test_quarterly_granularity_starts_at_the_quarter_boundary(self):
        from portfolio.spending import monthly_spending
        report = monthly_spending(self.user, months=4, mode='actual',
                                  granularity='quarter')
        labels = [m['month'] for m in report['months']]
        self.assertEqual(len(labels), 4)
        quarter = (date.today().month - 1) // 3 + 1
        self.assertEqual(labels[-1], f'{date.today().year}-Q{quarter}')
        for label in labels:
            self.assertRegex(label, r'^\d{4}-Q[1-4]$')

    def test_an_unknown_granularity_falls_back_to_months(self):
        from portfolio.spending import monthly_spending
        report = monthly_spending(self.user, months=2, granularity='decade')
        self.assertEqual(report['granularity'], 'month')
        self.assertRegex(report['months'][-1]['month'], r'^\d{4}-\d{2}$')

    def test_period_bounds_parses_every_label_it_produces(self):
        from portfolio.spending import period_bounds, period_label
        cases = {
            '2026-08': (date(2026, 8, 1), date(2026, 9, 1)),
            '2026-12': (date(2026, 12, 1), date(2027, 1, 1)),
            '2026-Q1': (date(2026, 1, 1), date(2026, 4, 1)),
            '2026-Q4': (date(2026, 10, 1), date(2027, 1, 1)),
            '2026': (date(2026, 1, 1), date(2027, 1, 1)),
        }
        for label, expected in cases.items():
            self.assertEqual(period_bounds(label), expected, label)
        for bad in ('', 'August', '2026-Q5', '2026-13', 'Q1', None):
            self.assertIsNone(period_bounds(bad), bad)
        # Labels round-trip: whatever the report emits, the filter can parse.
        index = 2026 * 12 + 7
        for granularity in ('month', 'quarter', 'year'):
            self.assertIsNotNone(period_bounds(period_label(index, granularity)))

    def test_budgets_scale_with_the_period(self):
        """A budget is a monthly number; a year of it is twelve."""
        from portfolio.spending import monthly_spending
        self.groceries.monthly_budget = Decimal('400')
        self.groceries.save()

        monthly = monthly_spending(self.user, months=1, granularity='month')
        self.assertEqual(monthly['budgets'], {'Groceries': 400.0})
        quarterly = monthly_spending(self.user, months=1, granularity='quarter')
        self.assertEqual(quarterly['budgets'], {'Groceries': 1200.0})
        yearly = monthly_spending(self.user, months=1, granularity='year')
        self.assertEqual(yearly['budgets'], {'Groceries': 4800.0})

    def test_categories_without_a_budget_are_absent(self):
        from portfolio.spending import monthly_spending
        self.assertEqual(monthly_spending(self.user, months=1)['budgets'], {})

    def test_transfers_are_excluded(self):
        from portfolio.spending import monthly_spending
        self._tx(amount=Decimal('-500'), is_transfer=True)
        self._tx(amount=Decimal('-40'))
        report = monthly_spending(self.user, months=1, mode='actual')
        self.assertEqual(report['months'][-1]['expenses'], 40.0)

    def test_uncategorized_bucket(self):
        from portfolio.spending import monthly_spending
        self._tx(amount=Decimal('-25'))
        report = monthly_spending(self.user, months=1, mode='actual')
        self.assertEqual(report['months'][-1]['by_category'], {'Uncategorized': 25.0})

    def test_foreign_currency_uses_most_recent_stored_rate(self):
        from portfolio.spending import monthly_spending
        booking = date.today().replace(day=1)
        # No rate on the booking date itself — the report must fall back to the
        # most recent earlier rate, without asking the rate API.
        ExchangeRate.objects.create(
            from_currency='CHF', to_currency='EUR',
            rate_date=booking - timedelta(days=3), rate=Decimal('1.05'),
        )
        self._tx(amount=Decimal('-100'), currency='CHF', booking_date=booking)
        report = monthly_spending(self.user, months=1, mode='actual')
        self.assertEqual(report['months'][-1]['expenses'], 105.0)

    def test_foreign_currency_inverse_pair(self):
        from portfolio.spending import monthly_spending
        # Only the opposite direction is stored (EUR->CHF); the report inverts
        # it. The rate is also dated today while the booking may be older —
        # bookings before the earliest stored rate clamp to that rate.
        ExchangeRate.objects.create(
            from_currency='EUR', to_currency='CHF',
            rate_date=date.today(), rate=Decimal('2'),
        )
        self._tx(amount=Decimal('-100'), currency='CHF',
                 booking_date=date.today().replace(day=1))
        report = monthly_spending(self.user, months=1, mode='actual')
        self.assertEqual(report['months'][-1]['expenses'], 50.0)

    def test_rate_lookup_is_bulk_not_per_transaction(self):
        from portfolio.spending import monthly_spending
        booking = date.today().replace(day=1)
        ExchangeRate.objects.create(
            from_currency='CHF', to_currency='EUR',
            rate_date=booking, rate=Decimal('1'),
        )
        for i in range(8):
            self._tx(amount=Decimal('-10'), currency='CHF', booking_date=booking)
        # transactions + distinct currencies + one rate-series fetch + budgets.
        # A fixed count whatever the data: per-date rate lookups would scale
        # with the transaction count, which is what this guards against.
        with self.assertNumQueries(4):
            monthly_spending(self.user, months=1, mode='actual')

        for i in range(8, 24):
            self._tx(amount=Decimal('-10'), currency='CHF', booking_date=booking)
        with self.assertNumQueries(4):
            monthly_spending(self.user, months=1, mode='actual')


class ClassificationApiTests(APITestCase):
    def setUp(self):
        from portfolio.models import Transaction, TransactionCategory
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='CHF',
        )
        self.category = TransactionCategory.objects.create(user=self.user, name='Groceries')
        self.imported = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 1),
            amount=Decimal('-25.50'), currency='CHF', counterparty='Migros',
            source='camt053', dedup_key='ref:R1',
        )
        self.client.force_authenticate(user=self.user)

    def test_classify_imported_transaction(self):
        detail = reverse('transaction_detail', kwargs={'pk': self.imported.id})
        resp = self.client.patch(detail, {'category': self.category.id}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['category_name'], 'Groceries')
        self.imported.refresh_from_db()
        self.assertTrue(self.imported.category_manual)

    def test_imported_financial_fields_stay_readonly(self):
        detail = reverse('transaction_detail', kwargs={'pk': self.imported.id})
        resp = self.client.patch(detail, {'amount': '-1.00'}, format='json')
        self.assertEqual(resp.status_code, 200)
        self.imported.refresh_from_db()
        self.assertEqual(self.imported.amount, Decimal('-25.50'))

    def test_cannot_use_other_users_category(self):
        from portfolio.models import TransactionCategory
        other, _, _ = make_kek_user(username='bob')
        foreign = TransactionCategory.objects.create(user=other, name='Theirs')
        detail = reverse('transaction_detail', kwargs={'pk': self.imported.id})
        resp = self.client.patch(detail, {'category': foreign.id}, format='json')
        self.assertEqual(resp.status_code, 400)

    def test_single_transaction_can_be_spread(self):
        """A one-off yearly bill has no rule to hang a spread on."""
        detail = reverse('transaction_detail', kwargs={'pk': self.imported.id})
        resp = self.client.patch(detail, {'spread_months': 12}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['spread_months'], 12)
        self.imported.refresh_from_db()
        self.assertEqual(self.imported.spread_months, 12)

    def test_marking_a_spread_transaction_as_transfer_drops_the_spread(self):
        """A transfer never reaches the report, so a spread on it is dead data.

        The UI hides the spread control for transfers — a leftover value would
        sit there invisibly and come back if the transfer flag were removed.
        """
        self.imported.spread_months = 12
        self.imported.save()
        detail = reverse('transaction_detail', kwargs={'pk': self.imported.id})
        resp = self.client.patch(detail, {'is_transfer': True}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['spread_months'], 1)
        self.imported.refresh_from_db()
        self.assertTrue(self.imported.is_transfer)
        self.assertEqual(self.imported.spread_months, 1)

    def test_correcting_a_transaction_names_the_rule_behind_it(self):
        """A rule that mislabels one booking mislabels every future one.

        The correction is per transaction, so without this the user fixes the
        same merchant again next month and never learns why.
        """
        from portfolio.models import CategoryRule, TransactionCategory
        wrong = TransactionCategory.objects.create(user=self.user, name='Shopping')
        CategoryRule.objects.create(
            user=self.user, match_text='migros', category=wrong, position=0)
        detail = reverse('transaction_detail', kwargs={'pk': self.imported.id})

        resp = self.client.patch(detail, {'category': self.category.id}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['stale_rule']['match_text'], 'migros')
        self.assertEqual(resp.data['stale_rule']['category_name'], 'Shopping')

    def test_no_prompt_when_the_rule_already_agrees(self):
        """Re-picking the category a rule assigns is not worth interrupting."""
        from portfolio.models import CategoryRule
        CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.category, position=0)
        resp = self.client.patch(
            reverse('transaction_detail', kwargs={'pk': self.imported.id}),
            {'category': self.category.id}, format='json')
        self.assertNotIn('stale_rule', resp.data)

    def test_no_prompt_without_a_matching_rule(self):
        resp = self.client.patch(
            reverse('transaction_detail', kwargs={'pk': self.imported.id}),
            {'category': self.category.id}, format='json')
        self.assertNotIn('stale_rule', resp.data)

    def test_spread_change_names_the_rule_that_sets_a_different_spread(self):
        from portfolio.models import CategoryRule
        CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.category,
            spread_months=1, position=0)
        resp = self.client.patch(
            reverse('transaction_detail', kwargs={'pk': self.imported.id}),
            {'spread_months': 12}, format='json')
        self.assertEqual(resp.data['stale_rule']['match_text'], 'migros')

    def test_clearing_the_category_prompts_nothing(self):
        """A rule must target a category or the transfer flag — "none" is
        neither, so there is nothing to offer."""
        from portfolio.models import CategoryRule
        CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.category, position=0)
        resp = self.client.patch(
            reverse('transaction_detail', kwargs={'pk': self.imported.id}),
            {'category': None}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertNotIn('stale_rule', resp.data)

    def test_rule_create_applies_retroactively(self):
        resp = self.client.post(reverse('rule_list'), {
            'match_text': 'migros', 'category': self.category.id,
        }, format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        self.imported.refresh_from_db()
        self.assertEqual(self.imported.category, self.category)

    def test_monthly_report_endpoint(self):
        resp = self.client.get(reverse('spending_monthly'), {'months': 2, 'mode': 'actual'})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data['months']), 2)
        self.assertEqual(resp.data['base_currency'], self.user.profile.base_currency)


class AiCategorizationClientTests(TestCase):
    """Gemini client: pricing lookup, model listing, suggestion parsing."""

    def test_price_prefix_matching_prefers_longest(self):
        from portfolio.ai_categorization import price_for_model
        self.assertEqual(price_for_model('gemini-3.5-flash-lite-001'), (0.30, 2.50))
        self.assertEqual(price_for_model('gemini-3.5-flash'), (1.50, 9.00))
        self.assertIsNone(price_for_model('gemini-unknown-model'))

    @patch('portfolio.ai_categorization.requests.get')
    def test_list_models_filters_and_prices(self, m_get):
        from portfolio.ai_categorization import list_models
        m_get.return_value = MagicMock(status_code=200, json=lambda: {'models': [
            {'name': 'models/gemini-3.6-flash', 'displayName': 'Gemini 3.6 Flash',
             'supportedGenerationMethods': ['generateContent']},
            {'name': 'models/gemini-embedding-001', 'displayName': 'Embedding',
             'supportedGenerationMethods': ['embedContent']},
            {'name': 'models/imagen-4', 'displayName': 'Imagen',
             'supportedGenerationMethods': ['generateContent']},
        ]})
        models = list_models('key')
        self.assertEqual(len(models), 1)
        self.assertEqual(models[0]['id'], 'gemini-3.6-flash')
        self.assertEqual(models[0]['input_price_per_1m'], 0.75)

    @patch('portfolio.ai_categorization.requests.get')
    def test_list_models_invalid_key_is_friendly(self, m_get):
        from portfolio.ai_categorization import GeminiError, list_models
        m_get.return_value = MagicMock(status_code=400, json=lambda: {
            'error': {'message': 'API key not valid. Please pass a valid API key.'}})
        with self.assertRaises(GeminiError) as ctx:
            list_models('bad')
        self.assertIn('not valid', str(ctx.exception))

    @patch('portfolio.ai_categorization.requests.post')
    def test_suggest_parses_assignments_rules_and_cost(self, m_post):
        import json as jsonlib
        from portfolio.ai_categorization import suggest_categories
        m_post.return_value = MagicMock(status_code=200, json=lambda: {
            'candidates': [{'content': {'parts': [{'text': jsonlib.dumps({
                'assignments': [{'id': 1, 'category': 'Health'}, {'bogus': True}],
                'rules': [{'match_text': 'apotheke', 'category': 'Health'}, {'match_text': ''}],
            })}]}}],
            'usageMetadata': {'promptTokenCount': 1000, 'candidatesTokenCount': 500},
        })
        result = suggest_categories(
            'key', 'gemini-3.6-flash',
            [{'id': 1, 'counterparty': 'Apotheke', 'description': '', 'amount': '-10', 'currency': 'EUR'}],
            ['Groceries'],
        )
        self.assertEqual(result['assignments'], [{'id': 1, 'category': 'Health'}])
        self.assertEqual(result['rules'], [{'match_text': 'apotheke', 'category': 'Health'}])
        self.assertAlmostEqual(result['usage']['estimated_cost_usd'], 0.002625)

    @patch('portfolio.ai_categorization.requests.post')
    def test_suggest_modes_use_separate_prompts(self, m_post):
        import json as jsonlib
        from portfolio.ai_categorization import suggest_categories
        m_post.return_value = MagicMock(status_code=200, json=lambda: {
            'candidates': [{'content': {'parts': [{'text': jsonlib.dumps({
                'assignments': [{'id': 1, 'category': 'Health'}],
                'rules': [{'match_text': 'apotheke', 'category': 'Health'}],
            })}]}}],
            'usageMetadata': {},
        })
        tx = [{'id': 1, 'counterparty': 'Apotheke', 'description': '',
               'amount': '-10', 'currency': 'EUR'}]

        suggest_categories('key', 'gemini-3.6-flash', tx, [], mode='items')
        items_prompt = m_post.call_args.kwargs['json']['contents'][0]['parts'][0]['text']
        self.assertIn('Do NOT propose', items_prompt)

        suggest_categories(
            'key', 'gemini-3.6-flash', tx, [], mode='rules',
            existing_rules=['rewe -> Groceries'],
        )
        rules_prompt = m_post.call_args.kwargs['json']['contents'][0]['parts'][0]['text']
        self.assertIn('rewe -> Groceries', rules_prompt)
        self.assertIn('Do NOT assign', rules_prompt)


class AiEndpointTests(APITestCase):
    def setUp(self):
        from portfolio.models import Transaction
        self.user, self.kek, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='EUR',
        )
        self.tx = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 1),
            amount=Decimal('-19.90'), currency='EUR', counterparty='Apotheke am Markt',
            source='camt053', dedup_key='ref:A1',
        )
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def test_config_roundtrip_stores_key_encrypted(self):
        resp = self.client.put(reverse('ai_config'), {
            'api_key': 'AIza-test', 'model': 'gemini-3.6-flash',
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.user.profile.refresh_from_db()
        self.assertTrue(self.user.profile.encrypted_gemini_key)
        self.assertNotIn(b'AIza-test', bytes(self.user.profile.encrypted_gemini_key))
        resp = self.client.get(reverse('ai_config'))
        self.assertTrue(resp.data['configured'])
        self.assertEqual(resp.data['model'], 'gemini-3.6-flash')
        self.assertTrue(resp.data['disclosed_fields'])

    def test_config_requires_kek(self):
        self.client.credentials()  # drop X-KEK
        resp = self.client.put(reverse('ai_config'), {'api_key': 'x'}, format='json')
        self.assertEqual(resp.status_code, 403)

    @patch('portfolio.ai_categorization.suggest_categories')
    def test_suggest_returns_disclosure_and_flags_new_categories(self, m_suggest):
        from portfolio.models import TransactionCategory
        TransactionCategory.objects.create(user=self.user, name='Groceries')
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        m_suggest.return_value = {
            'assignments': [
                {'id': self.tx.id, 'category': 'Health'},
                {'id': 999999, 'category': 'Ignored'},
            ],
            'rules': [{'match_text': 'apotheke', 'category': 'Health'}],
            'usage': {'input_tokens': 10, 'output_tokens': 5, 'estimated_cost_usd': 0.0001},
        }
        resp = self.client.post(reverse('ai_suggest'), {}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(len(resp.data['suggestions']), 1)
        self.assertTrue(resp.data['suggestions'][0]['is_new_category'])
        self.assertEqual(resp.data['sent_count'], 1)
        self.assertTrue(resp.data['disclosed_fields'])
        # The suggestion is NOT persisted without confirmation.
        self.tx.refresh_from_db()
        self.assertIsNone(self.tx.category)

    @patch('portfolio.ai_categorization.suggest_categories')
    def test_suggest_rules_mode_passes_existing_rules(self, m_suggest):
        from portfolio.models import CategoryRule, TransactionCategory
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        rewe = CategoryRule.objects.create(
            user=self.user, match_text='rewe', category=groceries, position=0)
        broker = CategoryRule.objects.create(
            user=self.user, match_text='broker top', is_transfer=True, position=1)
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        m_suggest.return_value = {
            'assignments': [],
            'rules': [{'match_text': 'apotheke', 'category': 'Health'}],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': 0.0},
        }
        resp = self.client.post(reverse('ai_suggest'), {'mode': 'rules'}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(m_suggest.call_args.kwargs['mode'], 'rules')
        self.assertEqual(
            m_suggest.call_args.kwargs['existing_rules'],
            [f'{rewe.id} | rewe | Groceries',
             f'{broker.id} | broker top | Transfer'],
        )
        self.assertEqual(resp.data['suggestions'], [])
        self.assertEqual(len(resp.data['rules']), 1)

    @patch('portfolio.ai_categorization.suggest_categories')
    def test_suggest_rules_mode_regex_replaces_and_transfer(self, m_suggest):
        from portfolio.models import CategoryRule, TransactionCategory
        subs = TransactionCategory.objects.create(user=self.user, name='Subscriptions')
        yt = CategoryRule.objects.create(
            user=self.user, match_text='youtubepremium', category=subs, position=0)
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        m_suggest.return_value = {
            'assignments': [],
            'rules': [
                # Variant-merging regex proposal, explicitly replacing a rule.
                {'match_text': 'dm[-.]drogerie', 'category': 'Groceries',
                 'is_regex': True, 'replaces': None},
                # Near-duplicate of an existing rule with no replaces set —
                # linked deterministically via normalization.
                {'match_text': 'youtube premium', 'category': 'Subscriptions'},
                # Exact duplicate — dropped as noise.
                {'match_text': 'youtubepremium', 'category': 'Subscriptions'},
                # Broken regex — dropped (it would silently match nothing).
                {'match_text': '(broker', 'category': 'X', 'is_regex': True},
                # Transfer rule: no category.
                {'match_text': 'broker top-up', 'transfer': True},
            ],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': 0.0},
        }
        resp = self.client.post(reverse('ai_suggest'), {'mode': 'rules'}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        rules = resp.data['rules']
        self.assertEqual(len(rules), 3)
        self.assertTrue(rules[0]['is_regex'])
        self.assertEqual(rules[1]['replaces_rule_id'], yt.id)
        self.assertEqual(rules[1]['replaced_match_text'], 'youtubepremium')
        self.assertTrue(rules[2]['is_transfer'])
        self.assertIsNone(rules[2]['category'])

    @patch('portfolio.ai_categorization.suggest_categories')
    def test_suggest_items_mode_can_flag_transfers(self, m_suggest):
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        m_suggest.return_value = {
            'assignments': [{'id': self.tx.id, 'transfer': True}],
            'rules': [],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': 0.0},
        }
        resp = self.client.post(reverse('ai_suggest'), {'mode': 'items'}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertTrue(resp.data['suggestions'][0]['is_transfer'])
        self.assertIsNone(resp.data['suggestions'][0]['category'])

    def test_apply_transfer_assignment_and_rule_replacement(self):
        from portfolio.models import CategoryRule, TransactionCategory
        subs = TransactionCategory.objects.create(user=self.user, name='Subscriptions')
        yt = CategoryRule.objects.create(
            user=self.user, match_text='youtubepremium', category=subs,
            position=0, spread_months=3)
        resp = self.client.post(reverse('ai_apply'), {
            'assignments': [
                {'transaction_id': self.tx.id, 'is_transfer': True},
            ],
            'rules': [
                {'match_text': 'youtube ?premium', 'category': 'Subscriptions',
                 'is_regex': True, 'replaces_rule_id': yt.id},
                {'match_text': 'broker top-up', 'is_transfer': True},
            ],
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['assigned'], 1)
        self.assertEqual(resp.data['rules_updated'], 1)
        self.assertEqual(resp.data['rules_created'], 1)
        self.tx.refresh_from_db()
        self.assertTrue(self.tx.is_transfer)
        self.assertTrue(self.tx.transfer_manual)
        yt.refresh_from_db()
        # Updated in place: pattern and regex flag change, position and
        # spread survive, no duplicate rule appears.
        self.assertEqual(yt.match_text, 'youtube ?premium')
        self.assertTrue(yt.is_regex)
        self.assertEqual(yt.position, 0)
        self.assertEqual(yt.spread_months, 3)
        transfer_rule = CategoryRule.objects.get(
            user=self.user, match_text='broker top-up')
        self.assertTrue(transfer_rule.is_transfer)
        self.assertIsNone(transfer_rule.category)

    @patch('portfolio.ai_categorization.suggest_categories')
    def test_suggest_items_mode_sends_no_rules_context(self, m_suggest):
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        m_suggest.return_value = {
            'assignments': [{'id': self.tx.id, 'category': 'Health'}],
            'rules': [],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': 0.0},
        }
        resp = self.client.post(reverse('ai_suggest'), {'mode': 'items'}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(m_suggest.call_args.kwargs['mode'], 'items')
        self.assertIsNone(m_suggest.call_args.kwargs['existing_rules'])
        self.assertEqual(len(resp.data['suggestions']), 1)
        self.assertEqual(resp.data['rules'], [])

    def test_apply_confirmed_suggestions(self):
        from portfolio.models import CategoryRule, Transaction, TransactionCategory
        other = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 2),
            amount=Decimal('-5.00'), currency='EUR', counterparty='Apotheke Nord',
            source='camt053', dedup_key='ref:A2',
        )
        resp = self.client.post(reverse('ai_apply'), {
            'assignments': [{'transaction_id': self.tx.id, 'category': 'Health'}],
            'rules': [{'match_text': 'apotheke', 'category': 'Health'}],
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['assigned'], 1)
        self.assertEqual(resp.data['rules_created'], 1)
        self.tx.refresh_from_db()
        self.assertEqual(self.tx.category.name, 'Health')
        self.assertTrue(self.tx.category_manual)
        # The created rule immediately categorized the other apotheke transaction.
        other.refresh_from_db()
        self.assertEqual(other.category.name, 'Health')
        self.assertEqual(TransactionCategory.objects.filter(user=self.user).count(), 1)
        self.assertEqual(CategoryRule.objects.filter(user=self.user).count(), 1)

    @patch('portfolio.ai_categorization.relabel_similar')
    def test_relabel_proposes_similar_without_persisting(self, m_relabel):
        from portfolio.models import Transaction, TransactionCategory
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        # The corrected transaction: manually set to Health.
        self.tx.category = health
        self.tx.category_manual = True
        self.tx.save()
        # Mislabeled twin (rule/AI decision, not manual) and an unrelated entry.
        twin = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 15),
            amount=Decimal('-12.30'), currency='EUR', counterparty='Apotheke am Markt',
            category=groceries, source='camt053', dedup_key='ref:A2',
        )
        # No shared word — never reaches the candidate pool.
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 1),
            amount=Decimal('-50.00'), currency='EUR', counterparty='Coop Pronto',
            category=groceries, source='camt053', dedup_key='ref:A3',
        )
        # Similar but already in the corrected category — nothing to fix.
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 6, 20),
            amount=Decimal('-8.00'), currency='EUR', counterparty='Apotheke am Markt',
            category=health, source='camt053', dedup_key='ref:A4',
        )
        m_relabel.return_value = {
            'ids': [twin.id, 999999],
            'rules': [{'match_text': 'apotheke', 'category': 'WrongName'}],
            'usage': {'input_tokens': 10, 'output_tokens': 5, 'estimated_cost_usd': 0.0001},
        }
        resp = self.client.post(reverse('ai_relabel'), {
            'transaction_id': self.tx.id,
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        # Only the twin we sent; the hallucinated id is dropped.
        self.assertEqual(
            [s['transaction_id'] for s in resp.data['suggestions']], [twin.id])
        self.assertEqual(resp.data['suggestions'][0]['category'], 'Health')
        self.assertEqual(resp.data['suggestions'][0]['current_category'], 'Groceries')
        # The rule is pinned to the corrected category, whatever the model said.
        self.assertEqual(resp.data['rules'][0]['category'], 'Health')
        self.assertTrue(resp.data['disclosed_fields'])
        # Candidates: the twin only — same-category and the corrected tx excluded.
        self.assertEqual(resp.data['sent_count'], 1)
        # Nothing persisted without confirmation.
        twin.refresh_from_db()
        self.assertEqual(twin.category, groceries)

    @patch('portfolio.ai_categorization.relabel_similar')
    def test_relabel_skips_manual_and_uncategorized_candidates(self, m_relabel):
        from portfolio.models import Transaction, TransactionCategory
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        self.tx.category = health
        self.tx.category_manual = True
        self.tx.save()
        # A manual decision must never be proposed for overwriting…
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 10),
            amount=Decimal('-9.99'), currency='EUR', counterparty='Apotheke Nord',
            category_manual=True, source='camt053', dedup_key='ref:M1',
        )
        # …but a similar UNCATEGORIZED transaction is a candidate.
        open_tx = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 5),
            amount=Decimal('-7.50'), currency='EUR', counterparty='Apotheke West',
            source='camt053', dedup_key='ref:U1',
        )
        m_relabel.return_value = {
            'ids': [open_tx.id], 'rules': [],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': None},
        }
        resp = self.client.post(reverse('ai_relabel'), {
            'transaction_id': self.tx.id,
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['sent_count'], 1)
        sent_candidates = m_relabel.call_args.args[3]
        self.assertEqual([c['id'] for c in sent_candidates], [open_tx.id])
        self.assertIsNone(resp.data['suggestions'][0]['current_category'])

    @patch('portfolio.ai_categorization.relabel_similar')
    def test_relabel_rule_is_placed_before_the_shadowing_rule(self, m_relabel):
        from portfolio.models import CategoryRule, Transaction, TransactionCategory
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        # The broad rule that mislabeled the transaction ("Markt" matches).
        bad_rule = CategoryRule.objects.create(
            user=self.user, match_text='markt', category=groceries, position=0,
        )
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        self.tx.category = health
        self.tx.category_manual = True
        self.tx.save()
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 15),
            amount=Decimal('-12.30'), currency='EUR', counterparty='Apotheke am Markt',
            category=groceries, source='camt053', dedup_key='ref:A2',
        )
        m_relabel.return_value = {
            'ids': [], 'rules': [{'match_text': 'apotheke', 'category': 'Health'}],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': None},
        }
        resp = self.client.post(reverse('ai_relabel'), {
            'transaction_id': self.tx.id,
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['rules'][0]['place_before_rule_id'], bad_rule.id)
        self.assertEqual(resp.data['rules'][0]['shadowed_match_text'], 'markt')

    @patch('portfolio.ai_categorization.relabel_similar')
    def test_relabel_drops_rule_when_first_match_is_already_correct(self, m_relabel):
        from portfolio.models import CategoryRule, Transaction, TransactionCategory
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        CategoryRule.objects.create(
            user=self.user, match_text='apotheke', category=health, position=0,
        )
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        self.tx.category = health
        self.tx.category_manual = True
        self.tx.save()
        Transaction.objects.create(
            account=self.account, booking_date=date(2026, 7, 15),
            amount=Decimal('-12.30'), currency='EUR', counterparty='Apotheke am Markt',
            source='camt053', dedup_key='ref:A2',
        )
        m_relabel.return_value = {
            'ids': [], 'rules': [{'match_text': 'apotheke', 'category': 'Health'}],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': None},
        }
        resp = self.client.post(reverse('ai_relabel'), {
            'transaction_id': self.tx.id,
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        # Future entries already classify correctly — no rule proposal.
        self.assertEqual(resp.data['rules'], [])

    def test_apply_inserts_rule_before_the_named_rule(self):
        from portfolio.models import CategoryRule, TransactionCategory
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        bad_rule = CategoryRule.objects.create(
            user=self.user, match_text='markt', category=groceries, position=0,
        )
        CategoryRule.objects.create(
            user=self.user, match_text='coop', category=groceries, position=1,
        )
        resp = self.client.post(reverse('ai_apply'), {
            'rules': [{
                'match_text': 'apotheke', 'category': 'Health',
                'place_before_rule_id': bad_rule.id,
            }],
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        order = list(
            CategoryRule.objects.filter(user=self.user)
            .order_by('position', 'id').values_list('match_text', flat=True)
        )
        self.assertEqual(order, ['apotheke', 'markt', 'coop'])

    def test_regex_rule_creation_validation_and_matching(self):
        from portfolio.models import Transaction, TransactionCategory
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        # Invalid pattern is rejected by the serializer.
        resp = self.client.post(reverse('rule_list'), {
            'match_text': 'apo(theke', 'category': health.id, 'is_regex': True,
        }, format='json')
        self.assertEqual(resp.status_code, 400)
        # Valid regex categorizes the uncategorized setUp transaction
        # ("Apotheke am Markt") retroactively on creation.
        resp = self.client.post(reverse('rule_list'), {
            'match_text': r'apotheke.*(markt|nord)', 'category': health.id,
            'is_regex': True,
        }, format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertTrue(resp.data['is_regex'])
        self.tx.refresh_from_db()
        self.assertEqual(self.tx.category, health)
        # A plain substring rule with regex metacharacters stays literal.
        other = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 3),
            amount=Decimal('-2.00'), currency='EUR', counterparty='Kiosk (Markt)',
            source='camt053', dedup_key='ref:L1',
        )
        self.client.post(reverse('rule_list'), {
            'match_text': '(markt)', 'category': health.id,
        }, format='json')
        other.refresh_from_db()
        self.assertEqual(other.category, health)  # literal "(markt)" matched

    def test_transfer_rule_marks_matches_as_transfers(self):
        from portfolio.models import Transaction, TransactionCategory
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        # XOR validation: both targets, or neither, is invalid.
        resp = self.client.post(reverse('rule_list'), {
            'match_text': 'apotheke', 'category': health.id, 'is_transfer': True,
        }, format='json')
        self.assertEqual(resp.status_code, 400)
        resp = self.client.post(reverse('rule_list'), {
            'match_text': 'apotheke',
        }, format='json')
        self.assertEqual(resp.status_code, 400)
        # A user's manual "not a transfer" decision outranks the rule, and the
        # entry falls through to later category rules.
        unmarked = Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 2),
            amount=Decimal('-5.00'), currency='EUR', counterparty='Apotheke Nord',
            transfer_manual=True, source='camt053', dedup_key='ref:T1',
        )
        resp = self.client.post(reverse('rule_list'), {
            'match_text': 'apotheke', 'is_transfer': True,
        }, format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertIsNone(resp.data['category'])
        self.client.post(reverse('rule_list'), {
            'match_text': 'nord', 'category': health.id,
        }, format='json')
        self.tx.refresh_from_db()
        self.assertTrue(self.tx.is_transfer)
        self.assertIsNone(self.tx.category)
        unmarked.refresh_from_db()
        self.assertFalse(unmarked.is_transfer)
        self.assertEqual(unmarked.category, health)  # later rule applied

    def test_rules_replace_accepts_transfer_rules(self):
        resp = self.client.post(reverse('rule_replace'), {
            'rules': [{'match_text': 'vorsorge', 'is_transfer': True}],
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        from portfolio.models import CategoryRule
        rule = CategoryRule.objects.get(user=self.user)
        self.assertTrue(rule.is_transfer)
        self.assertIsNone(rule.category)

    def test_rules_replace_validates_regex(self):
        from portfolio.models import TransactionCategory
        TransactionCategory.objects.create(user=self.user, name='Health')
        resp = self.client.post(reverse('rule_replace'), {
            'rules': [{'match_text': 'apo(theke', 'category': 'Health',
                       'is_regex': True}],
        }, format='json')
        self.assertEqual(resp.status_code, 400)
        resp = self.client.post(reverse('rule_replace'), {
            'rules': [{'match_text': r'apotheke|drogerie', 'category': 'Health',
                       'is_regex': True}],
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.tx.refresh_from_db()
        self.assertEqual(self.tx.category.name, 'Health')

    @patch('portfolio.ai_categorization.consolidate_rules')
    def test_consolidate_merges_and_drops_hallucinated_categories(self, m_consolidate):
        from portfolio.models import CategoryRule, TransactionCategory
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        r1 = CategoryRule.objects.create(
            user=self.user, match_text='migros zurich', category=groceries, position=0)
        r2 = CategoryRule.objects.create(
            user=self.user, match_text='migros bern', category=groceries,
            spread_months=3, position=1)
        # A regex rule must pass through untouched and never reach Gemini.
        regex_rule = CategoryRule.objects.create(
            user=self.user, match_text=r'coop (city|pronto)', category=groceries,
            is_regex=True, position=2)
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        m_consolidate.return_value = {
            'rules': [
                {'match_text': 'migros', 'category': 'Groceries',
                 'spread_months': None, 'sources': [r1.id, r2.id]},
                {'match_text': 'ghost', 'category': 'InventedCategory', 'sources': []},
            ],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': None},
        }
        resp = self.client.post(reverse('ai_consolidate'), {}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['before_count'], 3)
        self.assertEqual(resp.data['after_count'], 2)
        rule = resp.data['rules'][0]
        self.assertEqual(rule['match_text'], 'migros')
        # Missing spread falls back to the largest source spread.
        self.assertEqual(rule['spread_months'], 3)
        self.assertEqual(rule['sources'], [r1.id, r2.id])
        # The regex rule passes through unchanged, in evaluation order.
        passthrough = resp.data['rules'][1]
        self.assertEqual(passthrough['match_text'], r'coop (city|pronto)')
        self.assertTrue(passthrough['is_regex'])
        self.assertEqual(passthrough['sources'], [regex_rule.id])
        # Match counts are computed and sent (self.tx does not contain
        # "migros"); the regex rule is never sent to Gemini.
        sent_rules = m_consolidate.call_args.args[2]
        self.assertEqual([r['matches'] for r in sent_rules], [0, 0])
        self.assertEqual([r['id'] for r in sent_rules], [r1.id, r2.id])
        # Nothing persisted: all original rules still there.
        self.assertEqual(CategoryRule.objects.filter(user=self.user).count(), 3)

    def test_rules_replace_swaps_the_set_and_reapplies(self):
        from portfolio.models import CategoryRule, Transaction, TransactionCategory
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        CategoryRule.objects.create(
            user=self.user, match_text='migros zurich', category=groceries, position=0)
        CategoryRule.objects.create(
            user=self.user, match_text='migros bern', category=groceries, position=1)
        resp = self.client.post(reverse('rule_replace'), {
            'rules': [
                {'match_text': 'migros', 'category': 'Groceries', 'spread_months': 1},
                {'match_text': 'apotheke', 'category': 'Health', 'spread_months': 1},
            ],
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['count'], 2)
        order = list(
            CategoryRule.objects.filter(user=self.user)
            .order_by('position', 'id').values_list('match_text', flat=True)
        )
        self.assertEqual(order, ['migros', 'apotheke'])
        # The replacement set was re-applied: the uncategorized Apotheke
        # transaction from setUp is now categorized.
        self.assertEqual(resp.data['rule_applied'], 1)
        self.tx.refresh_from_db()
        self.assertEqual(self.tx.category, health)

    def test_rules_replace_rejects_unknown_category_keeping_old_rules(self):
        from portfolio.models import CategoryRule, TransactionCategory
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        CategoryRule.objects.create(
            user=self.user, match_text='migros', category=groceries, position=0)
        resp = self.client.post(reverse('rule_replace'), {
            'rules': [{'match_text': 'x', 'category': 'Nope', 'spread_months': 1}],
        }, format='json')
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(
            CategoryRule.objects.filter(user=self.user).count(), 1)

    @patch('portfolio.ai_categorization.relabel_similar')
    def test_relabel_leaves_old_labels_alone_but_offers_old_uncategorized(
            self, m_relabel):
        from portfolio.models import Transaction, TransactionCategory
        health = TransactionCategory.objects.create(user=self.user, name='Health')
        groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        self.tx.category = health
        self.tx.category_manual = True
        self.tx.save()
        # Mislabeled but >18 months old: settled history, not a candidate.
        Transaction.objects.create(
            account=self.account, booking_date=date(2024, 5, 1),
            amount=Decimal('-11.00'), currency='EUR', counterparty='Apotheke am Markt',
            category=groceries, source='camt053', dedup_key='ref:OLD1',
        )
        # Uncategorized of the same age: pure gain, still a candidate.
        old_open = Transaction.objects.create(
            account=self.account, booking_date=date(2024, 5, 2),
            amount=Decimal('-6.00'), currency='EUR', counterparty='Apotheke am Markt',
            source='camt053', dedup_key='ref:OLD2',
        )
        m_relabel.return_value = {
            'ids': [old_open.id], 'rules': [],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'estimated_cost_usd': None},
        }
        resp = self.client.post(reverse('ai_relabel'), {
            'transaction_id': self.tx.id,
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        sent_candidates = m_relabel.call_args.args[3]
        self.assertEqual([c['id'] for c in sent_candidates], [old_open.id])

    def test_relabel_requires_categorized_transaction(self):
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash',
        }, format='json')
        resp = self.client.post(reverse('ai_relabel'), {
            'transaction_id': self.tx.id,
        }, format='json')
        self.assertEqual(resp.status_code, 400)
        resp = self.client.post(reverse('ai_relabel'), {
            'transaction_id': 999999,
        }, format='json')
        self.assertEqual(resp.status_code, 404)

    def test_apply_cannot_touch_other_users_transactions(self):
        from portfolio.models import Transaction
        other_user, _, _ = make_kek_user(username='bob')
        foreign_account = FinancialAccount.objects.create(
            user=other_user, broker=self.broker, name='Foreign', currency='EUR',
        )
        foreign_tx = Transaction.objects.create(
            account=foreign_account, booking_date=date(2026, 8, 1),
            amount=Decimal('-1.00'), currency='EUR', source='camt053', dedup_key='x',
        )
        resp = self.client.post(reverse('ai_apply'), {
            'assignments': [{'transaction_id': foreign_tx.id, 'category': 'Hijack'}],
        }, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['assigned'], 0)
        foreign_tx.refresh_from_db()
        self.assertIsNone(foreign_tx.category)


_ZKB_CSV = (
    '"Date";"Booking text";"Curr";"Amount details";"ZKB reference";'
    '"Reference number";"Debit CHF";"Credit CHF";"Value date";"Balance CHF";'
    '"Payment purpose";"Details"\n'
    '"23.08.2026";"Debit TWINT: TEST MERCHANT";"";"";"REF-AAA-1";"";"10.00";"";'
    '"23.08.2026";"1000.00";"";""\n'
    '"20.08.2026";"Credit originator: ACME CORP";"";"";"REF-BBB-2";"";"";"80.00";'
    '"20.08.2026";"1010.00";"PURPOSE TEXT";"ACME CORP, Somestreet 1, CH"\n'
    '"";"";"";"";"";"";"";"";"";"";"";"a detail continuation row"\n'
    # Still pending: no reference, no value date, and — the giveaway — no
    # resulting balance, because the bank has not booked it yet.
    '"22.08.2026";"Debit TWINT:CHF 7.95";"";"";"";"";"7.95";"";"";"";"";""\n'
)

_DKB_CSV = (
    '"Girokonto";"DE00000000000000000000"\n'
    '"Zeitraum:";"01.01.2026 - 24.08.2026"\n'
    '"Kontostand vom 24.08.2026:";"1.000,00 €"\n'
    '""\n'
    '"Buchungsdatum";"Wertstellung";"Status";"Zahlungspflichtige*r";'
    '"Zahlungsempfänger*in";"Verwendungszweck";"Umsatztyp";"IBAN";'
    '"Betrag (€)";"Gläubiger-ID";"Mandatsreferenz";"Kundenreferenz"\n'
    '"24.08.26";"24.08.26";"Gebucht";"ISSUER";"Test Shop";"Purchase 1";"Ausgang";'
    '"DE11111111111111111111";"-1.234,56";"";"";"KREF1"\n'
    '"20.08.26";"20.08.26";"Gebucht";"Employer AG";"Account Holder";"Salary";'
    '"Eingang";"DE22222222222222222222";"2.500,00";"";"";"KREF2"\n'
    '"25.08.26";"25.08.26";"Vorgemerkt";"ISSUER";"Pending Shop";"Pending";'
    '"Ausgang";"DE33333333333333333333";"-9,99";"";"";"KREF3"\n'
)


_COMMERZBANK_CSV = (
    'Buchungstag;Wertstellung;Umsatzart;Buchungstext;Betrag;Währung;'
    'IBAN Kontoinhaber;Kategorie;Sender;Empfänger;Verwendungszweck\n'
    '11.08.2026;11.08.2026;Überweisung;Alice Example Auffuellung '
    'End-to-End-Ref.: NOTPROVIDED;702;EUR;DE58000000000000000001;Einnahmen;'
    'Alice Example;;Auffuellung\n'
    '03.08.2026;03.08.2026;Dauerauftrag;BOB EXAMPLE BYLADEM1001 '
    'DE57000000000000000002 TOPUP End-to-End-Ref.: NOTPROVIDED Dauerauftrag;'
    '-1.702,50;EUR;DE58000000000000000001;Sonstige Ausgaben;;BOB EXAMPLE;TOPUP\n'
)


_SWISSCARD_CSV = (
    'Transaction date,Description,Merchant,Card number,Currency,Amount,'
    'Foreign Currency,Amount in foreign currency,Debit/Credit,Status,'
    'Merchant Category,Registered Category\n'
    # A purchase: POSITIVE amount with Debit — must be stored as spending.
    '23.08.2026,TEST SHOP GENEVA,TEST SHOP,3776 60**** *0001,CHF,42.50,,,'
    'Debit,Posted,Groceries,\n'
    # The monthly settlement arriving from the bank account: negative + Credit.
    '20.08.2026,IHRE ZAHLUNG – BESTEN DANK,,3776 60**** *0001,CHF,-1200.00,,,'
    'Credit,Posted,Payment,\n'
    # A refund, and a not-yet-posted entry that must be skipped.
    '19.08.2026,REFUND TEST SHOP,TEST SHOP,3776 60**** *0002,CHF,-9.90,,,'
    'Credit,Posted,Shopping,\n'
    '24.08.2026,PENDING PURCHASE,PENDING,3776 60**** *0001,CHF,5.00,,,'
    'Debit,Pending,General,\n'
)


class CsvImportTests(APITestCase):
    """CSV transaction import (synthetic fixtures mimicking the bank formats)."""

    def setUp(self):
        self.user, self.kek, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.chf = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='ZKB Giro', currency='CHF',
        )
        self.eur = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='DKB Giro', currency='EUR',
        )
        self.client.force_authenticate(user=self.user)

    def _upload(self, account, text):
        from django.core.files.uploadedfile import SimpleUploadedFile
        return self.client.post(
            reverse('transaction_csv_import', kwargs={'pk': account.pk}),
            {'file': SimpleUploadedFile('export.csv', text.encode('utf-8'))},
            format='multipart',
        )

    def _upload_auto(self, text):
        from django.core.files.uploadedfile import SimpleUploadedFile
        return self.client.post(
            reverse('transaction_csv_import_auto'),
            {'file': SimpleUploadedFile('export.csv', text.encode('utf-8'))},
            format='multipart',
        )

    def test_swisscard_signs_follow_the_direction_column(self):
        from portfolio.models import Transaction
        card = FinancialAccount.objects.create(
            user=self.user,
            broker=Broker.objects.create(
                code='swisscard', name='Swisscard', integration_type='rest'),
            name='Swisscard', currency='CHF',
        )
        resp = self._upload(card, _SWISSCARD_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['imported'], 3)  # the pending row is skipped
        rows = {t.booking_date: t for t in Transaction.objects.filter(account=card)}
        # A purchase is written positive in the file but is spending here.
        purchase = rows[date(2026, 8, 23)]
        self.assertEqual(purchase.amount, Decimal('-42.50'))
        # The settlement is money arriving on the card account.
        self.assertEqual(rows[date(2026, 8, 20)].amount, Decimal('1200.00'))
        # A refund is a credit despite being written negative.
        self.assertEqual(rows[date(2026, 8, 19)].amount, Decimal('9.90'))
        # Merchant category and card stay visible in the booking text.
        self.assertIn('Groceries', purchase.description)
        self.assertIn('*0001', purchase.description)

    def test_swisscard_settlement_pairs_with_the_paying_account(self):
        from portfolio.models import Transaction
        card = FinancialAccount.objects.create(
            user=self.user,
            broker=Broker.objects.create(
                code='swisscard', name='Swisscard', integration_type='rest'),
            name='Swisscard', currency='CHF',
        )
        # The bank side of the monthly settlement.
        bank_side = Transaction.objects.create(
            account=self.chf, booking_date=date(2026, 8, 20),
            amount=Decimal('-1200.00'), currency='CHF',
            counterparty='Swisscard AECS GmbH', source='camt053',
            dedup_key='ref:SETTLE-1',
        )
        self._upload(card, _SWISSCARD_CSV)
        card_side = Transaction.objects.get(
            account=card, counterparty='IHRE ZAHLUNG – BESTEN DANK')
        bank_side.refresh_from_db()
        card_side.refresh_from_db()
        # Both ends are excluded from spending — the card purchases are the
        # real expenses, the settlement only moves money between own accounts.
        self.assertTrue(bank_side.is_transfer)
        self.assertTrue(card_side.is_transfer)
        # The purchases themselves stay spending.
        purchase = Transaction.objects.get(
            account=card, booking_date=date(2026, 8, 23))
        self.assertFalse(purchase.is_transfer)

    def test_auto_import_picks_the_card_account_over_the_bank_account(self):
        card = FinancialAccount.objects.create(
            user=self.user,
            broker=Broker.objects.create(
                code='swisscard', name='Swisscard', integration_type='rest'),
            name='Swisscard', currency='CHF',
        )
        # self.chf is also CHF — the format names its bank, so no picker.
        resp = self._upload_auto(_SWISSCARD_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['account_id'], card.id)

    def test_auto_import_matches_dkb_account_by_preamble_iban(self):
        self.eur.account_identifier = 'DE00000000000000000000'
        self.eur.save()
        resp = self._upload_auto(_DKB_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['status'], 'success')
        self.assertEqual(resp.data['account_id'], self.eur.id)
        self.assertEqual(resp.data['imported'], 2)

    def test_commerzbank_auto_import_by_own_iban_column(self):
        from portfolio.models import Transaction
        self.eur.account_identifier = 'DE58000000000000000001'
        self.eur.save()
        resp = self._upload_auto(_COMMERZBANK_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['format'], 'commerzbank')
        self.assertEqual(resp.data['account_id'], self.eur.id)
        self.assertEqual(resp.data['imported'], 2)
        credit = Transaction.objects.get(account=self.eur, amount=Decimal('702'))
        self.assertEqual(credit.counterparty, 'Alice Example')  # sender on inflow
        self.assertEqual(credit.description, 'Auffuellung')
        debit = Transaction.objects.get(account=self.eur, amount=Decimal('-1702.50'))
        self.assertEqual(debit.counterparty, 'BOB EXAMPLE')  # recipient on outflow
        # The counterparty IBAN is embedded in the booking text — extracted so
        # transfer auto-detection can pair it (the own IBAN is skipped).
        self.assertEqual(debit.counterparty_account, 'DE57000000000000000002')
        self.assertEqual(debit.currency, 'EUR')

    def test_auto_import_rejects_unknown_iban(self):
        resp = self._upload_auto(_DKB_CSV)  # no account carries that IBAN
        self.assertEqual(resp.status_code, 400)
        self.assertIn('DE00000000000000000000', resp.data['error'])

    def test_auto_import_zkb_by_unique_currency(self):
        resp = self._upload_auto(_ZKB_CSV)  # exactly one CHF account
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['status'], 'success')
        self.assertEqual(resp.data['account_id'], self.chf.id)

    def test_auto_import_zkb_ambiguous_lists_candidates(self):
        other = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Second CHF', currency='CHF',
        )
        resp = self._upload_auto(_ZKB_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['status'], 'ambiguous')
        self.assertEqual(
            {a['id'] for a in resp.data['accounts']}, {self.chf.id, other.id})
        from portfolio.models import Transaction
        self.assertEqual(Transaction.objects.count(), 0)  # nothing imported

    def test_account_import_rejects_foreign_iban_file(self):
        self.chf.account_identifier = 'CH0000000000000000000'
        self.chf.save()
        resp = self._upload(self.chf, _DKB_CSV)  # file names a DE IBAN
        self.assertEqual(resp.status_code, 400)
        self.assertIn('DE00000000000000000000', resp.data['error'])

    def test_zkb_import_signs_refs_and_detail_rows(self):
        from portfolio.models import Transaction
        resp = self._upload(self.chf, _ZKB_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['format'], 'zkb')
        self.assertEqual(resp.data['imported'], 2)
        # The detail continuation row and the pending, balance-less TWINT row.
        self.assertEqual(resp.data['skipped'], 2)
        debit = Transaction.objects.get(account=self.chf, external_id='REF-AAA-1')
        self.assertEqual(debit.amount, Decimal('-10.00'))
        self.assertEqual(debit.currency, 'CHF')
        self.assertEqual(debit.source, 'csv')
        self.assertEqual(debit.dedup_key, 'ref:REF-AAA-1')
        credit = Transaction.objects.get(account=self.chf, external_id='REF-BBB-2')
        self.assertEqual(credit.amount, Decimal('80.00'))
        self.assertEqual(credit.counterparty, 'ACME CORP, Somestreet 1, CH')
        self.assertIn('PURPOSE TEXT', credit.description)
        self.assertEqual(str(credit.value_date), '2026-08-20')

    def test_zkb_pending_row_is_not_imported(self):
        from portfolio.models import Transaction
        self._upload(self.chf, _ZKB_CSV)
        # A pending row has no reference, so it would land under a content
        # hash and come back as a second row once the bank books it under one.
        self.assertFalse(
            Transaction.objects.filter(
                account=self.chf, amount=Decimal('-7.95')).exists())

    def test_zkb_import_dedups_against_ebics_synced_rows(self):
        from portfolio.models import Transaction
        # The same entry already arrived via EBICS: shared bank reference.
        Transaction.objects.create(
            account=self.chf, booking_date=date(2026, 8, 23),
            amount=Decimal('-10.00'), currency='CHF', source='camt053',
            external_id='REF-AAA-1', dedup_key='ref:REF-AAA-1',
        )
        resp = self._upload(self.chf, _ZKB_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['imported'], 1)  # only the credit is new
        self.assertEqual(Transaction.objects.filter(account=self.chf).count(), 2)

    def test_dkb_import_amounts_status_and_counterparty(self):
        from portfolio.models import Transaction
        resp = self._upload(self.eur, _DKB_CSV)
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['format'], 'dkb')
        self.assertEqual(resp.data['imported'], 2)  # pending row skipped
        self.assertEqual(resp.data['skipped'], 1)
        out = Transaction.objects.get(account=self.eur, amount=Decimal('-1234.56'))
        self.assertEqual(out.counterparty, 'Test Shop')  # payee on outflow
        self.assertEqual(out.counterparty_account, 'DE11111111111111111111')
        self.assertEqual(out.currency, 'EUR')
        inc = Transaction.objects.get(account=self.eur, amount=Decimal('2500.00'))
        self.assertEqual(inc.counterparty, 'Employer AG')  # payer on inflow

    def test_reimport_is_idempotent(self):
        for account, text in ((self.chf, _ZKB_CSV), (self.eur, _DKB_CSV)):
            first = self._upload(account, text)
            second = self._upload(account, text)
            self.assertEqual(second.status_code, 200, second.data)
            self.assertEqual(second.data['imported'], 0)
            self.assertEqual(second.data['fetched'], first.data['fetched'])

    def test_currency_mismatch_is_refused(self):
        resp = self._upload(self.chf, _DKB_CSV)  # EUR file into CHF account
        self.assertEqual(resp.status_code, 400)
        self.assertIn('EUR', resp.data['error'])

    def test_unknown_format_and_foreign_account(self):
        resp = self._upload(self.chf, 'just;some;random\ncsv;file;here\n')
        self.assertEqual(resp.status_code, 400)
        other_user, _, _ = make_kek_user(username='bob')
        foreign = FinancialAccount.objects.create(
            user=other_user, broker=self.broker, name='Foreign', currency='CHF',
        )
        resp = self._upload(foreign, _ZKB_CSV)
        self.assertEqual(resp.status_code, 404)


class TransactionBackfillTests(APITestCase):
    """Dated transaction backfill (web-only feature)."""

    def setUp(self):
        self.user, self.kek, _ = make_kek_user()
        self.broker = Broker.objects.create(
            code='zkb', name='ZKB', integration_type='ebics', supports_auto_sync=True,
        )
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='CHF',
            account_identifier='CH93', encrypted_credentials=b'x',
        )
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def _url(self):
        return reverse('transaction_backfill', kwargs={'pk': self.account.pk})

    @patch('portfolio.views.KEKAuthenticationMixin.decrypt_sync_credentials')
    @patch('portfolio.views.FinancialAccount.objects.get')
    def test_rejects_bad_dates(self, _m_get, m_creds):
        m_creds.return_value = {}
        _m_get.return_value = self.account
        resp = self.client.post(self._url(), {'start': 'nope'}, format='json')
        self.assertEqual(resp.status_code, 400)
        self.assertIn('ISO dates', resp.data['error'])

        resp = self.client.post(
            self._url(), {'start': '2026-08-01', 'end': '2026-01-01'}, format='json')
        self.assertEqual(resp.status_code, 400)
        self.assertIn('before end date', resp.data['error'])

    def test_manual_account_rejected(self):
        self.account.is_manual = True
        self.account.save()
        resp = self.client.post(self._url(), {'start': '2026-01-01'}, format='json')
        self.assertEqual(resp.status_code, 400)

    @patch('portfolio.views.KEKAuthenticationMixin.decrypt_sync_credentials')
    def test_enqueues_task(self, m_creds):
        m_creds.return_value = {'keyring_pem': 'x'}
        resp = self.client.post(
            self._url(), {'start': '2026-01-01', 'end': '2026-06-30'}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['status'], 'queued')
        self.assertIn('task_id', resp.data)


class BackfillImporterTests(TestCase):
    def setUp(self):
        from brokers.integrations.base import TransactionInfo
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='CHF',
            account_identifier='CH93',
        )
        self.TransactionInfo = TransactionInfo

    def _integration(self, infos):
        calls = []

        class Fake:
            def supports_transactions(self):
                return True

            # Backfill goes through get_transactions_for_range (dated request),
            # which defaults to get_transactions for range-querying feeds.
            def get_transactions_for_range(self, identifier, start, end):
                return self.get_transactions(identifier, start, end)

            def get_transactions(self, identifier, start, end):
                calls.append((start, end))
                return infos

        fake = Fake()
        fake.calls = calls
        return fake

    def test_backfill_uses_requested_range_and_is_idempotent(self):
        from portfolio.models import Transaction
        from portfolio.transaction_importer import backfill_account_transactions
        infos = [self.TransactionInfo(
            booking_date=date(2025, 3, 5), amount=Decimal('-20'), currency='CHF',
            counterparty='Old Shop', external_id='OLD1',
        )]
        integration = self._integration(infos)
        result = backfill_account_transactions(
            self.account, integration, date(2025, 1, 1), date(2025, 12, 31))
        self.assertEqual(result.imported, 1)
        self.assertEqual(integration.calls[0], (date(2025, 1, 1), date(2025, 12, 31)))
        # Re-running the same range imports nothing new.
        self.assertEqual(
            backfill_account_transactions(
                self.account, integration, date(2025, 1, 1), date(2025, 12, 31)).imported,
            0,
        )
        self.assertEqual(Transaction.objects.filter(account=self.account).count(), 1)

    def test_backfill_reports_the_span_the_bank_actually_served(self):
        """A bank that serves only the tail of the requested window must say so.

        ZKB's EBICS archive starts at subscriber activation, so a 15-month request
        can come back with 7 weeks. Reporting only the imported count made that look
        like a complete import of the requested period.
        """
        from portfolio.transaction_importer import backfill_account_transactions
        infos = [
            self.TransactionInfo(
                booking_date=date(2025, 11, 3), amount=Decimal('-20'), currency='CHF',
                counterparty='Shop', external_id='A1',
            ),
            self.TransactionInfo(
                booking_date=date(2025, 12, 20), amount=Decimal('-35'), currency='CHF',
                counterparty='Shop', external_id='A2',
            ),
        ]
        result = backfill_account_transactions(
            self.account, self._integration(infos), date(2025, 1, 1), date(2025, 12, 31))

        self.assertEqual(result.imported, 2)
        self.assertEqual(result.fetched, 2)
        self.assertEqual(result.covered_start, date(2025, 11, 3))
        self.assertEqual(result.covered_end, date(2025, 12, 20))
        self.assertTrue(result.is_truncated)
        self.assertIn('2025-11-03', result.describe())
        self.assertIn("short of the requested", result.describe())

    def test_backfill_covering_the_window_is_not_flagged_truncated(self):
        from portfolio.transaction_importer import backfill_account_transactions
        infos = [self.TransactionInfo(
            booking_date=date(2025, 1, 9), amount=Decimal('-20'), currency='CHF',
            counterparty='Shop', external_id='B1',
        )]
        result = backfill_account_transactions(
            self.account, self._integration(infos), date(2025, 1, 1), date(2025, 12, 31))
        self.assertFalse(result.is_truncated)
        self.assertNotIn('short of the requested', result.describe())

    def test_backfill_with_no_data_says_so(self):
        from portfolio.transaction_importer import backfill_account_transactions
        result = backfill_account_transactions(
            self.account, self._integration([]), date(2025, 1, 1), date(2025, 12, 31))
        self.assertEqual(result.imported, 0)
        self.assertFalse(result.is_truncated)
        self.assertIn('No transactions were returned', result.describe())


class CategoryOrderingTests(APITestCase):
    """Categories come back in the order the dropdowns show them."""

    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.client.force_authenticate(user=self.user)

    def test_list_is_alphabetical_regardless_of_case(self):
        """A plain ORDER BY name sorts by collation, which strands lowercase.

        On a C-collated Postgres every lowercase initial sorts after every
        uppercase one, so "eBay" showed up behind "Transport" — halfway down a
        dropdown nobody scrolls that far into.
        """
        from portfolio.models import TransactionCategory
        for name in ('Transport', 'eBay', 'Groceries', 'zoo', 'Insurance'):
            TransactionCategory.objects.create(user=self.user, name=name)

        resp = self.client.get(reverse('category_list'))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(
            [c['name'] for c in resp.data],
            ['eBay', 'Groceries', 'Insurance', 'Transport', 'zoo'],
        )

    def test_budget_can_be_set_and_cleared(self):
        from portfolio.models import TransactionCategory
        category = TransactionCategory.objects.create(user=self.user, name='Food')
        url = reverse('category_detail', kwargs={'pk': category.pk})

        resp = self.client.patch(url, {'monthly_budget': '250.00'}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['monthly_budget'], '250.00')

        # Empty means "no target", which is different from a target of zero.
        resp = self.client.patch(url, {'monthly_budget': None}, format='json')
        self.assertIsNone(resp.data['monthly_budget'])
        category.refresh_from_db()
        self.assertIsNone(category.monthly_budget)

    def test_a_negative_budget_is_rejected(self):
        from portfolio.models import TransactionCategory
        category = TransactionCategory.objects.create(user=self.user, name='Food')
        resp = self.client.patch(
            reverse('category_detail', kwargs={'pk': category.pk}),
            {'monthly_budget': '-10'}, format='json')
        self.assertEqual(resp.status_code, 400)

    def test_a_new_category_lands_in_order_not_at_the_end(self):
        from portfolio.models import TransactionCategory
        for name in ('Alpha', 'Zulu'):
            TransactionCategory.objects.create(user=self.user, name=name)
        created = self.client.post(
            reverse('category_list'), {'name': 'Mike'}, format='json')
        self.assertEqual(created.status_code, 201, created.data)

        resp = self.client.get(reverse('category_list'))
        self.assertEqual([c['name'] for c in resp.data], ['Alpha', 'Mike', 'Zulu'])


class InteractiveBackfillTests(APITestCase):
    """A backfill of a broker that texts a code must be able to ask for it.

    Swisscard cannot log in without an SMS code. Without this handshake the
    backfill could only ever run in the few minutes after an unrelated sync had
    warmed a session — the history of a card account would be unreachable.
    """

    def setUp(self):
        from brokers.integrations.base import AuthResult, TransactionInfo
        self.AuthResult = AuthResult
        self.TransactionInfo = TransactionInfo
        self.user, self.kek, _ = make_kek_user()
        self.broker = Broker.objects.create(
            code='swisscard', name='Swisscard', integration_type='rest')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Cashback', currency='CHF',
            account_identifier='4000', encrypted_credentials=b'x', status='active',
        )
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def _integration(self, *, requires_2fa=True, infos=(), code_ok=True):
        outer = self

        class Fake:
            closed = False
            completed_with = None

            def authenticate(self):
                if requires_2fa:
                    return outer.AuthResult(
                        success=False, requires_2fa=True, two_fa_type='sms',
                        session_data={'storage_state': {'cookies': []}},
                        challenge_data={'message': 'Code sent to +41 79 ***'},
                    )
                return outer.AuthResult(success=True)

            def complete_2fa(self, code, session_data):
                self.completed_with = (code, session_data)
                if not code_ok:
                    return outer.AuthResult(success=False, error_message='Wrong code')
                return outer.AuthResult(success=True)

            def requires_reauth_before_2fa(self):
                return False

            def supports_transactions(self):
                return True

            def get_transactions_for_range(self, identifier, start, end):
                self.range = (start, end)
                return list(infos)

            def close(self):
                self.closed = True

        return Fake()

    def test_backfill_parks_the_challenge_instead_of_failing(self):
        from portfolio.views import _backfill_transactions_worker
        integration = self._integration()
        with patch('brokers.integrations.get_broker_integration', return_value=integration):
            result = _backfill_transactions_worker(
                account_id=self.account.id, credentials={},
                start_date=date(2025, 1, 1), end_date=date(2025, 12, 31),
            )

        self.assertEqual(result['status'], 'pending_auth')
        self.assertEqual(result['two_fa_type'], 'sms')
        self.assertIn('+41 79 ***', result['challenge']['message'])
        self.account.refresh_from_db()
        self.assertEqual(self.account.status, 'pending_auth')
        action = self.account.pending_auth_state['pending_action']
        self.assertEqual(action['type'], 'backfill')
        self.assertEqual(action['start'], '2025-01-01')
        self.assertEqual(action['end'], '2025-12-31')
        self.assertEqual(action['previous_status'], 'active')
        self.assertTrue(integration.closed)

    @patch('portfolio.views.KEKAuthenticationMixin.decrypt_account_credentials')
    def test_the_code_resumes_the_backfill_not_a_sync(self, m_creds):
        from portfolio.models import Transaction
        m_creds.return_value = {}
        self.account.pending_auth_state = {
            'two_fa_type': 'sms',
            'session_data': {'storage_state': {'cookies': []}},
            'pending_action': {
                'type': 'backfill', 'start': '2025-01-01', 'end': '2025-12-31',
                'previous_status': 'active',
            },
        }
        self.account.status = 'pending_auth'
        self.account.save()

        integration = self._integration(infos=[self.TransactionInfo(
            booking_date=date(2025, 3, 5), amount=Decimal('-42.50'), currency='CHF',
            counterparty='Test Shop', external_id='tx-1',
        )])
        with patch('brokers.integrations.get_broker_integration', return_value=integration):
            resp = self.client.post(
                reverse('account_auth', kwargs={'pk': self.account.pk}),
                {'auth_code': '123456'}, format='json',
            )

        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['status'], 'success')
        self.assertEqual(resp.data['imported'], 1)
        # The requested window travelled through the challenge unchanged.
        self.assertEqual(integration.range, (date(2025, 1, 1), date(2025, 12, 31)))
        self.assertEqual(integration.completed_with[0], '123456')
        self.assertEqual(Transaction.objects.filter(account=self.account).count(), 1)
        # No snapshot: a backfill is not a sync.
        self.assertFalse(AccountSnapshot.objects.filter(account=self.account).exists())
        self.account.refresh_from_db()
        self.assertEqual(self.account.status, 'active')
        self.assertIsNone(self.account.pending_auth_state)

    @patch('portfolio.views.KEKAuthenticationMixin.decrypt_account_credentials')
    def test_a_rejected_code_keeps_the_backfill_pending(self, m_creds):
        m_creds.return_value = {}
        self.account.pending_auth_state = {
            'two_fa_type': 'sms', 'session_data': {},
            'pending_action': {'type': 'backfill', 'start': '2025-01-01',
                               'end': '2025-12-31', 'previous_status': 'active'},
        }
        self.account.status = 'pending_auth'
        self.account.save()

        with patch('brokers.integrations.get_broker_integration',
                   return_value=self._integration(code_ok=False)):
            resp = self.client.post(
                reverse('account_auth', kwargs={'pk': self.account.pk}),
                {'auth_code': '000000'}, format='json',
            )

        self.assertEqual(resp.status_code, 400)
        self.assertIn('Wrong code', resp.data['error'])
        # Still parked, so the user can retype the code without starting over.
        self.account.refresh_from_db()
        self.assertEqual(self.account.status, 'pending_auth')
        self.assertIn('pending_action', self.account.pending_auth_state)


class StorePositionsTests(TestCase):
    def setUp(self):
        from brokers.integrations.base import PositionInfo
        self.user, _, _ = make_kek_user()
        broker = Broker.objects.create(code='ibkr', name='IBKR', integration_type='rest')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=broker, name='IBKR', currency='USD',
        )
        self.snapshot = AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('1000'), currency='USD',
            snapshot_date=date(2026, 8, 1),
        )
        self.PositionInfo = PositionInfo

    def _info(self, symbol='VT', value='500', quantity='4'):
        return self.PositionInfo(
            symbol=symbol, name=f'{symbol} ETF', quantity=Decimal(quantity),
            price_per_unit=Decimal(value) / Decimal(quantity),
            market_value=Decimal(value), currency='USD',
            isin='US9220427424', asset_class='equity',
        )

    def test_store_positions_replaces_wholesale(self):
        from portfolio.snapshot_writer import store_positions
        store_positions(self.snapshot, [self._info('VT'), self._info('VXUS')])
        self.assertEqual(self.snapshot.positions.count(), 2)
        # A later sync where VXUS was sold must remove its row.
        store_positions(self.snapshot, [self._info('VT', value='600')])
        names = list(self.snapshot.positions.values_list('symbol', flat=True))
        self.assertEqual(names, ['VT'])
        self.assertEqual(self.snapshot.positions.get().market_value, Decimal('600'))

    def test_empty_list_does_not_erase_existing_positions(self):
        from portfolio.snapshot_writer import store_positions
        store_positions(self.snapshot, [self._info('VT')])
        self.assertEqual(store_positions(self.snapshot, []), 0)
        self.assertEqual(self.snapshot.positions.count(), 1)


class WealthHoldingsEndpointTests(APITestCase):
    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.client.force_authenticate(user=self.user)
        broker = Broker.objects.create(code='ibkr', name='IBKR', integration_type='rest')
        self.acc_a = FinancialAccount.objects.create(
            user=self.user, broker=broker, name='IBKR', currency='CHF',
        )
        self.acc_b = FinancialAccount.objects.create(
            user=self.user, broker=broker, name='MS', currency='CHF',
        )

    def _snap_with_position(self, account, snapshot_date, *, isin, symbol, value, quantity):
        snap = AccountSnapshot.objects.create(
            account=account, balance=Decimal(value), currency='CHF',
            snapshot_date=snapshot_date,
        )
        PortfolioPosition.objects.create(
            snapshot=snap, symbol=symbol, isin=isin, name=f'{symbol} ETF',
            quantity=Decimal(quantity), price_per_unit=Decimal(value) / Decimal(quantity),
            market_value=Decimal(value), currency='CHF', asset_class='equity',
        )
        return snap

    def test_merges_same_isin_across_accounts(self):
        self._snap_with_position(
            self.acc_a, date(2026, 8, 1), isin='US9220427424', symbol='VT',
            value='500', quantity='4')
        self._snap_with_position(
            self.acc_b, date(2026, 8, 2), isin='US9220427424', symbol='VT',
            value='250', quantity='2')
        resp = self.client.get(reverse('wealth_holdings'))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data['holdings']), 1)
        holding = resp.data['holdings'][0]
        self.assertEqual(holding['quantity'], 6.0)
        self.assertEqual(holding['value_base_currency'], 750.0)
        self.assertEqual(sorted(holding['accounts']), ['IBKR', 'MS'])
        self.assertEqual(resp.data['as_of'], '2026-08-02')

    def test_uses_latest_snapshot_that_has_positions(self):
        self._snap_with_position(
            self.acc_a, date(2026, 8, 1), isin='US9220427424', symbol='VT',
            value='500', quantity='4')
        # A newer balance-only snapshot (e.g. from a balance-only sync) must not
        # hide the holdings that are still current.
        AccountSnapshot.objects.create(
            account=self.acc_a, balance=Decimal('510'), currency='CHF',
            snapshot_date=date(2026, 8, 5),
        )
        resp = self.client.get(reverse('wealth_holdings'))
        self.assertEqual(len(resp.data['holdings']), 1)

    def test_empty_when_no_positions_anywhere(self):
        resp = self.client.get(reverse('wealth_holdings'))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['holdings'], [])
        self.assertIsNone(resp.data['as_of'])


class SimulationEngineTests(TestCase):
    def _run(self, **overrides):
        from portfolio.simulation import run_simulation
        params = dict(
            start_wealth=100_000, monthly_contribution=1_000,
            expected_return=0.05, volatility=0.12, inflation=0.02,
            years=10, paths=500, seed=42,
        )
        params.update(overrides)
        return run_simulation(**params)

    def test_seeded_run_is_deterministic(self):
        self.assertEqual(self._run(), self._run())

    def test_percentiles_are_monotonic(self):
        for band in self._run()['bands']:
            self.assertLessEqual(band['p5'], band['p25'])
            self.assertLessEqual(band['p25'], band['p50'])
            self.assertLessEqual(band['p50'], band['p75'])
            self.assertLessEqual(band['p75'], band['p95'])

    def test_zero_volatility_matches_compound_interest(self):
        import math
        result = self._run(volatility=0, years=10, paths=100)
        # With sigma=0 every path is the deterministic monthly compounding of the
        # real return (5% - 2% = 3%) plus contributions.
        rate = math.exp(0.03 / 12)
        wealth = 100_000.0
        for _ in range(120):
            wealth = wealth * rate + 1_000
        band = result['bands'][-1]
        self.assertAlmostEqual(band['p50'], wealth, delta=0.01)  # bands round to 2 dp
        self.assertEqual(band['p5'], band['p95'])

    def test_target_probability_and_median_year(self):
        result = self._run(target_amount=150_000)
        target = result['target']
        self.assertGreaterEqual(target['probability'], 0)
        self.assertLessEqual(target['probability'], 1)
        # 100k at 3% real + 12k/year reaches 150k comfortably within 10 years.
        self.assertIsNotNone(target['median_reached_year'])
        # An absurd target is (a) never reached by the median and (b) ~0 probability.
        result = self._run(target_amount=10**12)
        self.assertIsNone(result['target']['median_reached_year'])
        self.assertEqual(result['target']['probability'], 0)

    def test_wealth_is_floored_at_zero(self):
        result = self._run(
            start_wealth=1_000, monthly_contribution=-5_000, volatility=0,
            years=2, paths=100,
        )
        self.assertEqual(result['bands'][-1]['p50'], 0)

    def test_paths_and_years_are_clamped(self):
        result = self._run(years=500, paths=5)
        self.assertEqual(result['years'], 50)
        self.assertEqual(result['paths'], 100)


class SimulationDefaultsTests(TestCase):
    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='ibkr', name='IBKR', integration_type='rest')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='IBKR', currency='CHF',
        )

    def test_market_assumptions_blend_from_holdings(self):
        from portfolio.simulation import ASSET_CLASS_ASSUMPTIONS, derive_market_assumptions
        snap = AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('1000'), currency='CHF',
            snapshot_date=date(2026, 8, 1),
        )
        for asset_class, value in (('equity', '600'), ('fixed_income', '400')):
            PortfolioPosition.objects.create(
                snapshot=snap, name=asset_class, quantity=Decimal('1'),
                price_per_unit=Decimal(value), market_value=Decimal(value),
                currency='CHF', asset_class=asset_class,
            )
        expected_return, volatility, weights = derive_market_assumptions(self.user)
        eq = ASSET_CLASS_ASSUMPTIONS['equity']
        fi = ASSET_CLASS_ASSUMPTIONS['fixed_income']
        self.assertAlmostEqual(expected_return, 0.6 * eq[0] + 0.4 * fi[0], places=4)
        self.assertAlmostEqual(volatility, 0.6 * eq[1] + 0.4 * fi[1], places=4)
        self.assertAlmostEqual(weights['equity'], 0.6, places=4)

    def test_market_assumptions_fall_back_without_holdings(self):
        from portfolio.simulation import DEFAULT_RETURN, DEFAULT_VOLATILITY, derive_market_assumptions
        expected_return, volatility, weights = derive_market_assumptions(self.user)
        self.assertEqual(expected_return, DEFAULT_RETURN)
        self.assertEqual(volatility, DEFAULT_VOLATILITY)
        self.assertEqual(weights, {})

    def test_start_wealth_uses_latest_snapshots(self):
        from portfolio.simulation import derive_start_wealth
        AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('500'), currency='CHF',
            snapshot_date=date(2026, 7, 1),
        )
        AccountSnapshot.objects.create(
            account=self.account, balance=Decimal('750'), currency='CHF',
            snapshot_date=date(2026, 8, 1),
        )
        self.assertEqual(derive_start_wealth(self.user), 750.0)


class SimulationEndpointTests(APITestCase):
    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.client.force_authenticate(user=self.user)

    def test_simulation_endpoint_returns_bands_and_parameters(self):
        resp = self.client.get(reverse('wealth_simulation'), {'seed': 1, 'paths': 200})
        self.assertEqual(resp.status_code, 200)
        # Bands always cover the largest selectable horizon (30y) so clients can
        # switch horizons by slicing locally; 'years' is the selected horizon.
        self.assertEqual(resp.data['years'], 15)
        self.assertEqual(len(resp.data['bands']), 31)
        for name in ('start_wealth', 'monthly_contribution', 'expected_return',
                     'volatility', 'inflation'):
            self.assertIn(name, resp.data['parameters'])
        # Nothing supplied -> everything derived.
        self.assertTrue(resp.data['parameters']['start_wealth']['derived'])

    def test_supplied_parameters_are_echoed_as_not_derived(self):
        resp = self.client.get(reverse('wealth_simulation'), {
            'seed': 1, 'paths': 200, 'expected_return': '0.06', 'target_amount': '1000',
        })
        self.assertEqual(resp.data['parameters']['expected_return']['value'], 0.06)
        self.assertFalse(resp.data['parameters']['expected_return']['derived'])
        self.assertIn('target', resp.data)

    def test_target_probability_matches_selected_horizon(self):
        resp = self.client.get(reverse('wealth_simulation'), {
            'seed': 1, 'paths': 200, 'years': 5, 'target_amount': '1000',
            'monthly_contribution': '100', 'start_wealth': '0',
        })
        target = resp.data['target']
        self.assertEqual(len(target['probability_by_year']), 31)
        self.assertEqual(target['probability'], target['probability_by_year'][5])

    def test_invalid_parameter_is_a_400(self):
        resp = self.client.get(reverse('wealth_simulation'), {'years': 'soon'})
        self.assertEqual(resp.status_code, 400)
        self.assertIn('years', resp.data['error'])


class SimulationPersistenceTests(APITestCase):
    """Explicitly sent parameters persist as overrides; untouched ones re-derive."""

    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.client.force_authenticate(user=self.user)
        self.url = reverse('wealth_simulation')

    def _profile(self):
        self.user.profile.refresh_from_db()
        return self.user.profile

    def test_sent_parameters_are_stored_and_reused(self):
        self.client.get(self.url, {'paths': 100, 'expected_return': '0.06', 'years': 20})
        stored = self._profile().simulation_params
        self.assertEqual(stored, {'expected_return': 0.06, 'years': 20})

        # A later bare request applies the stored overrides.
        resp = self.client.get(self.url, {'paths': 100})
        self.assertEqual(resp.data['years'], 20)
        parameter = resp.data['parameters']['expected_return']
        self.assertEqual(parameter['value'], 0.06)
        self.assertFalse(parameter['derived'])
        # Untouched parameters still count as derived.
        self.assertTrue(resp.data['parameters']['volatility']['derived'])

    def test_unsent_parameters_keep_rederiving(self):
        """A stored override must not freeze the others — esp. start_wealth."""
        broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        account = FinancialAccount.objects.create(
            user=self.user, broker=broker, name='Acct', currency='CHF',
        )
        AccountSnapshot.objects.create(
            account=account, balance=Decimal('1000'), currency='CHF',
            snapshot_date=date(2026, 8, 1),
        )
        self.client.get(self.url, {'paths': 100, 'expected_return': '0.06'})
        # Wealth changes: a new snapshot arrives.
        AccountSnapshot.objects.create(
            account=account, balance=Decimal('2000'), currency='CHF',
            snapshot_date=date(2026, 8, 10),
        )
        resp = self.client.get(self.url, {'paths': 100})
        self.assertEqual(resp.data['parameters']['start_wealth']['value'], 2000.0)
        self.assertTrue(resp.data['parameters']['start_wealth']['derived'])

    def test_empty_parameter_clears_the_override(self):
        self.client.get(self.url, {'paths': 100, 'volatility': '0.3'})
        self.assertEqual(self._profile().simulation_params, {'volatility': 0.3})
        resp = self.client.get(self.url, {'paths': 100, 'volatility': ''})
        self.assertIsNone(self._profile().simulation_params)
        self.assertTrue(resp.data['parameters']['volatility']['derived'])

    def test_target_amount_persists_and_clears(self):
        self.client.get(self.url, {'paths': 100, 'target_amount': '500000'})
        resp = self.client.get(self.url, {'paths': 100})
        self.assertEqual(resp.data['target']['amount'], 500000.0)
        self.client.get(self.url, {'paths': 100, 'target_amount': ''})
        resp = self.client.get(self.url, {'paths': 100})
        self.assertNotIn('target', resp.data)

    def test_paths_and_seed_are_never_persisted(self):
        self.client.get(self.url, {'paths': 100, 'seed': 5})
        self.assertIsNone(self._profile().simulation_params)


class AiModelFilterTests(TestCase):
    """The model picker must only offer general-purpose text models."""

    def _list(self, ids_and_names):
        from portfolio.ai_categorization import list_models
        payload = {'models': [
            {'name': f'models/{mid}', 'displayName': name,
             'supportedGenerationMethods': ['generateContent']}
            for mid, name in ids_and_names
        ]}
        with patch('portfolio.ai_categorization.requests.get') as m_get:
            m_get.return_value = MagicMock(status_code=200, json=lambda: payload)
            return list_models('key')

    def test_excludes_image_speech_robotics_and_tool_variants(self):
        models = self._list([
            ('gemini-3.6-flash', 'Gemini 3.6 Flash'),
            ('gemini-2.5-flash-image', 'Nano Banana'),
            ('gemini-3-pro-image-preview', 'Nano Banana Pro'),
            ('gemini-2.5-flash-preview-tts', 'Gemini 2.5 Flash Preview TTS'),
            ('gemini-robotics-er-2-preview', 'Gemini Robotics-ER 2 Preview'),
            ('gemini-2.5-computer-use-preview-10-2025', 'Gemini 2.5 Computer Use'),
            ('gemini-2.5-flash-native-audio-dialog', 'Gemini Live'),
            ('gemini-embedding-001', 'Gemini Embedding'),
            ('gemini-3.1-pro-preview-custom-tools', 'Gemini 3.1 Pro Custom Tools'),
        ])
        self.assertEqual([m['id'] for m in models], ['gemini-3.6-flash'])

    def test_image_model_never_inherits_a_text_models_price(self):
        # 'gemini-2.5-flash-image' prefix-matches the 'gemini-2.5-flash' price row.
        from portfolio.ai_categorization import is_text_model
        self.assertFalse(is_text_model('gemini-2.5-flash-image'))
        self.assertEqual(self._list([('gemini-2.5-flash-image', 'Nano Banana')]), [])

    def test_keeps_current_text_models_including_previews_and_aliases(self):
        models = self._list([
            ('gemini-3.1-pro-preview', 'Gemini 3.1 Pro Preview'),
            ('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
            ('gemini-flash-latest', 'Gemini Flash Latest'),
        ])
        self.assertEqual(
            sorted(m['id'] for m in models),
            ['gemini-3.1-pro-preview', 'gemini-3.5-flash-lite', 'gemini-flash-latest'],
        )

    def test_deduplicates_aliases_of_the_same_model(self):
        models = self._list([
            ('gemini-3.6-flash', 'Gemini 3.6 Flash'),
            ('gemini-3.6-flash-001', 'Gemini 3.6 Flash'),
        ])
        self.assertEqual(len(models), 1)


class RuleOrderingTests(APITestCase):
    """Rules are first-match-wins, so their order is user-controlled."""

    def setUp(self):
        from portfolio.models import CategoryRule, TransactionCategory
        self.user, self.kek, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='EUR',
        )
        self.travel = TransactionCategory.objects.create(user=self.user, name='Travel')
        self.fuel = TransactionCategory.objects.create(user=self.user, name='Fuel')
        self.CategoryRule = CategoryRule
        self.client.force_authenticate(user=self.user)

    def _rule(self, match_text, category, position):
        return self.CategoryRule.objects.create(
            user=self.user, match_text=match_text, category=category, position=position,
        )

    def _tx(self, counterparty):
        from portfolio.models import Transaction
        return Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 1), amount=Decimal('-60'),
            currency='EUR', counterparty=counterparty, source='camt053',
            dedup_key=f'k-{counterparty}',
        )

    def test_duplicate_match_text_is_rejected(self):
        url = reverse('rule_list')
        first = self.client.post(
            url, {'match_text': 'shell', 'category': self.fuel.id}, format='json')
        self.assertEqual(first.status_code, 201, first.data)
        # A second rule with the same text could never fire (first-match-wins).
        dupe = self.client.post(
            url, {'match_text': 'Shell', 'category': self.travel.id}, format='json')
        self.assertEqual(dupe.status_code, 400, dupe.data)
        self.assertEqual(self.CategoryRule.objects.filter(user=self.user).count(), 1)

    def test_transfer_rule_cannot_spread(self):
        resp = self.client.post(reverse('rule_list'), {
            'match_text': 'broker top-up', 'is_transfer': True, 'spread_months': 12,
        }, format='json')
        self.assertEqual(resp.status_code, 400, resp.data)
        # Without the spread it is accepted.
        ok = self.client.post(reverse('rule_list'), {
            'match_text': 'broker top-up', 'is_transfer': True,
        }, format='json')
        self.assertEqual(ok.status_code, 201, ok.data)

    def test_first_matching_rule_wins_by_position(self):
        from portfolio.classification import apply_rules
        # 'shell' is more specific than 'she'... use a realistic overlap instead:
        self._rule('tank', self.fuel, position=0)
        self._rule('tankstelle shop', self.travel, position=1)
        tx = self._tx('Tankstelle Shop A5')
        apply_rules(self.user)
        tx.refresh_from_db()
        self.assertEqual(tx.category, self.fuel)

    def test_reorder_changes_which_rule_wins(self):
        from portfolio.classification import apply_rules
        broad = self._rule('tank', self.fuel, position=0)
        specific = self._rule('tankstelle shop', self.travel, position=1)
        resp = self.client.post(
            reverse('rule_reorder'), {'ids': [specific.id, broad.id]}, format='json',
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual([r['id'] for r in resp.data], [specific.id, broad.id])
        tx = self._tx('Tankstelle Shop A5')
        apply_rules(self.user)
        tx.refresh_from_db()
        self.assertEqual(tx.category, self.travel)

    def test_reorder_keeps_rules_missing_from_the_payload(self):
        a = self._rule('aaa', self.fuel, position=0)
        b = self._rule('bbb', self.fuel, position=1)
        c = self._rule('ccc', self.fuel, position=2)
        resp = self.client.post(reverse('rule_reorder'), {'ids': [c.id]}, format='json')
        self.assertEqual([r['id'] for r in resp.data], [c.id, a.id, b.id])

    def test_reorder_ignores_other_users_rule_ids(self):
        from portfolio.models import TransactionCategory
        mine = self._rule('mine', self.fuel, position=0)
        other, _, _ = make_kek_user(username='bob')
        foreign_cat = TransactionCategory.objects.create(user=other, name='Theirs')
        foreign = self.CategoryRule.objects.create(
            user=other, match_text='theirs', category=foreign_cat, position=0,
        )
        resp = self.client.post(
            reverse('rule_reorder'), {'ids': [foreign.id, mine.id]}, format='json',
        )
        self.assertEqual([r['id'] for r in resp.data], [mine.id])
        foreign.refresh_from_db()
        self.assertEqual(foreign.position, 0)

    def test_new_rules_are_appended_last(self):
        self._rule('first', self.fuel, position=0)
        resp = self.client.post(reverse('rule_list'), {
            'match_text': 'second', 'category': self.fuel.id,
        }, format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(resp.data['position'], 1)

    def test_legacy_rules_without_positions_keep_creation_order(self):
        # Existing rows migrate in with position 0; id must break the tie.
        first = self._rule('aaa', self.fuel, position=0)
        second = self._rule('bbb', self.travel, position=0)
        self.assertEqual(
            [r.id for r in self.CategoryRule.objects.filter(user=self.user)],
            [first.id, second.id],
        )


class RulePreviewTests(APITestCase):
    """Counting what a rule would do, before it is saved."""

    def setUp(self):
        from portfolio.models import CategoryRule, TransactionCategory
        self.user, self.kek, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='EUR',
        )
        self.fuel = TransactionCategory.objects.create(user=self.user, name='Fuel')
        self.CategoryRule = CategoryRule
        self.client.force_authenticate(user=self.user)

    def _tx(self, counterparty, key=None, **kwargs):
        from portfolio.models import Transaction
        return Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 1),
            amount=Decimal('-60'), currency='EUR', counterparty=counterparty,
            source='camt053', dedup_key=key or f'k-{counterparty}', **kwargs,
        )

    def _preview(self, **body):
        return self.client.post(reverse('rule_preview'), body, format='json')

    def test_counts_only_rows_the_rule_would_claim(self):
        self._tx('Shell Station A5')
        self._tx('Shell Station B2', key='k2')
        self._tx('Migros')
        # Already categorized: rules never overwrite a category.
        self._tx('Shell Station C3', key='k3', category=self.fuel)
        resp = self._preview(match_text='shell')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['will_classify'], 2)
        self.assertEqual(resp.data['already_classified'], 1)
        self.assertEqual(resp.data['shadowed'], 0)
        self.assertEqual(resp.data['matched'], 3)

    def test_earlier_rule_shadows_the_new_one(self):
        self.CategoryRule.objects.create(
            user=self.user, match_text='station', category=self.fuel, position=0)
        self._tx('Shell Station A5')
        resp = self._preview(match_text='shell')
        # First-match-wins: a new rule is appended, so 'station' claims it.
        self.assertEqual(resp.data['will_classify'], 0)
        self.assertEqual(resp.data['shadowed'], 1)

    def test_editing_a_rule_keeps_its_own_position(self):
        mine = self.CategoryRule.objects.create(
            user=self.user, match_text='shell', category=self.fuel, position=0)
        self.CategoryRule.objects.create(
            user=self.user, match_text='station', category=self.fuel, position=1)
        self._tx('Shell Station A5')
        # As a new rule it would be shadowed by 'station'; in place it is not.
        self.assertEqual(self._preview(match_text='shell x').data['shadowed'], 0)
        resp = self._preview(match_text='shell x', rule_id=mine.id)
        self.assertEqual(resp.data['will_classify'], 0)  # 'shell x' matches nothing
        resp = self._preview(match_text='a5', rule_id=mine.id)
        self.assertEqual(resp.data['will_classify'], 1)
        self.assertEqual(resp.data['shadowed'], 0)

    def test_regex_and_examples(self):
        self._tx('Shell A5')
        self._tx('SHELL B2', key='k2')
        resp = self._preview(match_text=r'^shell\s', is_regex=True)
        self.assertEqual(resp.data['will_classify'], 2)
        self.assertEqual(len(resp.data['examples']), 2)
        self.assertIn(
            'shell', ' '.join(e['text'] for e in resp.data['examples']).lower())

    def test_invalid_regex_and_empty_text_are_rejected(self):
        self.assertEqual(self._preview(match_text='').status_code, 400)
        bad = self._preview(match_text='[unclosed', is_regex=True)
        self.assertEqual(bad.status_code, 400)
        self.assertIn('Invalid regular expression', bad.data['error'])

    def test_transfer_rule_skips_rows_already_marked(self):
        self._tx('Broker top-up', is_transfer=True)
        self._tx('Broker top-up 2', key='k2')
        resp = self._preview(match_text='broker top-up', is_transfer=True)
        self.assertEqual(resp.data['will_classify'], 1)
        self.assertEqual(resp.data['already_classified'], 1)

    def test_other_users_rows_and_rules_are_invisible(self):
        other, _, _ = make_kek_user(username='bob')
        other_account = FinancialAccount.objects.create(
            user=other, broker=self.broker, name='Theirs', currency='EUR')
        from portfolio.models import Transaction
        Transaction.objects.create(
            account=other_account, booking_date=date(2026, 8, 1),
            amount=Decimal('-60'), currency='EUR', counterparty='Shell Station',
            source='camt053', dedup_key='foreign')
        self.assertEqual(self._preview(match_text='shell').data['matched'], 0)
        foreign = self.CategoryRule.objects.create(
            user=other, match_text='x', position=0, is_transfer=True)
        self.assertEqual(
            self._preview(match_text='shell', rule_id=foreign.id).status_code, 404)


class RuleAmountRangeTests(APITestCase):
    """Rules can narrow to an amount range as well as matching text."""

    def setUp(self):
        from portfolio.models import CategoryRule, TransactionCategory
        self.user, self.kek, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        self.account = FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='Giro', currency='CHF',
        )
        self.coffee = TransactionCategory.objects.create(user=self.user, name='Coffee')
        self.groceries = TransactionCategory.objects.create(user=self.user, name='Groceries')
        self.CategoryRule = CategoryRule
        self.client.force_authenticate(user=self.user)

    def _tx(self, amount, counterparty='Migros', key=None):
        from portfolio.models import Transaction
        return Transaction.objects.create(
            account=self.account, booking_date=date(2026, 8, 1),
            amount=Decimal(amount), currency='CHF', counterparty=counterparty,
            source='camt053', dedup_key=key or f'k-{counterparty}-{amount}',
        )

    def test_range_selects_which_transactions_a_rule_claims(self):
        from portfolio.classification import apply_rules
        small = self._tx('-4.20')
        mid = self._tx('-19.99')
        big = self._tx('-42.00')
        self.CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.coffee, position=0,
            min_amount=Decimal('1.57'), min_inclusive=True,
            max_amount=Decimal('20.00'), max_inclusive=False,
        )
        self.CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.groceries, position=1)
        apply_rules(self.user)
        for tx, expected in ((small, self.coffee), (mid, self.coffee),
                             (big, self.groceries)):
            tx.refresh_from_db()
            self.assertEqual(tx.category, expected, f'{tx.amount}')

    def test_bounds_are_compared_without_the_sign(self):
        """Size is written the way it is spoken; direction is a separate axis."""
        from portfolio.classification import apply_rules
        spent = self._tx('-120.00', key='k1')
        refunded = self._tx('120.00', key='k2')
        under = self._tx('-90.00', key='k3')
        self.CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.groceries,
            position=0, min_amount=Decimal('95.99'), min_inclusive=False)
        apply_rules(self.user)
        for tx, expected in ((spent, self.groceries), (refunded, self.groceries),
                             (under, None)):
            tx.refresh_from_db()
            self.assertEqual(tx.category, expected, f'{tx.amount}')

    def test_direction_separates_payments_from_income(self):
        from portfolio.classification import apply_rules
        spent = self._tx('-50.00', key='k1')
        received = self._tx('50.00', key='k2')
        self.CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.groceries,
            position=0, direction='payment')
        apply_rules(self.user)
        spent.refresh_from_db(); received.refresh_from_db()
        self.assertEqual(spent.category, self.groceries)
        self.assertIsNone(received.category, 'a refund is not a payment')

    def test_direction_combines_with_the_bounds(self):
        """"payment and < 2.00" — the case a signed bound cannot express."""
        from portfolio.classification import apply_rules
        small_payment = self._tx('-1.00', key='k1')
        big_payment = self._tx('-9.00', key='k2')
        small_income = self._tx('1.00', key='k3')
        self.CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.coffee,
            position=0, direction='payment', max_amount=Decimal('2.00'))
        apply_rules(self.user)
        for tx, expected in ((small_payment, self.coffee), (big_payment, None),
                             (small_income, None)):
            tx.refresh_from_db()
            self.assertEqual(tx.category, expected, f'{tx.amount}')

    def test_direction_alone_needs_no_bounds(self):
        from portfolio.classification import amount_matches

        class R:
            min_amount = max_amount = None
            min_inclusive, max_inclusive = True, False

            def __init__(self, direction):
                self.direction = direction

        self.assertTrue(amount_matches(R('income'), Decimal('5')))
        self.assertFalse(amount_matches(R('income'), Decimal('-5')))
        self.assertTrue(amount_matches(R('payment'), Decimal('-5')))
        self.assertFalse(amount_matches(R('payment'), Decimal('5')))
        # Zero is neither, and 'any' takes everything.
        self.assertFalse(amount_matches(R('payment'), Decimal('0')))
        self.assertFalse(amount_matches(R('income'), Decimal('0')))
        self.assertTrue(amount_matches(R('any'), Decimal('0')))

    def test_same_text_allowed_when_only_the_direction_differs(self):
        url = reverse('rule_list')
        out = self.client.post(url, {
            'match_text': 'twint', 'category': self.groceries.id,
            'direction': 'payment',
        }, format='json')
        self.assertEqual(out.status_code, 201, out.data)
        inn = self.client.post(url, {
            'match_text': 'twint', 'category': self.coffee.id,
            'direction': 'income',
        }, format='json')
        self.assertEqual(inn.status_code, 201, inn.data)
        again = self.client.post(url, {
            'match_text': 'twint', 'category': self.coffee.id,
            'direction': 'payment',
        }, format='json')
        self.assertEqual(again.status_code, 400, again.data)

    def test_preview_respects_the_direction(self):
        self._tx('-4.20', key='k1')
        self._tx('4.20', key='k2')
        both = self.client.post(reverse('rule_preview'), {
            'match_text': 'migros'}, format='json')
        self.assertEqual(both.data['will_classify'], 2)
        payments = self.client.post(reverse('rule_preview'), {
            'match_text': 'migros', 'direction': 'payment'}, format='json')
        self.assertEqual(payments.data['will_classify'], 1)
        bad = self.client.post(reverse('rule_preview'), {
            'match_text': 'migros', 'direction': 'sideways'}, format='json')
        self.assertEqual(bad.status_code, 400)

    def test_existing_rules_keep_matching_everything(self):
        """Rules created before the feature must not narrow silently."""
        rule = self.CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.groceries,
            position=0)
        self.assertEqual(rule.direction, 'any')
        from portfolio.classification import apply_rules
        spent = self._tx('-50.00', key='k1')
        received = self._tx('50.00', key='k2')
        apply_rules(self.user)
        for tx in (spent, received):
            tx.refresh_from_db()
            self.assertEqual(tx.category, self.groceries)

    def test_exclusive_and_inclusive_edges(self):
        from portfolio.classification import amount_matches

        class R:
            def __init__(self, **kw):
                self.min_amount = self.max_amount = None
                self.min_inclusive, self.max_inclusive = True, False
                self.__dict__.update(kw)

        gte = R(min_amount=Decimal('20'), min_inclusive=True)
        gt = R(min_amount=Decimal('20'), min_inclusive=False)
        self.assertTrue(amount_matches(gte, Decimal('-20')))
        self.assertFalse(amount_matches(gt, Decimal('-20')))
        lte = R(max_amount=Decimal('20'), max_inclusive=True)
        lt = R(max_amount=Decimal('20'), max_inclusive=False)
        self.assertTrue(amount_matches(lte, Decimal('-20')))
        self.assertFalse(amount_matches(lt, Decimal('-20')))
        # A rule with no bounds is every rule that predates the feature.
        self.assertTrue(amount_matches(R(), Decimal('-1')))

    def test_same_text_allowed_with_a_different_range_but_not_the_same(self):
        url = reverse('rule_list')
        first = self.client.post(url, {
            'match_text': 'migros', 'category': self.coffee.id,
            'max_amount': '20.00',
        }, format='json')
        self.assertEqual(first.status_code, 201, first.data)
        # Same text, no range — reachable for anything over 20.
        second = self.client.post(url, {
            'match_text': 'migros', 'category': self.groceries.id,
        }, format='json')
        self.assertEqual(second.status_code, 201, second.data)
        # Same text AND the same range could never fire.
        third = self.client.post(url, {
            'match_text': 'migros', 'category': self.groceries.id,
            'max_amount': '20.00',
        }, format='json')
        self.assertEqual(third.status_code, 400, third.data)

    def test_impossible_and_negative_ranges_are_rejected(self):
        url = reverse('rule_list')
        empty = self.client.post(url, {
            'match_text': 'a', 'category': self.coffee.id,
            'min_amount': '50', 'max_amount': '10',
        }, format='json')
        self.assertEqual(empty.status_code, 400, empty.data)
        negative = self.client.post(url, {
            'match_text': 'b', 'category': self.coffee.id, 'min_amount': '-5',
        }, format='json')
        self.assertEqual(negative.status_code, 400, negative.data)
        # min == max is fine only when both ends are inclusive.
        point = self.client.post(url, {
            'match_text': 'c', 'category': self.coffee.id,
            'min_amount': '10', 'max_amount': '10', 'max_inclusive': True,
        }, format='json')
        self.assertEqual(point.status_code, 201, point.data)

    def test_preview_counts_respect_the_range(self):
        self._tx('-4.20', key='k1')
        self._tx('-42.00', key='k2')
        resp = self.client.post(reverse('rule_preview'), {
            'match_text': 'migros', 'max_amount': '20',
        }, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['will_classify'], 1)
        self.assertEqual(resp.data['matched'], 1)
        # Without the bound both rows match.
        wide = self.client.post(reverse('rule_preview'), {
            'match_text': 'migros'}, format='json')
        self.assertEqual(wide.data['will_classify'], 2)

    def test_a_narrow_rule_is_not_shadowed_by_a_broad_one_it_outranks(self):
        """The range is what makes two same-text rules both reachable."""
        self.CategoryRule.objects.create(
            user=self.user, match_text='migros', category=self.groceries,
            position=0, min_amount=Decimal('20'))
        self._tx('-4.20', key='k1')
        resp = self.client.post(reverse('rule_preview'), {
            'match_text': 'migros', 'max_amount': '20',
        }, format='json')
        self.assertEqual(resp.data['will_classify'], 1)
        self.assertEqual(resp.data['shadowed'], 0)


class AiPricingRefreshTests(APITestCase):
    def setUp(self):
        self.user, self.kek, _ = make_kek_user()
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)
        self.client.put(reverse('ai_config'), {
            'api_key': 'k', 'model': 'gemini-3.6-flash', 'display_name': 'Gemini 3.6 Flash',
        }, format='json')

    def test_saving_a_model_snapshots_its_price_with_a_timestamp(self):
        resp = self.client.get(reverse('ai_config'))
        pricing = resp.data['pricing']
        self.assertEqual(pricing['display_name'], 'Gemini 3.6 Flash')
        self.assertEqual(pricing['input_price_per_1m'], 0.75)
        self.assertEqual(pricing['output_price_per_1m'], 3.75)
        self.assertTrue(pricing['checked_at'])
        self.assertTrue(resp.data['pricing_source_url'].startswith('https://'))

    @patch('portfolio.ai_categorization.list_models')
    def test_refresh_restamps_and_reports_unchanged(self, m_list):
        m_list.return_value = [{
            'id': 'gemini-3.6-flash', 'display_name': 'Gemini 3.6 Flash',
            'input_price_per_1m': 0.75, 'output_price_per_1m': 3.75,
        }]
        before = self.client.get(reverse('ai_config')).data['pricing']['checked_at']
        resp = self.client.post(reverse('ai_refresh_pricing'), {}, format='json')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertFalse(resp.data['changed'])
        self.assertTrue(resp.data['model_still_available'])
        self.assertGreaterEqual(resp.data['pricing']['checked_at'], before)

    @patch('portfolio.ai_categorization.list_models')
    def test_refresh_flags_a_model_the_key_no_longer_offers(self, m_list):
        m_list.return_value = [{
            'id': 'gemini-9-flash', 'display_name': 'Other',
            'input_price_per_1m': None, 'output_price_per_1m': None,
        }]
        resp = self.client.post(reverse('ai_refresh_pricing'), {}, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.data['model_still_available'])

    def test_refresh_requires_configuration(self):
        self.client.delete(reverse('ai_config'))
        resp = self.client.post(reverse('ai_refresh_pricing'), {}, format='json')
        self.assertEqual(resp.status_code, 400)


class AiPricingBackfillTests(APITestCase):
    """A model chosen before pricing snapshots existed must still show a price."""

    def setUp(self):
        self.user, self.kek, _ = make_kek_user()
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def test_config_get_fills_a_missing_pricing_snapshot(self):
        profile = self.user.profile
        profile.encrypted_gemini_key = b'blob'
        profile.gemini_model = 'gemini-3.7-flash'
        profile.gemini_pricing = None  # pre-existing configuration
        profile.save()

        resp = self.client.get(reverse('ai_config'))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['pricing']['input_price_per_1m'], 0.75)
        self.assertEqual(resp.data['pricing']['model'], 'gemini-3.7-flash')
        # Persisted, so the timestamp does not move on every read.
        profile.refresh_from_db()
        self.assertIsNotNone(profile.gemini_pricing)
        stamped = profile.gemini_pricing['checked_at']
        self.assertEqual(
            self.client.get(reverse('ai_config')).data['pricing']['checked_at'],
            stamped,
        )

    def test_no_model_means_no_snapshot(self):
        resp = self.client.get(reverse('ai_config'))
        self.assertEqual(resp.status_code, 200)
        self.assertIsNone(resp.data['pricing'])
