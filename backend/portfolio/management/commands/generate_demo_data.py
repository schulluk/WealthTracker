"""
Management command to generate demo data for testing and demonstration.

Creates users with sample accounts and historical balance snapshots.
Designed to be run daily to keep demo data fresh.

IMPORTANT: This command deletes and recreates demo users on each run.
Only users marked as demo users (is_demo_user=True) will be deleted.
If a username belongs to a real user, the command will fail.

Usage:
    python manage.py generate_demo_data --users demo1:password1 demo2:password2

Environment variable alternative:
    DEMO_USERS=demo1:password1,demo2:password2
    python manage.py generate_demo_data
"""
import logging
import os
import random
from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from accounts.models import UserProfile
from brokers.models import Broker
from core.user_encryption import (
    encrypt_user_key,
    generate_salt,
    generate_user_key,
    pad_kek_for_fernet,
)
from portfolio.models import AccountSnapshot, FinancialAccount

logger = logging.getLogger(__name__)

# Demo account configurations
# (name, broker_code, account_type, currency, is_manual, days_offset_for_newest)
DEMO_ACCOUNTS = [
    ('DKB Girokonto', 'dkb', 'checking', 'EUR', False, 0),        # today
    ('Interactive Brokers', 'ibkr', 'brokerage', 'USD', False, 0),  # today
    ('Commerzbank Tagesgeld', 'commerzbank', 'savings', 'EUR', False, 1),  # yesterday
    ('VIAC 3a', 'viac', 'retirement', 'CHF', False, 1),           # yesterday
    ('Cash Reserve', 'manual', 'savings', 'EUR', True, 4),        # 4 days ago
]

# Starting balance
STARTING_BALANCE = Decimal('147826.0000')

# Growth/decrease parameters
GROWTH_RATE_MIN = Decimal('0.03')   # 3%
GROWTH_RATE_MAX = Decimal('0.10')   # 10%
DECREASE_RATE_MIN = Decimal('0.02')  # 2%
DECREASE_RATE_MAX = Decimal('0.08')  # 8%

# Probability of growth in a month (applied per 4 snapshots since ~20 days)
GROWTH_PROBABILITY = 0.60

# Snapshots configuration
SNAPSHOT_INTERVAL_DAYS = 5
HISTORY_DAYS = int(365 * 2.5)  # 2.5 years


class Command(BaseCommand):
    help = 'Generate demo data with sample accounts and historical snapshots'

    def add_arguments(self, parser):
        parser.add_argument(
            '--users',
            nargs='*',
            help='List of username:password pairs (e.g., demo1:pass1 demo2:pass2)',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be created without making changes',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']

        # Get user credentials from args or environment
        user_pairs = options.get('users') or []

        if not user_pairs:
            # Try environment variable
            env_users = os.environ.get('DEMO_USERS', '')
            if env_users:
                user_pairs = env_users.split(',')

        if not user_pairs:
            logger.error(
                'No users specified. Use --users or set DEMO_USERS env var.\n'
                'Example: --users demo1:password1 demo2:password2'
            )
            return

        # Parse user credentials
        users_to_create = []
        for number, pair in enumerate(user_pairs, start=1):
            if ':' not in pair:
                # not the entry itself: it may be a password
                logger.error('Invalid user entry #%d: expected username:password', number)
                return
            username, password = pair.split(':', 1)
            users_to_create.append((username.strip(), password.strip()))

        logger.info('Processing %d demo users...', len(users_to_create))

        if dry_run:
            logger.warning('DRY RUN - no changes will be made')

        # First, validate that all usernames are either new or demo users
        self._validate_usernames([u[0] for u in users_to_create], dry_run)

        # Delete existing demo users and their data
        self._delete_demo_users([u[0] for u in users_to_create], dry_run)

        # Create new demo users
        for username, password in users_to_create:
            self._create_demo_user(username, password, dry_run)

        logger.info('Demo data generation complete')

    def _validate_usernames(self, usernames, dry_run):
        """
        Validate that all usernames are either new or belong to demo users.

        Raises CommandError if any username belongs to a real (non-demo) user.
        """
        for username in usernames:
            try:
                user = User.objects.get(username=username)
                profile = getattr(user, 'profile', None)

                if profile and not profile.is_demo_user:
                    raise CommandError(
                        f'User "{username}" exists and is NOT a demo user. '
                        f'Cannot overwrite real user data. '
                        f'Use a different username or manually delete this user.'
                    )
            except User.DoesNotExist:
                # New user, OK to create
                pass

        if not dry_run:
            logger.debug('All usernames validated')

    def _delete_demo_users(self, usernames, dry_run):
        """Delete demo users and all their associated data."""
        for username in usernames:
            try:
                user = User.objects.get(username=username)
                profile = getattr(user, 'profile', None)

                if profile and profile.is_demo_user:
                    if dry_run:
                        account_count = FinancialAccount.objects.filter(user=user).count()
                        logger.info(
                            'Would delete demo user "%s" with %d accounts', username, account_count
                        )
                    else:
                        # Delete cascades to accounts and snapshots
                        user.delete()
                        logger.info('Deleted demo user: %s', username)
            except User.DoesNotExist:
                pass

    @transaction.atomic
    def _create_demo_user(self, username, password, dry_run):
        """Create a demo user with accounts and snapshots."""
        logger.info('Creating demo user: %s', username)

        if dry_run:
            logger.info('Would create user %s with 5 demo accounts', username)
            return

        # Create user
        user = User.objects.create_user(
            username=username,
            email=f'{username}@demo.local',
            password=password
        )
        logger.debug('Created user: %s', username)

        # Get or create profile and mark as demo user
        profile, _ = UserProfile.objects.get_or_create(user=user)
        profile.base_currency = 'EUR'
        profile.auto_sync_enabled = False
        profile.is_demo_user = True

        # Set up encryption for the user
        self._setup_user_encryption(profile, password)
        profile.save()

        # Create demo accounts
        self._create_demo_accounts(user, profile)

        # Create demo transactions with categories, rules and a transfer pair
        self._create_demo_transactions(user)

    def _setup_user_encryption(self, profile, password):
        """Set up per-user encryption for a demo user."""
        from argon2.low_level import Type, hash_secret_raw
        import base64

        # Generate salts
        auth_salt = generate_salt()
        kek_salt = generate_salt()

        # Derive KEK from password (matching client-side derivation)
        kek_raw = hash_secret_raw(
            secret=password.encode(),
            salt=base64.b64decode(kek_salt),
            time_cost=3,
            memory_cost=65536,
            parallelism=4,
            hash_len=32,
            type=Type.ID
        )
        kek = pad_kek_for_fernet(kek_raw)

        # Derive auth_hash
        auth_hash_raw = hash_secret_raw(
            secret=password.encode(),
            salt=base64.b64decode(auth_salt),
            time_cost=3,
            memory_cost=65536,
            parallelism=4,
            hash_len=32,
            type=Type.ID
        )
        auth_hash = base64.b64encode(auth_hash_raw).decode()

        # Generate and encrypt user key
        user_key = generate_user_key()
        encrypted_user_key = encrypt_user_key(user_key, kek)

        # Update profile
        profile.auth_salt = auth_salt
        profile.kek_salt = kek_salt
        profile.auth_hash = auth_hash
        profile.encrypted_user_key = encrypted_user_key
        profile.encryption_migrated = True

        logger.debug('Set up per-user encryption for %s', profile.user.username)

    def _create_demo_transactions(self, user):
        """Seed ~13 months of realistic transactions on the checking account.

        Includes a monthly savings transfer pair (checking -> savings), a yearly
        insurance bill (amortized over 12 months via a rule), and category rules
        so the spending report renders fully classified out of the box.
        """
        from portfolio.classification import apply_rules, detect_transfers
        from portfolio.models import CategoryRule, Transaction, TransactionCategory

        try:
            checking = FinancialAccount.objects.get(user=user, name='DKB Girokonto')
            savings = FinancialAccount.objects.get(user=user, name='Commerzbank Tagesgeld')
        except FinancialAccount.DoesNotExist:
            logger.warning(
                'Checking/savings demo accounts missing for %s, skipping transactions', user.username
            )
            return

        categories = {
            name: TransactionCategory.objects.create(user=user, name=name)
            for name in ['Rent', 'Groceries', 'Insurance', 'Subscriptions', 'Dining Out', 'Phone']
        }
        rules = [
            ('hausverwaltung', 'Rent', 1),
            ('rewe', 'Groceries', 1), ('edeka', 'Groceries', 1), ('lidl', 'Groceries', 1),
            ('axa', 'Insurance', 12),
            ('netflix', 'Subscriptions', 1),
            ('telekom', 'Phone', 1),
            ('restaurant', 'Dining Out', 1), ('sushi', 'Dining Out', 1), ('cafe', 'Dining Out', 1),
        ]
        for match_text, category_name, spread in rules:
            CategoryRule.objects.create(
                user=user, match_text=match_text,
                category=categories[category_name], spread_months=spread,
            )

        rng = random.Random(user.username)  # deterministic per user
        today = date.today()
        grocery_shops = ['REWE Markt', 'EDEKA', 'Lidl']
        dining_spots = ['Restaurant Roma', 'Sushi Bar Tokyo', 'Cafe Central']

        rows = []

        def add(account, day, amount, counterparty, description):
            if day > today:
                return
            rows.append(Transaction(
                account=account, booking_date=day, value_date=day,
                amount=Decimal(str(amount)), currency='EUR',
                counterparty=counterparty, description=description,
                source='fints', dedup_key=f'demo:{len(rows)}',
            ))

        for months_back in range(13, -1, -1):
            month_index = (today.year * 12 + today.month - 1) - months_back
            year, month = month_index // 12, month_index % 12 + 1

            def on(day):
                return date(year, month, day)

            add(checking, on(1), '-1250.00', 'Hausverwaltung Meier', 'Miete')
            add(checking, on(3), '-12.90', 'Netflix', 'Abo')
            add(checking, on(15), '-49.99', 'Telekom Deutschland', 'Mobilfunk Rechnung')
            add(checking, on(25), '3450.00', 'ACME GmbH', 'Gehalt')
            # Monthly savings transfer pair — detected and excluded from spending.
            add(checking, on(26), '-500.00', 'Eigenübertrag', 'Dauerauftrag Sparen')
            add(savings, on(min(27, 28)), '500.00', 'Eigenübertrag', 'Dauerauftrag Sparen')
            for _ in range(rng.randint(6, 9)):
                add(checking, on(rng.randint(2, 28)),
                    f'-{rng.uniform(15, 95):.2f}', rng.choice(grocery_shops), 'Einkauf')
            for _ in range(rng.randint(2, 4)):
                add(checking, on(rng.randint(2, 28)),
                    f'-{rng.uniform(18, 60):.2f}', rng.choice(dining_spots), '')
            if month == 8:  # yearly insurance bill, amortized via the AXA rule
                add(checking, on(10), '-948.00', 'AXA Versicherung', 'Jahresbeitrag Haftpflicht KFZ')

        Transaction.objects.bulk_create(rows)
        categorized = apply_rules(user)
        transfers = detect_transfers(user)
        logger.debug(
            'Created %d transactions for %s (%s categorized, %s marked as transfers)',
            len(rows), user.username, categorized, transfers,
        )

    def _create_demo_accounts(self, user, profile):
        """Create demo accounts with historical snapshots."""
        today = date.today()

        for name, broker_code, account_type, currency, is_manual, days_offset in DEMO_ACCOUNTS:
            # Get the broker
            try:
                broker = Broker.objects.get(code=broker_code)
            except Broker.DoesNotExist:
                logger.warning('Broker "%s" not found, skipping account "%s"', broker_code, name)
                continue

            # Create account
            account = FinancialAccount.objects.create(
                user=user,
                broker=broker,
                name=name,
                account_type=account_type,
                currency=currency,
                is_manual=is_manual,
                sync_enabled=False,
                status='active',
            )
            logger.debug('Created account "%s" for %s', name, user.username)

            # Generate snapshots
            newest_date = today - timedelta(days=days_offset)
            self._generate_snapshots(account, profile, newest_date)

    def _generate_snapshots(self, account, profile, newest_date):
        """Generate historical snapshots for an account."""
        # Calculate date range
        oldest_date = newest_date - timedelta(days=HISTORY_DAYS)

        # Generate snapshot dates (every 5 days, from oldest to newest)
        snapshot_dates = []
        current_date = oldest_date
        while current_date <= newest_date:
            snapshot_dates.append(current_date)
            current_date += timedelta(days=SNAPSHOT_INTERVAL_DAYS)

        # Ensure newest_date is included
        if snapshot_dates[-1] != newest_date:
            snapshot_dates.append(newest_date)

        # Generate balances with trend logic
        balances = self._generate_balances(len(snapshot_dates))

        # Create snapshots
        snapshots_to_create = []
        for snapshot_date, balance in zip(snapshot_dates, balances):
            # Convert to base currency if different
            balance_base = balance
            exchange_rate = Decimal('1.0')

            if account.currency != profile.base_currency:
                # Apply a simple mock exchange rate
                if account.currency == 'USD':
                    exchange_rate = Decimal('0.92')
                elif account.currency == 'CHF':
                    exchange_rate = Decimal('1.05')
                balance_base = balance * exchange_rate

            snapshots_to_create.append(AccountSnapshot(
                account=account,
                balance=balance,
                currency=account.currency,
                balance_base_currency=balance_base,
                base_currency=profile.base_currency,
                exchange_rate_used=exchange_rate,
                snapshot_date=snapshot_date,
                snapshot_source='manual' if account.is_manual else 'auto',
            ))

        AccountSnapshot.objects.bulk_create(snapshots_to_create)
        logger.debug('Created %d snapshots for account "%s"', len(snapshots_to_create), account.name)

    def _generate_balances(self, count):
        """
        Generate a list of balances with monthly trend logic.

        Each "month" (4 snapshots), a total growth/decrease rate is picked.
        Snapshots within that month interpolate monotonically toward the target.
        """
        balances = []
        current_balance = STARTING_BALANCE

        i = 0
        while i < count:
            # Determine trend and total rate for this month
            is_growing = random.random() < GROWTH_PROBABILITY

            if is_growing:
                monthly_rate = GROWTH_RATE_MIN + Decimal(str(random.random())) * (
                    GROWTH_RATE_MAX - GROWTH_RATE_MIN
                )
                end_balance = current_balance * (1 + monthly_rate)
            else:
                monthly_rate = DECREASE_RATE_MIN + Decimal(str(random.random())) * (
                    DECREASE_RATE_MAX - DECREASE_RATE_MIN
                )
                end_balance = current_balance * (1 - monthly_rate)

            # How many snapshots in this chunk
            chunk_size = min(4, count - i)

            # Pick random split points to distribute the move monotonically
            # Generate sorted random fractions for intermediate steps
            if chunk_size == 1:
                fractions = [Decimal('1')]
            else:
                raw = sorted(random.random() for _ in range(chunk_size - 1))
                fractions = [Decimal(str(r)) for r in raw] + [Decimal('1')]

            delta = end_balance - current_balance
            for f in fractions:
                balance = current_balance + delta * f
                balances.append(balance.quantize(Decimal('0.0001')))

            current_balance = end_balance.quantize(Decimal('0.0001'))
            i += chunk_size

        return balances[:count]
