"""Tests for the EBICS integration, the broker factory, and EBICS endpoints."""
import base64
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from django.test import TestCase
from django.urls import reverse
from ebicsclient import (
    Balance,
    CreditDebit,
    InitializationState,
    Statement,
)
from rest_framework.test import APITestCase

from brokers.integrations import get_broker_integration
from brokers.integrations.base import AccountInfo, BalanceInfo
from brokers.integrations.zkb_ebics import (
    EbicsSubscriberBlockedError,
    ZKBEbicsIntegration,
    _client_for,
    generate_keyring_blob,
    submit_keys_and_letter,
)
from brokers.models import Broker, EbicsCredential
from core.kek_testing import make_kek_user


def make_balance(amount, credit_debit=CreditDebit.CREDIT, currency='CHF',
                 bal_date=None, code='CLBD'):
    return Balance(
        code=code,
        amount=Decimal(str(amount)),
        currency=currency,
        credit_debit=credit_debit,
        date=bal_date or date(2026, 7, 1),
    )


def make_statement(iban, closing, entries=None):
    return Statement(
        identification='STMT-1',
        iban=iban,
        opening_balance=None,
        closing_balance=closing,
        balances=[closing] if closing else [],
        entries=entries or [],
    )


# ---------------------------------------------------------------------------
# Area 2: EBICS integration (network mocked)
# ---------------------------------------------------------------------------

class KeyringBlobTests(TestCase):
    def test_generate_keyring_blob_roundtrips_through_deserialize(self):
        from ebicsclient import deserialize_keyring

        blob = generate_keyring_blob()
        self.assertIn('keyring_pem', blob)
        self.assertIn('keyring_passphrase', blob)
        # The pem is base64; decoding + deserialize with the passphrase must work.
        pem = base64.b64decode(blob['keyring_pem'])
        keyring = deserialize_keyring(pem, blob['keyring_passphrase'])
        self.assertIsNotNone(keyring)

    def test_generate_keyring_blob_is_random(self):
        self.assertNotEqual(
            generate_keyring_blob()['keyring_passphrase'],
            generate_keyring_blob()['keyring_passphrase'],
        )


class ZKBEbicsAuthenticateTests(TestCase):
    def _credentials(self, **overrides):
        blob = generate_keyring_blob()
        creds = {
            'host_id': 'ZKBKCHZZ',
            'partner_id': 'PARTNER1',
            'user_id': 'SUBSCRIBER1',
            'url': 'https://ebics.zkb.ch/ebics',
            'keyring_pem': blob['keyring_pem'],
            'keyring_passphrase': blob['keyring_passphrase'],
        }
        creds.update(overrides)
        return creds

    def test_authenticate_success_builds_client(self):
        integration = ZKBEbicsIntegration(self._credentials())
        result = integration.authenticate()
        self.assertTrue(result.success)
        self.assertIsNone(result.error_message)

    def test_authenticate_missing_keyring_fails(self):
        creds = self._credentials()
        creds.pop('keyring_pem')
        result = ZKBEbicsIntegration(creds).authenticate()
        self.assertFalse(result.success)
        self.assertIn('keyring', result.error_message.lower())

    def test_authenticate_bad_passphrase_fails_gracefully(self):
        result = ZKBEbicsIntegration(
            self._credentials(keyring_passphrase='wrong-passphrase')
        ).authenticate()
        self.assertFalse(result.success)

    def test_complete_2fa_not_supported(self):
        result = ZKBEbicsIntegration(self._credentials()).complete_2fa(None, {})
        self.assertFalse(result.success)


class ZKBEbicsBalanceTests(TestCase):
    """get_balance / get_accounts by seeding the cached statements (no network)."""

    def setUp(self):
        self.integration = ZKBEbicsIntegration({})

    def test_get_balance_credit_is_positive(self):
        stmt = make_statement('CH1', make_balance('1234.56', CreditDebit.CREDIT))
        self.integration._statements = [stmt]
        info = self.integration.get_balance('CH1')
        self.assertIsInstance(info, BalanceInfo)
        self.assertEqual(info.balance, Decimal('1234.56'))
        self.assertEqual(info.currency, 'CHF')
        self.assertEqual(info.balance_date, date(2026, 7, 1))
        self.assertEqual(info.raw_data['credit_debit'], 'CRDT')
        self.assertEqual(info.raw_data['source'], 'ebics_camt053')

    def test_get_balance_debit_is_negative(self):
        stmt = make_statement('CH2', make_balance('500.00', CreditDebit.DEBIT))
        self.integration._statements = [stmt]
        info = self.integration.get_balance('CH2')
        self.assertEqual(info.balance, Decimal('-500.00'))

    def test_get_balance_unknown_iban_raises(self):
        self.integration._statements = [
            make_statement('CH1', make_balance('1')),
        ]
        with self.assertRaises(ValueError) as ctx:
            self.integration.get_balance('CH-DOES-NOT-EXIST')
        self.assertIn('CH1', str(ctx.exception))  # lists what IS available

    def test_get_balance_picks_most_recent_statement(self):
        old = make_statement('CH1', make_balance('100', bal_date=date(2026, 1, 1)))
        new = make_statement('CH1', make_balance('900', bal_date=date(2026, 6, 1)))
        self.integration._statements = [old, new]
        self.assertEqual(self.integration.get_balance('CH1').balance, Decimal('900'))

    def test_get_accounts_maps_statements(self):
        self.integration._statements = [
            make_statement('CH1', make_balance('1', currency='CHF')),
            make_statement('CH2', make_balance('2', currency='EUR')),
            make_statement('', make_balance('3')),  # no IBAN -> skipped
        ]
        accounts = self.integration.get_accounts()
        self.assertEqual(len(accounts), 2)
        self.assertTrue(all(isinstance(a, AccountInfo) for a in accounts))
        by_id = {a.identifier: a for a in accounts}
        self.assertEqual(by_id['CH1'].currency, 'CHF')
        self.assertEqual(by_id['CH2'].currency, 'EUR')
        self.assertEqual(by_id['CH1'].account_type, 'checking')


class BrokerFactoryTests(TestCase):
    def test_factory_returns_zkb_ebics_for_ebics_broker(self):
        broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')
        integration = get_broker_integration(broker, {'host_id': 'X'})
        self.assertIsInstance(integration, ZKBEbicsIntegration)

    def test_factory_unknown_broker_raises(self):
        broker = Broker.objects.create(code='mystery', name='Mystery', integration_type='rest')
        with self.assertRaises(ValueError):
            get_broker_integration(broker, {})


class ClientForRegressionTests(TestCase):
    """`_client_for` must pass the string subscriber_id, never the integer user FK PK."""

    def setUp(self):
        self.user, _, _ = make_kek_user()
        self.broker = Broker.objects.create(code='zkb', name='ZKB', integration_type='ebics')

    def _cred(self):
        return EbicsCredential.objects.create(
            user=self.user, broker=self.broker, label='ZKB',
            host_id='ZKBKCHZZ', partner_id='PARTNER1', subscriber_id='TEILNEHMER-42',
            url='https://ebics.zkb.ch/ebics',
        )

    def test_client_for_uses_subscriber_id_string(self):
        cred = self._cred()
        # Sanity: the FK PK and the EBICS subscriber id genuinely differ.
        self.assertNotEqual(str(cred.user_id), cred.subscriber_id)

        blob = {'keyring_pem': base64.b64encode(b'pem').decode(), 'keyring_passphrase': 'p'}
        with patch('ebicsclient.deserialize_keyring') as m_deser, \
                patch('ebicsclient.Bank') as m_bank, \
                patch('ebicsclient.User') as m_user, \
                patch('ebicsclient.Client') as m_client:
            _client_for(cred, blob)

        m_user.assert_called_once()
        kwargs = m_user.call_args.kwargs
        self.assertEqual(kwargs['user_id'], 'TEILNEHMER-42')
        self.assertEqual(kwargs['partner_id'], 'PARTNER1')
        # Explicitly assert it is NOT the Django user FK integer PK.
        self.assertNotEqual(kwargs['user_id'], cred.user_id)
        self.assertNotEqual(kwargs['user_id'], str(cred.user_id))
        m_bank.assert_called_once_with(host_id='ZKBKCHZZ', url='https://ebics.zkb.ch/ebics')
        m_deser.assert_called_once()
        m_client.assert_called_once()


class SubmitKeysAndLetterTests(TestCase):
    """The bank answers 091002 (ALREADY_INITIALISED) for BOTH a benign re-send of the
    same keys AND a rejected send of *different* keys — the response can't distinguish
    them. Since we only ever call this with a freshly generated keyring, ALREADY_INITIALISED
    means our keys were silently dropped: we must NOT render a letter (its fingerprints
    would never match the bank's keys) and must raise so the caller can tell the user."""

    @patch('brokers.integrations.zkb_ebics._client_for')
    def test_submitted_returns_letter(self, m_client_for):
        client = MagicMock()
        client.ini.return_value = InitializationState.SUBMITTED
        client.hia.return_value = InitializationState.SUBMITTED
        client.make_ini_letter.return_value = SimpleNamespace(
            media_type='application/pdf', content=b'%PDF',
        )
        m_client_for.return_value = client

        ini, hia, letter = submit_keys_and_letter(SimpleNamespace(), {'k': 'v'})
        self.assertEqual(ini, InitializationState.SUBMITTED)
        self.assertEqual(hia, InitializationState.SUBMITTED)
        self.assertEqual(letter.content, b'%PDF')
        client.make_ini_letter.assert_called_once()

    @patch('brokers.integrations.zkb_ebics._client_for')
    def test_already_initialised_raises_and_skips_letter(self, m_client_for):
        client = MagicMock()
        client.ini.return_value = InitializationState.ALREADY_INITIALISED
        client.hia.return_value = InitializationState.ALREADY_INITIALISED
        m_client_for.return_value = client

        with self.assertRaises(EbicsSubscriberBlockedError):
            submit_keys_and_letter(SimpleNamespace(), {'k': 'v'})
        # No letter may be produced for keys the bank never accepted.
        client.make_ini_letter.assert_not_called()

    @patch('brokers.integrations.zkb_ebics._client_for')
    def test_partial_already_initialised_also_raises(self, m_client_for):
        # Even a mixed result (one leg accepted, the other already-initialised) is a
        # non-delivery: fail closed rather than mail a half-valid letter.
        client = MagicMock()
        client.ini.return_value = InitializationState.SUBMITTED
        client.hia.return_value = InitializationState.ALREADY_INITIALISED
        m_client_for.return_value = client

        with self.assertRaises(EbicsSubscriberBlockedError):
            submit_keys_and_letter(SimpleNamespace(), {'k': 'v'})
        client.make_ini_letter.assert_not_called()


# ---------------------------------------------------------------------------
# Broker list/detail endpoints
# ---------------------------------------------------------------------------

class BrokerEndpointTests(APITestCase):
    def setUp(self):
        self.user, self.kek, _ = make_kek_user()
        self.client.force_authenticate(user=self.user)
        self.active = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        self.inactive = Broker.objects.create(
            code='old', name='Old', integration_type='rest', is_active=False,
        )

    def test_list_returns_only_active_brokers(self):
        resp = self.client.get(reverse('broker_list'))
        self.assertEqual(resp.status_code, 200)
        codes = [b['code'] for b in resp.data['results']]
        self.assertIn('viac', codes)
        self.assertNotIn('old', codes)

    def test_detail_by_code(self):
        resp = self.client.get(reverse('broker_detail', args=['viac']))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['name'], 'VIAC')

    def test_detail_inactive_404(self):
        resp = self.client.get(reverse('broker_detail', args=['old']))
        self.assertEqual(resp.status_code, 404)

    def test_list_requires_authentication(self):
        self.client.force_authenticate(user=None)
        self.assertEqual(self.client.get(reverse('broker_list')).status_code, 401)


# ---------------------------------------------------------------------------
# Area 3: EBICS credential endpoints
# ---------------------------------------------------------------------------

class EbicsEndpointTestBase(APITestCase):
    def setUp(self):
        self.user, self.kek, self.user_key = make_kek_user(username='alice')
        self.broker = Broker.objects.create(
            code='zkb', name='ZKB', integration_type='ebics',
            api_base_url='https://ebics.zkb.ch/ebics',
        )
        self.non_ebics = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        self.client.force_authenticate(user=self.user)
        self.client.credentials(HTTP_X_KEK=self.kek)

    def _create_cred(self, **overrides):
        """Create a credential directly (encrypted keyring under this user's KEK)."""
        from django.test import RequestFactory

        from core.kek_auth import KEKAuthenticationMixin
        request = RequestFactory().get('/', HTTP_X_KEK=self.kek)
        request.user = self.user
        blob = {'keyring_pem': base64.b64encode(b'pem').decode(), 'keyring_passphrase': 'pp'}
        data = dict(
            user=self.user, broker=self.broker, label='ZKB DataLink',
            host_id='ZKBKCHZZ', partner_id='PARTNER1', subscriber_id='SUB1',
            url='https://ebics.zkb.ch/ebics',
            encrypted_keyring=KEKAuthenticationMixin().encrypt_blob(request, blob),
            state='new',
        )
        data.update(overrides)
        return EbicsCredential.objects.create(**data)


class EbicsCredentialCrudTests(EbicsEndpointTestBase):
    def _payload(self, **overrides):
        data = {
            'broker_code': 'zkb', 'label': 'ZKB DataLink',
            'host_id': 'ZKBKCHZZ', 'partner_id': 'PARTNER1', 'user_id': 'SUB1',
        }
        data.update(overrides)
        return data

    @patch('brokers.integrations.zkb_ebics.generate_keyring_blob')
    def test_create_credential(self, m_gen):
        m_gen.return_value = {'keyring_pem': base64.b64encode(b'pem').decode(),
                              'keyring_passphrase': 'pp'}
        resp = self.client.post(reverse('ebics_credential_list'), self._payload(), format='json')
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(resp.data['state'], 'new')
        self.assertEqual(resp.data['user_id'], 'SUB1')  # exposed as subscriber_id
        self.assertTrue(resp.data['initialized'])
        cred = EbicsCredential.objects.get(pk=resp.data['id'])
        self.assertEqual(cred.subscriber_id, 'SUB1')
        self.assertIsNotNone(cred.encrypted_keyring)
        # URL is sourced from the broker, not the client (SSRF prevention).
        self.assertEqual(cred.url, 'https://ebics.zkb.ch/ebics')

    @patch('brokers.integrations.zkb_ebics.generate_keyring_blob')
    def test_create_ignores_client_supplied_url(self, m_gen):
        m_gen.return_value = {'keyring_pem': base64.b64encode(b'pem').decode(),
                              'keyring_passphrase': 'pp'}
        # A malicious url in the body must be ignored; the broker's url is used.
        resp = self.client.post(
            reverse('ebics_credential_list'),
            self._payload(url='https://169.254.169.254/latest/meta-data/'),
            format='json',
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        cred = EbicsCredential.objects.get(pk=resp.data['id'])
        self.assertEqual(cred.url, 'https://ebics.zkb.ch/ebics')

    def test_create_ebics_broker_without_url_400(self):
        Broker.objects.filter(code='zkb').update(api_base_url='')
        resp = self.client.post(reverse('ebics_credential_list'), self._payload(), format='json')
        self.assertEqual(resp.status_code, 400)
        self.assertIn('URL', resp.data['error'])

    def test_url_not_patchable(self):
        cred = self._create_cred()
        resp = self.client.patch(
            reverse('ebics_credential_detail', args=[cred.id]),
            {'url': 'https://evil.example/ebics', 'label': 'Renamed'}, format='json',
        )
        self.assertEqual(resp.status_code, 200)
        cred.refresh_from_db()
        self.assertEqual(cred.url, 'https://ebics.zkb.ch/ebics')  # unchanged
        self.assertEqual(cred.label, 'Renamed')  # label still patchable

    def test_create_without_kek_denied(self):
        self.client.credentials()  # clear X-KEK
        resp = self.client.post(reverse('ebics_credential_list'), self._payload(), format='json')
        self.assertEqual(resp.status_code, 403)

    def test_create_non_ebics_broker_400(self):
        resp = self.client.post(
            reverse('ebics_credential_list'), self._payload(broker_code='viac'), format='json',
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn('EBICS', resp.data['error'])

    def test_create_unknown_broker_400(self):
        resp = self.client.post(
            reverse('ebics_credential_list'), self._payload(broker_code='nope'), format='json',
        )
        self.assertEqual(resp.status_code, 400)

    @patch('brokers.integrations.zkb_ebics.generate_keyring_blob')
    def test_create_duplicate_400(self, m_gen):
        m_gen.return_value = {'keyring_pem': base64.b64encode(b'pem').decode(),
                              'keyring_passphrase': 'pp'}
        url = reverse('ebics_credential_list')
        self.assertEqual(self.client.post(url, self._payload(), format='json').status_code, 201)
        dup = self.client.post(url, self._payload(label='Second'), format='json')
        self.assertEqual(dup.status_code, 400)
        self.assertIn('already exists', dup.data['error'])

    def test_list_only_own_credentials(self):
        self._create_cred()
        other, _, _ = make_kek_user(username='bob')
        EbicsCredential.objects.create(
            user=other, broker=self.broker, label='Bob ZKB',
            host_id='H', partner_id='P', subscriber_id='S', url='https://x/ebics',
        )
        resp = self.client.get(reverse('ebics_credential_list'))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data), 1)
        self.assertEqual(resp.data[0]['label'], 'ZKB DataLink')

    def test_detail_and_patch(self):
        cred = self._create_cred()
        url = reverse('ebics_credential_detail', args=[cred.pk])
        self.assertEqual(self.client.get(url).status_code, 200)
        resp = self.client.patch(url, {'label': 'Renamed', 'bank_hash_auth': 'AA BB'},
                                 format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['label'], 'Renamed')
        cred.refresh_from_db()
        self.assertEqual(cred.label, 'Renamed')
        self.assertEqual(cred.bank_hash_auth, 'aabb')  # spaces stripped, lowercased

    def test_cannot_see_other_users_credential(self):
        other, _, _ = make_kek_user(username='bob')
        cred = EbicsCredential.objects.create(
            user=other, broker=self.broker, label='Bob',
            host_id='H', partner_id='P', subscriber_id='S', url='https://x/ebics',
        )
        resp = self.client.get(reverse('ebics_credential_detail', args=[cred.pk]))
        self.assertEqual(resp.status_code, 404)

    def test_delete_credential(self):
        cred = self._create_cred()
        resp = self.client.delete(reverse('ebics_credential_detail', args=[cred.pk]))
        self.assertEqual(resp.status_code, 204)
        self.assertFalse(EbicsCredential.objects.filter(pk=cred.pk).exists())

    def test_cannot_delete_other_users_credential(self):
        other, _, _ = make_kek_user(username='bob')
        cred = EbicsCredential.objects.create(
            user=other, broker=self.broker, label='Bob',
            host_id='H', partner_id='P', subscriber_id='S', url='https://x/ebics',
        )
        resp = self.client.delete(reverse('ebics_credential_detail', args=[cred.pk]))
        self.assertEqual(resp.status_code, 404)
        self.assertTrue(EbicsCredential.objects.filter(pk=cred.pk).exists())

    def test_delete_blocked_when_accounts_linked(self):
        from portfolio.models import FinancialAccount
        cred = self._create_cred()
        FinancialAccount.objects.create(
            user=self.user, broker=self.broker, name='ZKB acct', ebics_credential=cred,
        )
        resp = self.client.delete(reverse('ebics_credential_detail', args=[cred.pk]))
        self.assertEqual(resp.status_code, 400)
        self.assertTrue(EbicsCredential.objects.filter(pk=cred.pk).exists())


class EbicsInitializeTests(EbicsEndpointTestBase):
    @patch('brokers.integrations.zkb_ebics.submit_keys_and_letter')
    def test_initialize_transitions_to_keys_sent_and_returns_letter(self, m_submit):
        cred = self._create_cred()
        letter = SimpleNamespace(media_type='application/pdf', content=b'%PDF-1.7 fake')
        m_submit.return_value = (
            InitializationState.SUBMITTED, InitializationState.SUBMITTED, letter,
        )
        resp = self.client.post(reverse('ebics_credential_initialize', args=[cred.pk]))
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['status'], 'keys_sent')
        self.assertEqual(resp.data['ini'], 'submitted')
        self.assertEqual(resp.data['hia'], 'submitted')
        self.assertEqual(resp.data['letter']['media_type'], 'application/pdf')
        self.assertEqual(base64.b64decode(resp.data['letter']['content_base64']), b'%PDF-1.7 fake')
        cred.refresh_from_db()
        self.assertEqual(cred.state, 'keys_sent')

    @patch('brokers.integrations.zkb_ebics.submit_keys_and_letter')
    def test_initialize_failure_returns_502_and_records_error(self, m_submit):
        cred = self._create_cred()
        m_submit.side_effect = RuntimeError('bank rejected keys')
        resp = self.client.post(reverse('ebics_credential_initialize', args=[cred.pk]))
        self.assertEqual(resp.status_code, 502)
        cred.refresh_from_db()
        self.assertEqual(cred.state, 'new')  # unchanged
        self.assertIn('bank rejected keys', cred.last_error)

    @patch('brokers.integrations.zkb_ebics.submit_keys_and_letter')
    def test_initialize_blocked_subscriber_returns_409_no_letter(self, m_submit):
        # The bank rejected our fresh keys as already-initialised: the credential must
        # go to 'error' with an actionable message, and NO letter may be returned.
        cred = self._create_cred()
        m_submit.side_effect = EbicsSubscriberBlockedError(
            InitializationState.ALREADY_INITIALISED,
            InitializationState.ALREADY_INITIALISED,
        )
        resp = self.client.post(reverse('ebics_credential_initialize', args=[cred.pk]))
        self.assertEqual(resp.status_code, 409, resp.data)
        self.assertEqual(resp.data['code'], 'subscriber_blocked')
        self.assertIn('091002', resp.data['error'])
        self.assertIn('reset', resp.data['hint'].lower())
        self.assertNotIn('letter', resp.data)  # nothing to mail
        cred.refresh_from_db()
        self.assertEqual(cred.state, 'error')
        self.assertIn('reset', cred.last_error.lower())

    def test_initialize_other_user_404(self):
        other, _, _ = make_kek_user(username='bob')
        cred = EbicsCredential.objects.create(
            user=other, broker=self.broker, label='Bob',
            host_id='H', partner_id='P', subscriber_id='S', url='https://x/ebics',
            encrypted_keyring=b'x',
        )
        resp = self.client.post(reverse('ebics_credential_initialize', args=[cred.pk]))
        self.assertEqual(resp.status_code, 404)


class EbicsLetterTests(EbicsEndpointTestBase):
    @patch('brokers.integrations.zkb_ebics.render_letter')
    def test_letter_rerendered(self, m_render):
        cred = self._create_cred()
        m_render.return_value = SimpleNamespace(
            media_type='application/pdf', content=b'%PDF letter',
        )
        resp = self.client.get(reverse('ebics_credential_letter', args=[cred.pk]))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(
            base64.b64decode(resp.data['letter']['content_base64']), b'%PDF letter',
        )


class EbicsTestConnectionTests(EbicsEndpointTestBase):
    @patch('brokers.integrations.zkb_ebics.fetch_bank_keys_and_statements')
    def test_test_connection_activates_and_lists_ibans(self, m_fetch):
        cred = self._create_cred()
        stmt = make_statement('CH1', make_balance('4200.00', CreditDebit.CREDIT))
        m_fetch.return_value = ({'auth': 'aa11', 'enc': 'bb22'}, [stmt])
        resp = self.client.post(reverse('ebics_credential_test', args=[cred.pk]))
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data['status'], 'active')
        self.assertTrue(resp.data['bank_key_hashes_recorded'])  # TOFU on first use
        self.assertEqual(len(resp.data['accounts']), 1)
        self.assertEqual(resp.data['accounts'][0]['iban'], 'CH1')
        self.assertEqual(resp.data['accounts'][0]['balance'], 4200.0)
        cred.refresh_from_db()
        self.assertEqual(cred.state, 'active')
        self.assertEqual(cred.bank_hash_auth, 'aa11')

    @patch('brokers.integrations.zkb_ebics.fetch_bank_keys_and_statements')
    def test_test_connection_debit_balance_is_negative(self, m_fetch):
        cred = self._create_cred()
        stmt = make_statement('CH9', make_balance('300.00', CreditDebit.DEBIT))
        m_fetch.return_value = ({'auth': 'a', 'enc': 'b'}, [stmt])
        resp = self.client.post(reverse('ebics_credential_test', args=[cred.pk]))
        self.assertEqual(resp.data['accounts'][0]['balance'], -300.0)

    @patch('brokers.integrations.zkb_ebics.fetch_bank_keys_and_statements')
    def test_test_connection_failure_502(self, m_fetch):
        cred = self._create_cred()
        m_fetch.side_effect = RuntimeError('subscriber not activated')
        resp = self.client.post(reverse('ebics_credential_test', args=[cred.pk]))
        self.assertEqual(resp.status_code, 502)
        cred.refresh_from_db()
        self.assertEqual(cred.state, 'new')
        self.assertIn('subscriber not activated', cred.last_error)
