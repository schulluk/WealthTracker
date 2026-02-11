"""
KEK Authentication Mixin for handling per-user encryption.

This mixin extracts the KEK from request headers and provides
methods for decrypting user credentials.
"""
import base64
import logging

from rest_framework.exceptions import PermissionDenied

from .encryption import decrypt_credentials as legacy_decrypt_credentials
from .encryption import encrypt_credentials as legacy_encrypt_credentials
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

    def decrypt_account_credentials(self, request, account) -> dict:
        """
        Decrypt credentials for a specific account.

        Supports both legacy (server-key) and new (per-user KEK) encryption.

        Args:
            request: The HTTP request (to extract KEK header)
            account: The Account object with encrypted_credentials

        Returns:
            Decrypted credentials dictionary

        Raises:
            PermissionDenied: If decryption fails or KEK is required but missing
        """
        user = request.user
        profile = user.profile

        # Check if user has migrated to per-user encryption
        if profile.encryption_migrated:
            kek = self.get_kek(request)
            if not kek:
                raise PermissionDenied("KEK required for encrypted operations")

            if not profile.encrypted_user_key:
                raise PermissionDenied("User encryption not set up")

            try:
                # Ensure KEK is properly formatted for Fernet
                kek = pad_kek_for_fernet(kek)
                user_key = decrypt_user_key(profile.encrypted_user_key, kek)
                return decrypt_credentials(account.encrypted_credentials, user_key)
            except Exception as e:
                logger.warning(f"Failed to decrypt credentials for user {user.id}: {e}")
                raise PermissionDenied("Failed to decrypt credentials")
        else:
            # Legacy decryption using server-side key
            return legacy_decrypt_credentials(account.encrypted_credentials)

    def require_kek_for_migrated_user(self, request):
        """
        Check that KEK is present for migrated users.

        Call this at the start of views that need to decrypt credentials.

        Raises:
            PermissionDenied: If user is migrated but KEK is missing
        """
        profile = request.user.profile
        if profile.encryption_migrated:
            kek = self.get_kek(request)
            if not kek:
                raise PermissionDenied("KEK required for encrypted operations")

    def encrypt_account_credentials(self, request, credentials: dict) -> bytes:
        """
        Encrypt credentials for storage.

        Supports both legacy (server-key) and new (per-user KEK) encryption.

        Args:
            request: The HTTP request (to extract KEK header and user)
            credentials: Dictionary of credentials to encrypt

        Returns:
            Encrypted credentials bytes

        Raises:
            PermissionDenied: If encryption fails or KEK is required but missing
        """
        user = request.user
        profile = user.profile

        if profile.encryption_migrated:
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
        else:
            # Legacy encryption using server-side key
            return legacy_encrypt_credentials(credentials)
