from django.contrib.auth.models import User
from django.db import models


class Broker(models.Model):
    """Pre-defined list of supported brokers/financial institutions."""

    INTEGRATION_TYPES = [
        ('fints', 'FinTS Protocol'),
        ('rest', 'REST API'),
        ('graphql', 'GraphQL API'),
        ('ebics', 'EBICS Protocol'),
    ]

    code = models.CharField(
        max_length=50,
        unique=True,
        help_text='Internal broker identifier (e.g., dkb, commerzbank)'
    )
    name = models.CharField(max_length=100)
    integration_type = models.CharField(
        max_length=20,
        choices=INTEGRATION_TYPES
    )

    # FinTS-specific fields
    bank_identifier = models.CharField(
        max_length=20,
        blank=True,
        help_text='BLZ for German banks'
    )
    fints_server = models.URLField(
        blank=True,
        help_text='FinTS server URL'
    )

    # API-specific fields
    api_base_url = models.URLField(
        blank=True,
        help_text='Base URL for REST/GraphQL APIs'
    )

    # Metadata
    logo_url = models.URLField(blank=True)
    website_url = models.URLField(blank=True)
    country = models.CharField(max_length=2, default='DE')
    is_active = models.BooleanField(default=True)
    supports_2fa = models.BooleanField(default=False)
    supports_auto_sync = models.BooleanField(
        default=False,
        help_text='Whether accounts can be synced automatically without user interaction (e.g., decoupled TAN)'
    )

    # JSON schema defining required credentials
    credential_schema = models.JSONField(
        default=dict,
        help_text='JSON schema defining required credential fields'
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'brokers'
        ordering = ['name']

    def __str__(self):
        return self.name


class EbicsCredential(models.Model):
    """A subscriber's EBICS credentials at one bank, shared across accounts.

    EBICS access is subscriber-level, not account-level: one key exchange (one
    hand-signed initialisation letter) activates a ``partner_id``/``user_id`` at
    the bank, which can then read *all* of that subscriber's accounts. So the
    keyring lives here once and individual :class:`~portfolio.models.FinancialAccount`
    rows (by IBAN) point at it.

    Security bar matches the rest of the app: the RSA keyring (the only real
    secret) is stored in ``encrypted_keyring`` using the same Fernet-under-KEK
    scheme as ``FinancialAccount.encrypted_credentials`` — the server cannot
    decrypt it at rest without the client-derived KEK. Connection identifiers and
    the bank-key pinning hashes are non-secret (analogous to a plaintext IBAN /
    broker URL) and kept as columns so the credential can be listed without a KEK.
    """

    STATE_CHOICES = [
        ('new', 'New — keys generated, not yet sent'),
        ('keys_sent', 'Keys sent — awaiting bank activation'),
        ('active', 'Active'),
        ('error', 'Error'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='ebics_credentials',
    )
    broker = models.ForeignKey(
        Broker,
        on_delete=models.PROTECT,
        related_name='ebics_credentials',
    )
    label = models.CharField(
        max_length=100,
        help_text='User-friendly name, e.g. "ZKB DataLink"',
    )

    # Connection parameters (from the bank's Bankparameterdaten letter). Not secret.
    host_id = models.CharField(max_length=64, help_text='EBICS Host ID (e.g. ZKBKCHZZ)')
    partner_id = models.CharField(max_length=64, help_text='Partner/Customer ID (Kunden-ID)')
    # EBICS "User ID" (Teilnehmer-ID). Named subscriber_id to avoid clashing with
    # the `user` FK's automatic `user_id` attribute.
    subscriber_id = models.CharField(max_length=64, help_text='EBICS User/Subscriber ID (Teilnehmer-ID)')
    url = models.URLField(help_text='EBICS endpoint URL')

    # Bank public-key pinning hashes from the letter (SHA-256, hex). Integrity anchor,
    # verified on every HPB. Not secret (they are printed on the paper letter).
    bank_hash_auth = models.CharField(
        max_length=128, blank=True,
        help_text='Expected SHA-256 hash of the bank authentication (X002) key, hex',
    )
    bank_hash_enc = models.CharField(
        max_length=128, blank=True,
        help_text='Expected SHA-256 hash of the bank encryption (E002) key, hex',
    )

    # The crown jewel: Fernet-under-KEK encrypted JSON holding the serialised
    # ebicsclient keyring plus its passphrase. Same encryption path as credentials.
    encrypted_keyring = models.BinaryField(null=True, blank=True)

    state = models.CharField(max_length=20, choices=STATE_CHOICES, default='new')
    last_error = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'ebics_credentials'
        ordering = ['label']
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'host_id', 'partner_id', 'subscriber_id'],
                name='unique_ebics_subscriber_per_user',
            ),
        ]

    def __str__(self):
        return f"{self.label} ({self.host_id}/{self.partner_id})"
