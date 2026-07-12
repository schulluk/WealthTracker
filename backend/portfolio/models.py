from django.contrib.auth.models import User
from django.db import models

from brokers.models import Broker


class FinancialAccount(models.Model):
    """User's account at a specific broker."""

    ACCOUNT_TYPES = [
        ('checking', 'Checking Account'),
        ('savings', 'Savings Account'),
        ('brokerage', 'Brokerage/Investment Account'),
        ('retirement', 'Retirement Account'),
        ('crypto', 'Cryptocurrency Account'),
        ('other', 'Other'),
    ]

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('error', 'Sync Error'),
        ('pending_auth', 'Pending Authentication'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='financial_accounts'
    )
    broker = models.ForeignKey(
        Broker,
        on_delete=models.PROTECT,
        related_name='accounts'
    )
    # For EBICS brokers (e.g. ZKB): the shared subscriber credential this account
    # is read through. Its keyring — not this account's encrypted_credentials — is
    # used to sync. One credential serves many accounts (by IBAN).
    ebics_credential = models.ForeignKey(
        'brokers.EbicsCredential',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='accounts',
    )

    name = models.CharField(
        max_length=100,
        help_text='User-defined account name'
    )
    account_identifier = models.CharField(
        max_length=100,
        blank=True,
        help_text='IBAN, account number, or external ID'
    )
    account_type = models.CharField(
        max_length=20,
        choices=ACCOUNT_TYPES,
        default='checking'
    )
    currency = models.CharField(
        max_length=3,
        default='EUR',
        help_text='Native currency of the account'
    )

    # Encrypted credentials (binary field for Fernet encryption)
    encrypted_credentials = models.BinaryField(
        null=True,
        blank=True
    )

    # For manual accounts without API access
    is_manual = models.BooleanField(
        default=False,
        help_text='Manual account without automated sync'
    )

    # Sync status
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending_auth'
    )
    last_sync_at = models.DateTimeField(null=True, blank=True)
    last_sync_error = models.TextField(blank=True)
    sync_enabled = models.BooleanField(default=True)

    # Temporary state for multi-step auth flows
    pending_auth_state = models.JSONField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'financial_accounts'
        ordering = ['broker__name', 'name']

    def __str__(self):
        return f"{self.name} ({self.broker.name})"

    @property
    def latest_snapshot(self):
        """Get the most recent balance snapshot."""
        return self.snapshots.order_by('-snapshot_date', '-created_at').first()


class AccountSnapshot(models.Model):
    """Historical balance record for an account."""

    SNAPSHOT_SOURCES = [
        ('auto', 'Automatic Sync'),
        ('manual', 'Manual Entry'),
        ('import', 'Data Import'),
    ]

    account = models.ForeignKey(
        FinancialAccount,
        on_delete=models.CASCADE,
        related_name='snapshots'
    )

    # Balance information
    balance = models.DecimalField(
        max_digits=20,
        decimal_places=4,
        help_text='Account balance in native currency'
    )
    currency = models.CharField(
        max_length=3,
        help_text='Currency of the balance'
    )

    # Converted balance for quick aggregation
    balance_base_currency = models.DecimalField(
        max_digits=20,
        decimal_places=4,
        null=True,
        blank=True,
        help_text='Balance converted to user base currency'
    )
    base_currency = models.CharField(
        max_length=3,
        blank=True,
        help_text='User base currency at time of snapshot'
    )
    exchange_rate_used = models.DecimalField(
        max_digits=20,
        decimal_places=10,
        null=True,
        blank=True
    )

    # Snapshot metadata
    snapshot_date = models.DateField(
        help_text='Date the balance was valid for'
    )
    snapshot_source = models.CharField(
        max_length=20,
        choices=SNAPSHOT_SOURCES,
        default='auto'
    )

    # Raw response data from broker
    raw_data = models.JSONField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'account_snapshots'
        ordering = ['-snapshot_date', '-created_at']
        indexes = [
            models.Index(fields=['account', 'snapshot_date']),
            models.Index(fields=['snapshot_date']),
        ]

    def __str__(self):
        return f"{self.account.name} - {self.balance} {self.currency} ({self.snapshot_date})"


class PortfolioPosition(models.Model):
    """Individual holdings within an investment account."""

    ASSET_CLASSES = [
        ('equity', 'Equity/Stocks'),
        ('fixed_income', 'Fixed Income/Bonds'),
        ('cash', 'Cash & Equivalents'),
        ('real_estate', 'Real Estate'),
        ('commodity', 'Commodities'),
        ('crypto', 'Cryptocurrency'),
        ('other', 'Other'),
    ]

    snapshot = models.ForeignKey(
        AccountSnapshot,
        on_delete=models.CASCADE,
        related_name='positions'
    )

    # Security identification
    symbol = models.CharField(max_length=20, blank=True)
    isin = models.CharField(max_length=12, blank=True)
    name = models.CharField(max_length=200)

    # Position details
    quantity = models.DecimalField(max_digits=20, decimal_places=8)
    price_per_unit = models.DecimalField(max_digits=20, decimal_places=4)
    market_value = models.DecimalField(max_digits=20, decimal_places=4)
    currency = models.CharField(max_length=3)

    # Cost basis if available
    cost_basis = models.DecimalField(
        max_digits=20,
        decimal_places=4,
        null=True,
        blank=True
    )

    asset_class = models.CharField(
        max_length=50,
        choices=ASSET_CLASSES,
        default='other'
    )

    class Meta:
        db_table = 'portfolio_positions'

    def __str__(self):
        return f"{self.name}: {self.quantity} @ {self.price_per_unit}"
