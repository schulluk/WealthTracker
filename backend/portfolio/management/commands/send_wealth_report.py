"""
Management command to send weekly wealth report emails.

Usage:
    python manage.py send_wealth_report

This command sends a wealth summary email to all users who have
send_weekly_report=True in their profile. Intended to run on Mondays.
"""
import logging
from datetime import date, timedelta
from decimal import Decimal

from django.conf import settings
from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.core.management.base import BaseCommand
from django.db.models import Sum

from exchange_rates.models import ExchangeRate
from portfolio.models import AccountSnapshot, FinancialAccount

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Send weekly wealth report emails to subscribed users'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what emails would be sent without actually sending',
        )
        parser.add_argument(
            '--user',
            type=str,
            help='Send report only to specific username',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        target_user = options['user']

        # Get users with weekly report enabled
        users = User.objects.filter(profile__send_weekly_report=True)

        if target_user:
            users = users.filter(username=target_user)

        logger.info('Found %d users with weekly report enabled', users.count())

        sent_count = 0
        for user in users:
            if not user.email:
                logger.warning('Skipping %s: no email address', user.username)
                continue

            try:
                report = self._generate_report(user)

                if dry_run:
                    logger.info('Would send to %s:\n%s...', user.email, report['body'][:500])
                else:
                    send_mail(
                        subject=report['subject'],
                        message=report['body'],
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[user.email],
                        fail_silently=False,
                    )
                    logger.info('Sent to %s', user.username)  # no email addresses in the logs
                    sent_count += 1

            except Exception as e:
                logger.exception('Failed for %s: %s', user.username, e)

        logger.info('Sent %d emails', sent_count)

    def _generate_report(self, user):
        """Generate wealth report for a user."""
        base_currency = user.profile.base_currency
        today = date.today()

        # Get all user accounts
        accounts = FinancialAccount.objects.filter(user=user)

        # Calculate current total wealth
        total_wealth = Decimal('0')
        account_details = []

        for account in accounts:
            snapshot = AccountSnapshot.objects.filter(
                account=account
            ).order_by('-snapshot_date').first()

            if snapshot:
                # Convert to base currency
                balance_base = self._convert_currency(
                    snapshot.balance,
                    snapshot.currency,
                    base_currency,
                    snapshot.snapshot_date
                )

                total_wealth += balance_base
                account_details.append({
                    'name': account.name,
                    'broker': account.broker.name,
                    'balance': snapshot.balance,
                    'currency': snapshot.currency,
                    'balance_base': balance_base,
                    'date': snapshot.snapshot_date,
                })

        # Get historical data for comparison
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)

        week_ago_total = self._get_historical_total(user, week_ago, base_currency)
        month_ago_total = self._get_historical_total(user, month_ago, base_currency)

        week_change = total_wealth - week_ago_total if week_ago_total else None
        month_change = total_wealth - month_ago_total if month_ago_total else None

        # Format the email
        subject = f'[Wealth Tracker] Weekly Report - {self._format_currency(total_wealth, base_currency)}'

        lines = [
            f'Weekly Wealth Report for {user.first_name or user.username}',
            f'Date: {today.strftime("%Y-%m-%d")}',
            '',
            '=' * 50,
            f'Total Wealth: {self._format_currency(total_wealth, base_currency)}',
            '=' * 50,
            '',
        ]

        if week_change is not None:
            week_pct = (week_change / week_ago_total * 100) if week_ago_total else 0
            sign = '+' if week_change >= 0 else ''
            lines.append(f'7-day change: {sign}{self._format_currency(week_change, base_currency)} ({sign}{week_pct:.1f}%)')

        if month_change is not None:
            month_pct = (month_change / month_ago_total * 100) if month_ago_total else 0
            sign = '+' if month_change >= 0 else ''
            lines.append(f'30-day change: {sign}{self._format_currency(month_change, base_currency)} ({sign}{month_pct:.1f}%)')

        lines.extend(['', 'Account Breakdown:', '-' * 50])

        for detail in sorted(account_details, key=lambda x: x['balance_base'], reverse=True):
            pct = (detail['balance_base'] / total_wealth * 100) if total_wealth else 0
            lines.append(
                f"  {detail['name']} ({detail['broker']}): "
                f"{self._format_currency(detail['balance_base'], base_currency)} ({pct:.1f}%)"
            )

        lines.extend([
            '',
            '-' * 50,
            'This is an automated email from Wealth Tracker.',
            'To unsubscribe, disable weekly reports in your profile settings.',
        ])

        return {
            'subject': subject,
            'body': '\n'.join(lines),
        }

    def _get_historical_total(self, user, target_date, base_currency):
        """Get total wealth as of a specific date."""
        accounts = FinancialAccount.objects.filter(user=user)
        total = Decimal('0')

        for account in accounts:
            # Get snapshot closest to target date
            snapshot = AccountSnapshot.objects.filter(
                account=account,
                snapshot_date__lte=target_date
            ).order_by('-snapshot_date').first()

            if snapshot:
                balance_base = self._convert_currency(
                    snapshot.balance,
                    snapshot.currency,
                    base_currency,
                    snapshot.snapshot_date
                )
                total += balance_base

        return total if total > 0 else None

    def _convert_currency(self, amount, from_currency, to_currency, rate_date):
        """Convert amount from one currency to another."""
        if from_currency == to_currency:
            return amount

        # Try to find exchange rate
        rate = ExchangeRate.objects.filter(
            from_currency=from_currency,
            to_currency=to_currency,
            rate_date__lte=rate_date
        ).order_by('-rate_date').first()

        if rate:
            return amount * rate.rate

        # Try inverse
        rate = ExchangeRate.objects.filter(
            from_currency=to_currency,
            to_currency=from_currency,
            rate_date__lte=rate_date
        ).order_by('-rate_date').first()

        if rate and rate.rate != 0:
            return amount / rate.rate

        # Fallback: no conversion
        return amount

    def _format_currency(self, amount, currency):
        """Format amount with currency symbol."""
        symbols = {'CHF': 'CHF', 'EUR': '€', 'USD': '$', 'GBP': '£'}
        symbol = symbols.get(currency, currency)
        return f"{symbol} {amount:,.2f}"
