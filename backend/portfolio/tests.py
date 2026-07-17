"""Tests for portfolio models, serializers, and account/snapshot/sync endpoints."""
from datetime import date
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
        self.broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
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
