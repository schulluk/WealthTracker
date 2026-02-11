from django.contrib.auth.models import User
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver


class UserProfile(models.Model):
    """Extended user profile with wealth tracking preferences."""

    CURRENCY_CHOICES = [
        ('EUR', 'Euro'),
        ('USD', 'US Dollar'),
        ('CHF', 'Swiss Franc'),
        ('GBP', 'British Pound'),
    ]

    CHART_RANGE_CHOICES = [
        (30, '30 days'),
        (90, '90 days'),
        (180, '6 months'),
        (365, '1 year'),
        (730, '2 years'),
        (3650, 'All'),
    ]

    CHART_GRANULARITY_CHOICES = [
        ('daily', 'Daily'),
        ('monthly', 'Monthly'),
    ]

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile'
    )
    base_currency = models.CharField(
        max_length=3,
        choices=CURRENCY_CHOICES,
        default='EUR',
        help_text='Default currency for displaying aggregated wealth'
    )
    auto_sync_enabled = models.BooleanField(default=True)
    last_sync_at = models.DateTimeField(null=True, blank=True)
    # Email report settings
    send_weekly_report = models.BooleanField(
        default=False,
        help_text='Send weekly wealth summary email on Mondays'
    )
    # Chart display preferences
    default_chart_range = models.IntegerField(
        choices=CHART_RANGE_CHOICES,
        default=365,
        help_text='Default time range for wealth chart'
    )
    default_chart_granularity = models.CharField(
        max_length=10,
        choices=CHART_GRANULARITY_CHOICES,
        default='daily',
        help_text='Default granularity for wealth chart'
    )

    # KEK-based encryption fields
    encrypted_user_key = models.BinaryField(
        null=True,
        blank=True,
        help_text='Per-user encryption key, encrypted with KEK derived from password'
    )
    auth_salt = models.CharField(
        max_length=32,
        blank=True,
        help_text='Salt for authentication hash (base64, 16 bytes)'
    )
    auth_hash = models.CharField(
        max_length=128,
        blank=True,
        help_text='Client-derived authentication hash'
    )
    kek_salt = models.CharField(
        max_length=32,
        blank=True,
        help_text='Salt for KEK derivation (base64, 16 bytes)'
    )
    key_version = models.PositiveIntegerField(
        default=1,
        help_text='Key version for rotation support'
    )
    encryption_migrated = models.BooleanField(
        default=False,
        help_text='Whether user has migrated to per-user encryption'
    )

    # Sync reminder settings
    sync_reminder_enabled = models.BooleanField(
        default=True,
        help_text='Enable daily sync reminder notification'
    )
    sync_reminder_hour = models.PositiveSmallIntegerField(
        default=9,
        help_text='Hour for sync reminder (0-23)'
    )
    sync_reminder_minute = models.PositiveSmallIntegerField(
        default=0,
        help_text='Minute for sync reminder (0-59)'
    )
    sync_on_app_open = models.BooleanField(
        default=False,
        help_text='Automatically sync when opening app'
    )

    # Demo mode flag
    is_demo_user = models.BooleanField(
        default=False,
        help_text='Demo user created by generate_demo_data command'
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'user_profiles'

    def __str__(self):
        return f"{self.user.username}'s Profile ({self.base_currency})"


@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Automatically create a profile when a user is created."""
    if created:
        UserProfile.objects.create(user=instance)
