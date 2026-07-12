"""
KEK Authentication Mixin for handling per-user encryption.

This mixin extracts the KEK from request headers and provides
methods for decrypting user credentials.
"""
import base64
import logging

from rest_framework.exceptions import PermissionDenied

from .user_encryption import (
    decrypt_credentials,
    decrypt_user_key,
    encrypt_credentials,
    pad_kek_for_fernet,
)

logger = logging.getLogger(__name__)


class KEKAuthenticationMixin:
    """Mixin to extract and validate KEK from request."""

    def get_kek(self, request) -> bytes | None:
        """
        Extract KEK from request header.

        The KEK is sent in the X-KEK header, base64-encoded.

        Returns:
            KEK bytes or None if not present
        """
        kek_header = request.META.get('HTTP_X_KEK')
        if not kek_header:
            return None
        try:
            return base64.b64decode(kek_header)
        except Exception:
            logger.warning("Failed to decode KEK header")
            return None

    def get_user_key(self, request) -> bytes:
        """
        Derive the per-user Fernet key by unwrapping it with the request's KEK.

        This is the single choke point every encrypted operation goes through.

        Raises:
            PermissionDenied: If the KEK is missing or unwrapping fails.
        """
        profile = request.user.profile

        kek = self.get_kek(request)
        if not kek:
            raise PermissionDenied("KEK required for encrypted operations")
        if not profile.encrypted_user_key:
            raise PermissionDenied("User encryption not set up")

        try:
            kek = pad_kek_for_fernet(kek)
            return decrypt_user_key(profile.encrypted_user_key, kek)
        except Exception as e:
            logger.warning(f"Failed to unwrap user key for user {request.user.id}: {e}")
            raise PermissionDenied("Failed to decrypt credentials")

    def decrypt_account_credentials(self, request, account) -> dict:
        """
        Decrypt credentials for a specific account.

        Args:
            request: The HTTP request (to extract KEK header)
            account: The Account object with encrypted_credentials

        Returns:
            Decrypted credentials dictionary

        Raises:
            PermissionDenied: If decryption fails or KEK is missing
        """
        try:
            return decrypt_credentials(account.encrypted_credentials, self.get_user_key(request))
        except PermissionDenied:
            raise
        except Exception as e:
            logger.warning(f"Failed to decrypt credentials for user {request.user.id}: {e}")
            raise PermissionDenied("Failed to decrypt credentials")

    def decrypt_blob(self, request, encrypted) -> dict:
        """Decrypt an arbitrary Fernet-under-KEK blob (e.g. an EBICS keyring)."""
        try:
            return decrypt_credentials(encrypted, self.get_user_key(request))
        except PermissionDenied:
            raise
        except Exception as e:
            logger.warning(f"Failed to decrypt blob for user {request.user.id}: {e}")
            raise PermissionDenied("Failed to decrypt credentials")

    def encrypt_blob(self, request, data: dict) -> bytes:
        """Encrypt an arbitrary dict under the same Fernet-under-KEK scheme."""
        try:
            return encrypt_credentials(data, self.get_user_key(request))
        except PermissionDenied:
            raise
        except Exception as e:
            logger.warning(f"Failed to encrypt blob for user {request.user.id}: {e}")
            raise PermissionDenied("Failed to encrypt credentials")

    def decrypt_sync_credentials(self, request, account) -> dict:
        """
        Return the credentials dict a sync needs, for either credential model.

        For EBICS accounts the secret keyring lives on the shared
        ``account.ebics_credential`` (not ``account.encrypted_credentials``); it is
        decrypted with the same per-user key and merged with the connection
        parameters the integration expects.
        """
        cred = account.ebics_credential
        if cred is not None:
            if not cred.encrypted_keyring:
                raise PermissionDenied("EBICS credential is not initialized")
            blob = self.decrypt_blob(request, cred.encrypted_keyring)
            return {
                'host_id': cred.host_id,
                'partner_id': cred.partner_id,
                'user_id': cred.subscriber_id,
                'url': cred.url,
                'bank_hash_auth': cred.bank_hash_auth,
                'bank_hash_enc': cred.bank_hash_enc,
                'keyring_pem': blob.get('keyring_pem'),
                'keyring_passphrase': blob.get('keyring_passphrase'),
            }
        return self.decrypt_account_credentials(request, account)

    def require_kek(self, request):
        """
        Check that KEK is present.

        Call this at the start of views that need to decrypt credentials.

        Raises:
            PermissionDenied: If KEK is missing
        """
        kek = self.get_kek(request)
        if not kek:
            raise PermissionDenied("KEK required for encrypted operations")

    def encrypt_account_credentials(self, request, credentials: dict) -> bytes:
        """
        Encrypt credentials for storage.

        Args:
            request: The HTTP request (to extract KEK header and user)
            credentials: Dictionary of credentials to encrypt

        Returns:
            Encrypted credentials bytes

        Raises:
            PermissionDenied: If encryption fails or KEK is missing
        """
        user = request.user
        profile = user.profile

        kek = self.get_kek(request)
        if not kek:
            raise PermissionDenied("KEK required for encrypted operations")

        if not profile.encrypted_user_key:
            raise PermissionDenied("User encryption not set up")

        try:
            kek = pad_kek_for_fernet(kek)
            user_key = decrypt_user_key(profile.encrypted_user_key, kek)
            return encrypt_credentials(credentials, user_key)
        except Exception as e:
            logger.warning(f"Failed to encrypt credentials for user {user.id}: {e}")
            raise PermissionDenied("Failed to encrypt credentials")
