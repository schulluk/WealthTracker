"""Tests for the security core: per-user encryption and the KEK auth mixin."""
import base64
import os

from cryptography.fernet import Fernet, InvalidToken
from django.test import RequestFactory, TestCase
from rest_framework.exceptions import PermissionDenied

from brokers.models import Broker, EbicsCredential
from core.kek_auth import KEKAuthenticationMixin
from core.kek_testing import make_kek_user
from core.user_encryption import (
    decrypt_credentials,
    decrypt_user_key,
    encrypt_credentials,
    encrypt_user_key,
    generate_salt,
    generate_user_key,
    pad_kek_for_fernet,
)
from portfolio.models import FinancialAccount


class UserEncryptionTests(TestCase):
    """Pure-function tests for core.user_encryption."""

    def test_generate_salt_is_16_bytes_base64(self):
        salt = generate_salt()
        self.assertEqual(len(base64.b64decode(salt)), 16)
        # Two salts should differ.
        self.assertNotEqual(salt, generate_salt())

    def test_generate_user_key_is_valid_fernet_key(self):
        key = generate_user_key()
        # Must be usable directly as a Fernet key.
        Fernet(key)
        self.assertNotEqual(key, generate_user_key())

    def test_encrypt_decrypt_credentials_roundtrip(self):
        user_key = generate_user_key()
        creds = {'username': 'bob', 'password': 's3cr3t', 'totp': '1234567890'}
        blob = encrypt_credentials(creds, user_key)
        self.assertIsInstance(blob, bytes)
        # Ciphertext must not leak the plaintext.
        self.assertNotIn(b's3cr3t', blob)
        self.assertEqual(decrypt_credentials(blob, user_key), creds)

    def test_decrypt_credentials_empty_returns_empty_dict(self):
        self.assertEqual(decrypt_credentials(b'', generate_user_key()), {})
        self.assertEqual(decrypt_credentials(None, generate_user_key()), {})

    def test_decrypt_credentials_handles_memoryview(self):
        user_key = generate_user_key()
        blob = encrypt_credentials({'a': 1}, user_key)
        self.assertEqual(decrypt_credentials(memoryview(blob), user_key), {'a': 1})

    def test_decrypt_credentials_wrong_key_fails(self):
        blob = encrypt_credentials({'a': 1}, generate_user_key())
        with self.assertRaises(InvalidToken):
            decrypt_credentials(blob, generate_user_key())

    def test_encrypt_decrypt_user_key_under_kek_roundtrip(self):
        kek = pad_kek_for_fernet(os.urandom(32))
        user_key = generate_user_key()
        wrapped = encrypt_user_key(user_key, kek)
        self.assertNotEqual(wrapped, user_key)
        self.assertEqual(decrypt_user_key(wrapped, kek), user_key)

    def test_decrypt_user_key_handles_memoryview(self):
        kek = pad_kek_for_fernet(os.urandom(32))
        user_key = generate_user_key()
        wrapped = encrypt_user_key(user_key, kek)
        self.assertEqual(decrypt_user_key(memoryview(wrapped), kek), user_key)

    def test_decrypt_user_key_wrong_kek_fails(self):
        kek1 = pad_kek_for_fernet(os.urandom(32))
        kek2 = pad_kek_for_fernet(os.urandom(32))
        wrapped = encrypt_user_key(generate_user_key(), kek1)
        with self.assertRaises(InvalidToken):
            decrypt_user_key(wrapped, kek2)


class PadKekForFernetTests(TestCase):
    def test_raw_32_bytes_is_base64url_encoded(self):
        raw = os.urandom(32)
        padded = pad_kek_for_fernet(raw)
        self.assertEqual(len(padded), 44)
        self.assertEqual(base64.urlsafe_b64encode(raw), padded)
        # Result must be a valid Fernet key.
        Fernet(padded)

    def test_already_44_byte_b64_passthrough(self):
        already = base64.urlsafe_b64encode(os.urandom(32))
        self.assertEqual(len(already), 44)
        self.assertEqual(pad_kek_for_fernet(already), already)

    def test_invalid_length_raises_value_error(self):
        with self.assertRaises(ValueError):
            pad_kek_for_fernet(os.urandom(16))
        with self.assertRaises(ValueError):
            pad_kek_for_fernet(b'')

    def test_full_kek_chain_matches_get_user_key(self):
        """Raw 32-byte KEK -> pad -> wrap -> unwrap yields the original user key."""
        kek_raw = os.urandom(32)
        fernet_kek = pad_kek_for_fernet(kek_raw)
        user_key = generate_user_key()
        wrapped = encrypt_user_key(user_key, fernet_kek)
        # Re-derive from raw as the mixin does.
        self.assertEqual(decrypt_user_key(wrapped, pad_kek_for_fernet(kek_raw)), user_key)


class KEKMixinTestBase(TestCase):
    """Shared fixtures: a KEK user and a helper to build requests carrying X-KEK."""

    def setUp(self):
        self.factory = RequestFactory()
        self.mixin = KEKAuthenticationMixin()
        self.user, self.kek_header, self.user_key = make_kek_user()

    def _request(self, with_kek=True, user=None):
        headers = {'HTTP_X_KEK': self.kek_header} if with_kek else {}
        request = self.factory.get('/', **headers)
        request.user = user or self.user
        return request


class GetKekTests(KEKMixinTestBase):
    def test_get_kek_decodes_header(self):
        request = self._request()
        self.assertEqual(self.mixin.get_kek(request), base64.b64decode(self.kek_header))

    def test_get_kek_missing_header_returns_none(self):
        self.assertIsNone(self.mixin.get_kek(self._request(with_kek=False)))

    def test_get_kek_invalid_base64_returns_none(self):
        request = self.factory.get('/', HTTP_X_KEK='!!!not base64!!!')
        request.user = self.user
        self.assertIsNone(self.mixin.get_kek(request))

    def test_require_kek_raises_without_header(self):
        with self.assertRaises(PermissionDenied):
            self.mixin.require_kek(self._request(with_kek=False))


class GetUserKeyTests(KEKMixinTestBase):
    def test_get_user_key_returns_correct_key(self):
        self.assertEqual(self.mixin.get_user_key(self._request()), self.user_key)

    def test_get_user_key_without_kek_raises(self):
        with self.assertRaises(PermissionDenied):
            self.mixin.get_user_key(self._request(with_kek=False))

    def test_get_user_key_without_setup_raises(self):
        self.user.profile.encrypted_user_key = None
        self.user.profile.save()
        with self.assertRaises(PermissionDenied):
            self.mixin.get_user_key(self._request())

    def test_get_user_key_wrong_kek_raises_permission_denied(self):
        bad_kek = base64.b64encode(os.urandom(32)).decode()
        request = self.factory.get('/', HTTP_X_KEK=bad_kek)
        request.user = self.user
        with self.assertRaises(PermissionDenied):
            self.mixin.get_user_key(request)


class BlobAndCredentialTests(KEKMixinTestBase):
    def test_encrypt_decrypt_blob_roundtrip(self):
        request = self._request()
        data = {'keyring_pem': 'abc', 'keyring_passphrase': 'xyz'}
        encrypted = self.mixin.encrypt_blob(request, data)
        self.assertIsInstance(encrypted, bytes)
        self.assertEqual(self.mixin.decrypt_blob(request, encrypted), data)

    def test_decrypt_account_credentials(self):
        # Encrypt with the raw user key the same way the app stores them.
        blob = encrypt_credentials({'username': 'u', 'password': 'p'}, self.user_key)
        broker = Broker.objects.create(code='viac', name='VIAC', integration_type='rest')
        account = FinancialAccount.objects.create(
            user=self.user, broker=broker, name='acct', encrypted_credentials=blob,
        )
        result = self.mixin.decrypt_account_credentials(self._request(), account)
        self.assertEqual(result, {'username': 'u', 'password': 'p'})

    def test_encrypt_account_credentials_roundtrips_through_decrypt(self):
        request = self._request()
        encrypted = self.mixin.encrypt_account_credentials(request, {'pin': '9999'})
        self.assertEqual(decrypt_credentials(encrypted, self.user_key), {'pin': '9999'})

    def test_decrypt_blob_without_kek_raises(self):
        blob = self.mixin.encrypt_blob(self._request(), {'a': 1})
        with self.assertRaises(PermissionDenied):
            self.mixin.decrypt_blob(self._request(with_kek=False), blob)


class DecryptSyncCredentialsTests(KEKMixinTestBase):
    def setUp(self):
        super().setUp()
        self.rest_broker = Broker.objects.create(
            code='viac', name='VIAC', integration_type='rest',
        )
        self.ebics_broker = Broker.objects.create(
            code='zkb', name='ZKB', integration_type='ebics',
        )

    def test_normal_account_uses_encrypted_credentials(self):
        blob = encrypt_credentials({'username': 'u', 'password': 'p'}, self.user_key)
        account = FinancialAccount.objects.create(
            user=self.user, broker=self.rest_broker, name='viac',
            encrypted_credentials=blob,
        )
        self.assertEqual(
            self.mixin.decrypt_sync_credentials(self._request(), account),
            {'username': 'u', 'password': 'p'},
        )

    def _make_ebics_account(self, subscriber_id='SUB99'):
        request = self._request()
        keyring_blob = {'keyring_pem': 'cGVt', 'keyring_passphrase': 'topsecret'}
        cred = EbicsCredential.objects.create(
            user=self.user, broker=self.ebics_broker, label='ZKB',
            host_id='ZKBKCHZZ', partner_id='PARTNER1', subscriber_id=subscriber_id,
            url='https://ebics.zkb.ch/ebics', bank_hash_auth='aa', bank_hash_enc='bb',
            encrypted_keyring=self.mixin.encrypt_blob(request, keyring_blob),
        )
        account = FinancialAccount.objects.create(
            user=self.user, broker=self.ebics_broker, name='ZKB checking',
            account_identifier='CH00', ebics_credential=cred,
        )
        return cred, account

    def test_ebics_account_pulls_from_linked_credential(self):
        cred, account = self._make_ebics_account()
        result = self.mixin.decrypt_sync_credentials(self._request(), account)
        self.assertEqual(result['host_id'], 'ZKBKCHZZ')
        self.assertEqual(result['partner_id'], 'PARTNER1')
        self.assertEqual(result['url'], 'https://ebics.zkb.ch/ebics')
        self.assertEqual(result['bank_hash_auth'], 'aa')
        self.assertEqual(result['bank_hash_enc'], 'bb')
        self.assertEqual(result['keyring_pem'], 'cGVt')
        self.assertEqual(result['keyring_passphrase'], 'topsecret')

    def test_ebics_user_id_maps_to_subscriber_id_not_user_fk(self):
        """The regression the app comments warn about: user_id is subscriber_id."""
        cred, account = self._make_ebics_account(subscriber_id='TEILNEHMER-7')
        result = self.mixin.decrypt_sync_credentials(self._request(), account)
        self.assertEqual(result['user_id'], 'TEILNEHMER-7')
        self.assertEqual(result['user_id'], cred.subscriber_id)
        # Must NOT be the Django user FK's integer PK.
        self.assertNotEqual(result['user_id'], cred.user_id)
        self.assertNotEqual(result['user_id'], str(cred.user_id))

    def test_ebics_account_without_keyring_raises(self):
        cred = EbicsCredential.objects.create(
            user=self.user, broker=self.ebics_broker, label='ZKB',
            host_id='ZKBKCHZZ', partner_id='P', subscriber_id='S',
            url='https://ebics.zkb.ch/ebics', encrypted_keyring=None,
        )
        account = FinancialAccount.objects.create(
            user=self.user, broker=self.ebics_broker, name='ZKB',
            ebics_credential=cred,
        )
        with self.assertRaises(PermissionDenied):
            self.mixin.decrypt_sync_credentials(self._request(), account)
