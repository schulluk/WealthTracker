"""
Per-user encryption module for KEK-based credential security.

This module provides functions for:
- Generating salts for key derivation
- Generating and encrypting user keys
- Encrypting/decrypting credentials with user keys

Note: Key derivation (Argon2id) happens CLIENT-SIDE.
The server only receives the derived KEK, never the password.
"""
import base64
import json
import os

from cryptography.fernet import Fernet


def generate_salt() -> str:
    """Generate a 16-byte salt, base64 encoded."""
    return base64.b64encode(os.urandom(16)).decode()


def generate_user_key() -> bytes:
    """Generate a new random user encryption key."""
    return Fernet.generate_key()


def encrypt_user_key(user_key: bytes, kek: bytes) -> bytes:
    """
    Encrypt user key with KEK.

    Args:
        user_key: The user's encryption key (Fernet key)
        kek: Key Encryption Key derived from password (must be 32 bytes, base64url-encoded)

    Returns:
        Encrypted user key bytes
    """
    f = Fernet(kek)
    return f.encrypt(user_key)


def decrypt_user_key(encrypted_user_key: bytes, kek: bytes) -> bytes:
    """
    Decrypt user key with KEK.

    Args:
        encrypted_user_key: The encrypted user key
        kek: Key Encryption Key derived from password

    Returns:
        Decrypted user key (Fernet key)
    """
    # Handle memoryview from Django BinaryField
    if isinstance(encrypted_user_key, memoryview):
        encrypted_user_key = bytes(encrypted_user_key)
    f = Fernet(kek)
    return f.decrypt(encrypted_user_key)


def encrypt_credentials(credentials: dict, user_key: bytes) -> bytes:
    """
    Encrypt credentials with user key.

    Args:
        credentials: Dictionary of credentials to encrypt
        user_key: The user's Fernet encryption key

    Returns:
        Encrypted credentials bytes
    """
    f = Fernet(user_key)
    return f.encrypt(json.dumps(credentials).encode())


def decrypt_credentials(encrypted_creds: bytes, user_key: bytes) -> dict:
    """
    Decrypt credentials with user key.

    Args:
        encrypted_creds: Encrypted credentials bytes
        user_key: The user's Fernet encryption key

    Returns:
        Decrypted credentials dictionary
    """
    if not encrypted_creds:
        return {}
    # Handle memoryview from Django BinaryField
    if isinstance(encrypted_creds, memoryview):
        encrypted_creds = bytes(encrypted_creds)
    f = Fernet(user_key)
    return json.loads(f.decrypt(encrypted_creds).decode())


def pad_kek_for_fernet(kek_bytes: bytes) -> bytes:
    """
    Ensure KEK is properly formatted for Fernet (32 bytes, base64url-encoded).

    Argon2 output is raw bytes. Fernet requires a 32-byte key that's
    base64url-encoded (44 characters with padding).

    Args:
        kek_bytes: Raw 32-byte KEK from Argon2

    Returns:
        Base64url-encoded key suitable for Fernet
    """
    if len(kek_bytes) == 44:
        # Already base64-encoded
        return kek_bytes
    if len(kek_bytes) == 32:
        # Raw bytes, need to encode
        return base64.urlsafe_b64encode(kek_bytes)
    raise ValueError(f"KEK must be 32 bytes (raw) or 44 bytes (base64), got {len(kek_bytes)}")
