"""Shared helpers for tests that need a KEK-enabled user.

Named without a ``test`` prefix so Django's test discovery does not try to load
it as a test module.
"""
import base64
import os

from django.contrib.auth.models import User

from core.user_encryption import (
    encrypt_user_key,
    generate_user_key,
    pad_kek_for_fernet,
)


def make_kek_user(username='alice', password='pw-abc-12345', base_currency='CHF'):
    """Create a User whose profile has an encrypted_user_key wrapped under a test KEK.

    Returns ``(user, kek_header, user_key)`` where ``kek_header`` is the exact
    base64 string to send in the ``X-KEK`` request header (mirrors
    ``core.kek_auth.KEKAuthenticationMixin.get_kek``) and ``user_key`` is the
    raw Fernet user key so a test can encrypt fixtures the same way the app does.
    """
    user = User.objects.create_user(username=username, password=password)

    kek_raw = os.urandom(32)
    fernet_kek = pad_kek_for_fernet(kek_raw)
    user_key = generate_user_key()

    profile = user.profile
    profile.encrypted_user_key = encrypt_user_key(user_key, fernet_kek)
    profile.base_currency = base_currency
    profile.save()

    kek_header = base64.b64encode(kek_raw).decode()
    return user, kek_header, user_key
