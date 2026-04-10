import logging
import uuid
from datetime import date, timedelta
from decimal import Decimal
from time import time

logger = logging.getLogger(__name__)

# Discovery sessions stored in memory (requires single gunicorn worker for FinTS)
# FinTS client objects contain TCP connections that cannot be pickled/serialized
# Sessions expire after 10 minutes (photoTAN requires scanning + entering code)
DISCOVERY_SESSION_TIMEOUT = 600  # 10 minutes
_discovery_sessions: dict[str, dict] = {}


def _get_session(token: str) -> dict | None:
    """Get a session by token from in-memory storage."""
    return _discovery_sessions.get(token)


def _set_session(token: str, data: dict):
    """Set a session in in-memory storage."""
    _discovery_sessions[token] = data


def _delete_session(token: str):
    """Delete a session from in-memory storage."""
    _discovery_sessions.pop(token, None)


def _cleanup_expired_sessions():
    """Remove expired sessions from memory."""
    now = time()
    expired = [
        token for token, data in _discovery_sessions.items()
        if now - data.get('created_at', 0) > DISCOVERY_SESSION_TIMEOUT
    ]
    for token in expired:
        session = _discovery_sessions.pop(token, None)
        if session:
            integration = session.get('integration')
            if integration:
                try:
                    integration.close()
                except Exception:
                    pass


from django.utils import timezone
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.kek_auth import KEKAuthenticationMixin
from exchange_rates.models import ExchangeRate

from .models import AccountSnapshot, FinancialAccount
from .serializers import (
    AccountSnapshotCreateSerializer,
    AccountSnapshotSerializer,
    FinancialAccountCreateSerializer,
    FinancialAccountSerializer,
)


class FinancialAccountListCreateView(generics.ListCreateAPIView):
    """List user's accounts or create a new one."""
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return FinancialAccountCreateSerializer
        return FinancialAccountSerializer

    def get_queryset(self):
        return FinancialAccount.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class FinancialAccountDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update or delete a financial account."""
    serializer_class = FinancialAccountSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return FinancialAccount.objects.filter(user=self.request.user)


def _sync_single_account(*, account_id, credentials, base_currency):
    """Run on the sync worker thread. Syncs a single account."""
    import django
    django.db.connections.close_all()  # Get fresh DB connections for this thread

    from brokers.integrations import get_broker_integration

    account = FinancialAccount.objects.get(pk=account_id)
    integration = get_broker_integration(account.broker, credentials)

    try:
        auth_result = integration.authenticate()

        if not auth_result.success:
            if auth_result.requires_2fa:
                account.status = 'pending_auth'
                account.pending_auth_state = {
                    'two_fa_type': auth_result.two_fa_type,
                    'session_data': auth_result.session_data,
                }
                account.save()
                return {
                    'status': 'pending_auth',
                    'message': 'Two-factor authentication required',
                    'two_fa_type': auth_result.two_fa_type,
                    'challenge': auth_result.challenge_data,
                }
            else:
                account.status = 'error'
                account.last_sync_error = auth_result.error_message
                account.save()
                return {'status': 'error', 'error': auth_result.error_message}

        # Auth successful — fetch balance
        balance_info = integration.get_balance(account.account_identifier)

        existing = AccountSnapshot.objects.filter(
            account=account,
            balance=balance_info.balance,
            currency=balance_info.currency,
            snapshot_date=balance_info.balance_date,
        ).first()

        if existing:
            snapshot = existing
            created = False
        else:
            snapshot = AccountSnapshot.objects.create(
                account=account,
                balance=balance_info.balance,
                currency=balance_info.currency,
                snapshot_date=balance_info.balance_date,
                snapshot_source='auto',
                raw_data=balance_info.raw_data,
            )
            created = True

        # Convert to base currency
        if balance_info.currency != base_currency:
            from exchange_rates.services import ExchangeRateService
            rate = ExchangeRateService.get_rate(
                balance_info.currency, base_currency, balance_info.balance_date,
            )
            if rate and rate != Decimal('1.0'):
                snapshot.balance_base_currency = balance_info.balance * rate
                snapshot.base_currency = base_currency
                snapshot.exchange_rate_used = rate
                snapshot.save()

        # Backfill historical data if supported
        backfilled_count = 0
        if integration.supports_historical_data():
            backfilled_count = _backfill_historical(
                account, integration, base_currency,
            )

        account.status = 'active'
        account.last_sync_at = timezone.now()
        account.last_sync_error = ''
        account.pending_auth_state = None
        account.save()

        message = 'Sync completed' if created else 'No change (snapshot already exists)'
        if backfilled_count > 0:
            message += f' + {backfilled_count} historical snapshots backfilled'

        return {
            'status': 'success',
            'message': message,
            'snapshot': {
                'id': snapshot.id,
                'balance': float(snapshot.balance),
                'currency': snapshot.currency,
                'date': snapshot.snapshot_date.isoformat(),
                'created': created,
            },
            'backfilled': backfilled_count,
        }
    finally:
        integration.close()


def _sync_all_accounts(*, account_creds, base_currency):
    """Run on the sync worker thread. Syncs all accounts sequentially."""
    import django
    django.db.connections.close_all()

    from brokers.integrations import get_broker_integration

    results = {
        'synced': [],
        'pending_2fa': [],
        'errors': [],
        'skipped': [],
    }

    for account_id, credentials in account_creds:
        try:
            account = FinancialAccount.objects.get(pk=account_id)
            integration = get_broker_integration(account.broker, credentials)

            try:
                auth_result = integration.authenticate()

                if not auth_result.success:
                    if auth_result.requires_2fa:
                        account.status = 'pending_auth'
                        account.pending_auth_state = {
                            'two_fa_type': auth_result.two_fa_type,
                            'session_data': auth_result.session_data,
                        }
                        account.save()
                        results['pending_2fa'].append({
                            'id': account.id,
                            'name': account.name,
                            'two_fa_type': auth_result.two_fa_type,
                        })
                        continue
                    else:
                        account.status = 'error'
                        account.last_sync_error = auth_result.error_message
                        account.save()
                        results['errors'].append({
                            'id': account.id,
                            'name': account.name,
                            'error': auth_result.error_message,
                        })
                        continue

                balance_info = integration.get_balance(account.account_identifier)

                existing = AccountSnapshot.objects.filter(
                    account=account,
                    balance=balance_info.balance,
                    currency=balance_info.currency,
                    snapshot_date=balance_info.balance_date,
                ).first()

                if existing:
                    results['skipped'].append({
                        'id': account.id,
                        'name': account.name,
                        'reason': 'No change',
                    })
                else:
                    snapshot = AccountSnapshot.objects.create(
                        account=account,
                        balance=balance_info.balance,
                        currency=balance_info.currency,
                        snapshot_date=balance_info.balance_date,
                        snapshot_source='auto',
                        raw_data=balance_info.raw_data,
                    )

                    if balance_info.currency != base_currency:
                        from exchange_rates.services import ExchangeRateService
                        rate = ExchangeRateService.get_rate(
                            balance_info.currency, base_currency,
                            balance_info.balance_date,
                        )
                        if rate and rate != Decimal('1.0'):
                            snapshot.balance_base_currency = balance_info.balance * rate
                            snapshot.base_currency = base_currency
                            snapshot.exchange_rate_used = rate
                            snapshot.save()

                    results['synced'].append({
                        'id': account.id,
                        'name': account.name,
                        'balance': float(balance_info.balance),
                        'currency': balance_info.currency,
                    })

                account.status = 'active'
                account.last_sync_at = timezone.now()
                account.last_sync_error = ''
                account.pending_auth_state = None
                account.save()

            finally:
                integration.close()

        except Exception as e:
            logger.exception("Sync failed for account %s", account_id)
            try:
                account = FinancialAccount.objects.get(pk=account_id)
                account.status = 'error'
                account.last_sync_error = str(e) or repr(e)
                account.save()
            except Exception:
                pass
            results['errors'].append({
                'id': account_id,
                'name': getattr(account, 'name', str(account_id)),
                'error': str(e) or repr(e),
            })

    return {
        'status': 'success',
        'synced_count': len(results['synced']),
        'pending_2fa_count': len(results['pending_2fa']),
        'error_count': len(results['errors']),
        'skipped_count': len(results['skipped']),
        'details': results,
    }


def _backfill_historical(account, integration, base_currency):
    """
    Backfill historical snapshots from broker if available.
    Returns the number of snapshots created.

    Strategy:
    - Look at past HISTORICAL_BACKFILL_MAX_LOOKBACK_DAYS (365) days
    - Find oldest missing date (gap) in that window
    - Request from that date + HISTORICAL_BACKFILL_BUFFER_DAYS (5) buffer
    - Max request is 365 + 5 = 370 days
    - Skip if already have good recent coverage
    """
    from django.conf import settings as django_settings

    try:
        max_lookback = getattr(django_settings, 'HISTORICAL_BACKFILL_MAX_LOOKBACK_DAYS', 365)
        buffer_days = getattr(django_settings, 'HISTORICAL_BACKFILL_BUFFER_DAYS', 5)
        skip_if_recent_days = getattr(django_settings, 'HISTORICAL_BACKFILL_SKIP_IF_RECENT_DAYS', 2)

        existing_dates = set(
            AccountSnapshot.objects.filter(account=account)
            .values_list('snapshot_date', flat=True)
        )

        end_date = date.today()

        if integration.historical_data_requires_extra_request():
            oldest_gap = None
            for days_ago in range(max_lookback, skip_if_recent_days, -1):
                check_date = end_date - timedelta(days=days_ago)
                if check_date not in existing_dates:
                    oldest_gap = check_date
                    break

            if oldest_gap is None:
                return 0

            start_date = oldest_gap - timedelta(days=buffer_days)
            max_start = end_date - timedelta(days=max_lookback + buffer_days)
            if start_date < max_start:
                start_date = max_start
        else:
            start_date = end_date - timedelta(days=3650)

        logger.info(f"Backfilling {account.name} historical data from {start_date} to {end_date}")

        historical = integration.get_historical_balances(
            account.account_identifier, start_date, end_date
        )

        if not historical:
            return 0

        created_count = 0
        for bal_info in historical:
            if bal_info.balance_date in existing_dates:
                continue

            snapshot = AccountSnapshot.objects.create(
                account=account,
                balance=bal_info.balance,
                currency=bal_info.currency,
                snapshot_date=bal_info.balance_date,
                snapshot_source='auto',
                raw_data=bal_info.raw_data,
            )

            if bal_info.currency != base_currency:
                from exchange_rates.services import ExchangeRateService
                rate = ExchangeRateService.get_rate(
                    bal_info.currency, base_currency, bal_info.balance_date
                )
                if rate and rate != Decimal('1.0'):
                    snapshot.balance_base_currency = bal_info.balance * rate
                    snapshot.base_currency = base_currency
                    snapshot.exchange_rate_used = rate
                    snapshot.save()
            else:
                snapshot.balance_base_currency = bal_info.balance
                snapshot.base_currency = base_currency
                snapshot.save()

            created_count += 1
            existing_dates.add(bal_info.balance_date)

        logger.info(f"Backfilled {created_count} snapshots for {account.name}")
        return created_count

    except Exception as e:
        logger.warning(f"Failed to backfill historical data for {account.name}: {e}")
        return 0


class AccountSyncView(KEKAuthenticationMixin, APIView):
    """Trigger a sync for an account.

    Decrypts credentials on the request thread, then enqueues the actual
    sync work to a dedicated background thread so other API requests
    (graphs, snapshots) are not blocked.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        from .sync_queue import sync_queue

        try:
            account = FinancialAccount.objects.get(pk=pk, user=request.user)
        except FinancialAccount.DoesNotExist:
            return Response({'error': 'Account not found'}, status=status.HTTP_404_NOT_FOUND)

        if account.is_manual:
            return Response({'error': 'Cannot sync manual accounts'}, status=status.HTTP_400_BAD_REQUEST)

        if not account.encrypted_credentials:
            return Response({'error': 'No credentials configured'}, status=status.HTTP_400_BAD_REQUEST)

        # Check for already-running sync for this user
        existing = sync_queue.has_pending_task(request.user.id)
        if existing:
            return Response({
                'status': 'queued',
                'task_id': existing,
                'message': 'A sync is already in progress',
            })

        try:
            # Decrypt credentials on the request thread (needs KEK header)
            credentials = self.decrypt_account_credentials(request, account)
            base_currency = request.user.profile.base_currency
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        # Enqueue sync work to background thread
        task_id = sync_queue.enqueue(
            request.user.id,
            _sync_single_account,
            account_id=account.id,
            credentials=credentials,
            base_currency=base_currency,
        )

        return Response({
            'status': 'queued',
            'task_id': task_id,
            'message': 'Sync started',
        })


class SyncAllAccountsView(KEKAuthenticationMixin, APIView):
    """Trigger sync for all accounts that support auto-sync.

    Decrypts all credentials on the request thread, then enqueues the
    sync work to run sequentially on the background thread.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from .sync_queue import sync_queue

        # Check for already-running sync for this user
        existing = sync_queue.has_pending_task(request.user.id)
        if existing:
            return Response({
                'status': 'queued',
                'task_id': existing,
                'message': 'A sync is already in progress',
            })

        # Find all syncable accounts
        accounts = FinancialAccount.objects.filter(
            user=request.user,
            is_manual=False,
            sync_enabled=True,
        ).exclude(encrypted_credentials__isnull=True).exclude(encrypted_credentials=b'')

        if not accounts.exists():
            return Response({
                'status': 'success',
                'message': 'No accounts to sync',
                'synced_count': 0,
                'pending_2fa_count': 0,
                'error_count': 0,
                'skipped_count': 0,
                'details': {'synced': [], 'pending_2fa': [], 'errors': [], 'skipped': []},
            })

        # Decrypt all credentials on the request thread (needs KEK header)
        base_currency = request.user.profile.base_currency
        account_creds = []
        for account in accounts:
            try:
                creds = self.decrypt_account_credentials(request, account)
                account_creds.append((account.id, creds))
            except Exception as e:
                logger.warning("Failed to decrypt credentials for account %s: %s", account.id, e)

        if not account_creds:
            return Response({
                'error': 'Failed to decrypt credentials for all accounts',
            }, status=status.HTTP_400_BAD_REQUEST)

        # Enqueue sync work to background thread
        task_id = sync_queue.enqueue(
            request.user.id,
            _sync_all_accounts,
            account_creds=account_creds,
            base_currency=base_currency,
        )

        return Response({
            'status': 'queued',
            'task_id': task_id,
            'message': f'Sync started for {len(account_creds)} accounts',
        })


class SyncTaskStatusView(APIView):
    """Poll for the status of a background sync task."""
    permission_classes = [IsAuthenticated]

    def get(self, request, task_id):
        from .sync_queue import sync_queue

        result = sync_queue.get_status(task_id)
        if result is None:
            return Response(
                {'error': 'Task not found or expired'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(result)


class AccountAuthView(KEKAuthenticationMixin, APIView):
    """Handle 2FA authentication for an account."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        from brokers.integrations import get_broker_integration

        try:
            account = FinancialAccount.objects.get(pk=pk, user=request.user)
        except FinancialAccount.DoesNotExist:
            return Response({'error': 'Account not found'}, status=status.HTTP_404_NOT_FOUND)

        if account.status != 'pending_auth':
            return Response(
                {'error': 'Account is not pending authentication'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not account.pending_auth_state:
            return Response(
                {'error': 'No pending auth state. Please initiate sync first.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        auth_code = request.data.get('auth_code')
        session_data = account.pending_auth_state.get('session_data', {})

        try:
            # Decrypt credentials and get integration
            credentials = self.decrypt_account_credentials(request, account)
            integration = get_broker_integration(account.broker, credentials)

            # Re-authenticate to restore session
            auth_result = integration.authenticate()

            if auth_result.requires_2fa:
                # Complete 2FA
                auth_result = integration.complete_2fa(auth_code, session_data)

                if not auth_result.success:
                    return Response(
                        {'error': auth_result.error_message or '2FA failed'},
                        status=status.HTTP_400_BAD_REQUEST
                    )

            # 2FA successful, complete the sync
            sync_view = AccountSyncView()
            return sync_view._complete_sync(account, integration, request)

        except Exception as e:
            account.status = 'error'
            account.last_sync_error = str(e)
            account.save()
            return Response(
                {'error': f'Authentication failed: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AccountCredentialsView(KEKAuthenticationMixin, APIView):
    """Get or update credentials for an account."""
    permission_classes = [IsAuthenticated]

    # Fields that should be masked when returning credentials
    SENSITIVE_FIELDS = ('password', 'pin', 'secret', 'flex_token', 'token', 'api_key')

    def get(self, request, pk):
        """Get current credentials with sensitive fields masked."""
        try:
            account = FinancialAccount.objects.get(pk=pk, user=request.user)
        except FinancialAccount.DoesNotExist:
            return Response({'error': 'Account not found'}, status=status.HTTP_404_NOT_FOUND)

        if account.is_manual:
            return Response({'credentials': {}})

        if not account.encrypted_credentials:
            return Response({'credentials': {}})

        try:
            credentials = self.decrypt_account_credentials(request, account)
            # Mask sensitive fields
            masked = {}
            for key, value in credentials.items():
                if any(s in key.lower() for s in self.SENSITIVE_FIELDS):
                    # Show masked placeholder if value exists
                    masked[key] = '••••••••' if value else ''
                else:
                    masked[key] = value
            return Response({'credentials': masked})
        except Exception:
            return Response({'credentials': {}})

    def put(self, request, pk):
        try:
            account = FinancialAccount.objects.get(pk=pk, user=request.user)
        except FinancialAccount.DoesNotExist:
            return Response({'error': 'Account not found'}, status=status.HTTP_404_NOT_FOUND)

        if account.is_manual:
            return Response(
                {'error': 'Manual accounts do not have credentials'},
                status=status.HTTP_400_BAD_REQUEST
            )

        credentials = request.data.get('credentials')
        if not credentials:
            return Response(
                {'error': 'Credentials are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get existing credentials to merge with
        existing = {}
        if account.encrypted_credentials:
            try:
                existing = self.decrypt_account_credentials(request, account)
            except Exception:
                pass

        # Merge: only update fields that have non-empty, non-masked values
        one_time_fields = ('token', 'totp_token', 'otp', 'tan', 'sms_code')
        for key, value in credentials.items():
            if key in one_time_fields:
                continue
            # Skip empty values and masked placeholders
            if value and value != '••••••••':
                existing[key] = value

        account.encrypted_credentials = self.encrypt_account_credentials(request, existing)
        account.status = 'active'  # Reset status since credentials were updated
        account.last_sync_error = ''
        account.save()

        return Response({'status': 'success', 'message': 'Credentials updated'})


class AccountSnapshotListCreateView(generics.ListCreateAPIView):
    """List snapshots for an account or create a manual one."""
    permission_classes = [IsAuthenticated]
    serializer_class = AccountSnapshotSerializer

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return AccountSnapshotCreateSerializer
        return AccountSnapshotSerializer

    def create(self, request, *args, **kwargs):
        """Override to return full snapshot data after creation."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        # Return full snapshot using read serializer
        snapshot = serializer.instance
        response_serializer = AccountSnapshotSerializer(snapshot)
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)

    def get_queryset(self):
        account_id = self.kwargs['account_id']
        return AccountSnapshot.objects.filter(
            account_id=account_id,
            account__user=self.request.user
        )

    def perform_create(self, serializer):
        from rest_framework.exceptions import ValidationError

        account_id = self.kwargs['account_id']
        account = FinancialAccount.objects.get(pk=account_id, user=self.request.user)

        # Check for duplicate snapshot (same date, currency, and balance)
        balance = serializer.validated_data.get('balance')
        currency = serializer.validated_data.get('currency')
        snapshot_date = serializer.validated_data.get('snapshot_date')

        existing = AccountSnapshot.objects.filter(
            account=account,
            balance=balance,
            currency=currency,
            snapshot_date=snapshot_date
        ).exists()

        if existing:
            raise ValidationError({
                'detail': 'A snapshot with the same date, currency, and balance already exists.'
            })

        snapshot = serializer.save(account=account)

        # Convert to base currency
        user_profile = self.request.user.profile
        if snapshot.currency != user_profile.base_currency:
            rate = ExchangeRate.get_rate(
                snapshot.currency,
                user_profile.base_currency,
                snapshot.snapshot_date
            )
            # Fetch exchange rate if missing
            if not rate:
                from exchange_rates.services import ExchangeRateService
                try:
                    ExchangeRateService.fetch_rates_for_date(snapshot.snapshot_date)
                    # Retry getting rate after fetch
                    rate = ExchangeRate.get_rate(
                        snapshot.currency,
                        user_profile.base_currency,
                        snapshot.snapshot_date
                    )
                except Exception:
                    pass  # Will leave base_currency fields empty if fetch fails
            if rate:
                snapshot.balance_base_currency = snapshot.balance * rate
                snapshot.base_currency = user_profile.base_currency
                snapshot.exchange_rate_used = rate
                snapshot.save()


class AccountSnapshotDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update, or delete a snapshot."""
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return AccountSnapshotCreateSerializer
        return AccountSnapshotSerializer

    def get_queryset(self):
        return AccountSnapshot.objects.filter(account__user=self.request.user)

    def perform_update(self, serializer):
        snapshot = serializer.save()
        # Recalculate base currency conversion
        user_profile = self.request.user.profile
        if snapshot.currency != user_profile.base_currency:
            rate = ExchangeRate.get_rate(
                snapshot.currency,
                user_profile.base_currency,
                snapshot.snapshot_date
            )
            # Fetch exchange rate if missing
            if not rate:
                from exchange_rates.services import ExchangeRateService
                try:
                    ExchangeRateService.fetch_rates_for_date(snapshot.snapshot_date)
                    # Retry getting rate after fetch
                    rate = ExchangeRate.get_rate(
                        snapshot.currency,
                        user_profile.base_currency,
                        snapshot.snapshot_date
                    )
                except Exception:
                    pass
            if rate:
                snapshot.balance_base_currency = snapshot.balance * rate
                snapshot.base_currency = user_profile.base_currency
                snapshot.exchange_rate_used = rate
            else:
                snapshot.balance_base_currency = None
                snapshot.base_currency = None
                snapshot.exchange_rate_used = None
        else:
            # Same currency, no conversion needed
            snapshot.balance_base_currency = snapshot.balance
            snapshot.base_currency = user_profile.base_currency
            snapshot.exchange_rate_used = Decimal('1')
        snapshot.save()


class WealthSummaryView(APIView):
    """Get current total wealth summary."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_profile = request.user.profile
        base_currency = user_profile.base_currency

        accounts = FinancialAccount.objects.filter(user=request.user)
        total_wealth = Decimal('0')
        account_summaries = []

        for account in accounts:
            snapshot = account.latest_snapshot
            if snapshot:
                if snapshot.balance_base_currency:
                    amount = snapshot.balance_base_currency
                elif snapshot.currency == base_currency:
                    amount = snapshot.balance
                else:
                    rate = ExchangeRate.get_rate(
                        snapshot.currency, base_currency, snapshot.snapshot_date
                    )
                    amount = snapshot.balance * rate if rate else Decimal('0')

                total_wealth += amount
                account_summaries.append({
                    'account_id': account.id,
                    'account_name': account.name,
                    'broker': account.broker.name,
                    'balance': float(snapshot.balance),
                    'currency': snapshot.currency,
                    'balance_base_currency': float(amount),
                    'snapshot_date': snapshot.snapshot_date,
                })

        return Response({
            'total_wealth': float(total_wealth),
            'base_currency': base_currency,
            'accounts': account_summaries,
            'account_count': len(account_summaries),
        })


class WealthHistoryView(APIView):
    """Get historical wealth timeline."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_profile = request.user.profile
        base_currency = user_profile.base_currency

        # Get date range from query params
        days = int(request.query_params.get('days', 30))
        granularity = request.query_params.get('granularity', 'daily')  # daily or monthly
        end_date = date.today()
        start_date = end_date - timedelta(days=days)

        # Limit start_date to oldest snapshot date if more recent
        oldest_snapshot = AccountSnapshot.objects.filter(
            account__user=request.user
        ).order_by('snapshot_date').first()
        if oldest_snapshot and oldest_snapshot.snapshot_date > start_date:
            start_date = oldest_snapshot.snapshot_date

        # Get all snapshots up to end_date (including before start_date for carry-forward).
        # Use only the fields we need to reduce memory and transfer.
        snapshots = AccountSnapshot.objects.filter(
            account__user=request.user,
            snapshot_date__lte=end_date
        ).order_by('snapshot_date', 'created_at').only(
            'account_id', 'snapshot_date', 'balance',
            'balance_base_currency', 'currency',
        )

        # Build a timeline of the latest balance for each account on each date
        # For each account, track all snapshots in chronological order
        account_snapshots = {}  # account_id -> list of (date, balance_in_base)
        for snapshot in snapshots:
            account_id = snapshot.account_id
            if account_id not in account_snapshots:
                account_snapshots[account_id] = []

            # Calculate balance in base currency
            if snapshot.balance_base_currency:
                amount = snapshot.balance_base_currency
            elif snapshot.currency == base_currency:
                amount = snapshot.balance
            else:
                rate = ExchangeRate.get_rate(
                    snapshot.currency, base_currency, snapshot.snapshot_date
                )
                amount = snapshot.balance * rate if rate else Decimal('0')

            account_snapshots[account_id].append((snapshot.snapshot_date, amount))

        # For each account, deduplicate by date (keep last per date due to
        # ordering by created_at) and build a sorted list.
        for account_id in account_snapshots:
            by_date = {}
            for snap_date, amount in account_snapshots[account_id]:
                by_date[snap_date] = amount
            account_snapshots[account_id] = sorted(by_date.items())

        # Generate daily totals using carry-forward with bisect.
        # For each account, binary-search for the latest snapshot <= current_date
        # instead of scanning all snapshots linearly.
        from bisect import bisect_right

        # Pre-extract date arrays for fast bisect lookup
        account_dates = {}   # account_id -> [date1, date2, ...]
        account_values = {}  # account_id -> [amount1, amount2, ...]
        for account_id, snapshots_list in account_snapshots.items():
            dates = [s[0] for s in snapshots_list]
            values = [s[1] for s in snapshots_list]
            account_dates[account_id] = dates
            account_values[account_id] = values

        daily_totals = {}
        current_date = start_date
        while current_date <= end_date:
            total = Decimal('0')
            for account_id in account_snapshots:
                dates = account_dates[account_id]
                idx = bisect_right(dates, current_date) - 1
                if idx >= 0:
                    total += account_values[account_id][idx]
            daily_totals[current_date.isoformat()] = total
            current_date += timedelta(days=1)

        # Aggregate to monthly if requested
        if granularity == 'monthly':
            import calendar
            aggregation = user_profile.monthly_aggregation  # last, min, max, avg

            # Group daily values by (year, month)
            monthly_buckets = {}  # (year, month) -> list of (date_str, total)
            for date_str, total in daily_totals.items():
                d = date.fromisoformat(date_str)
                key = (d.year, d.month)
                monthly_buckets.setdefault(key, []).append((date_str, total))

            monthly_totals = {}
            reference_day = end_date.day
            for (year, month), entries in monthly_buckets.items():
                last_day_of_month = calendar.monthrange(year, month)[1]
                target_day = min(reference_day, last_day_of_month)
                month_key = date(year, month, target_day).isoformat()

                values = [v for _, v in entries]
                if aggregation == 'min':
                    monthly_totals[month_key] = min(values)
                elif aggregation == 'max':
                    monthly_totals[month_key] = max(values)
                elif aggregation == 'avg':
                    monthly_totals[month_key] = sum(values) / len(values)
                else:  # 'last' — pick the value closest to target_day
                    best = entries[0]
                    target_date = date(year, month, target_day)
                    for date_str, total in entries:
                        d = date.fromisoformat(date_str)
                        best_d = date.fromisoformat(best[0])
                        if d <= target_date and (best_d > target_date or d > best_d):
                            best = (date_str, total)
                    monthly_totals[month_key] = best[1]

            history = [
                {'date': mk, 'total_wealth': float(v)}
                for mk, v in sorted(monthly_totals.items())
            ]
        else:
            history = [
                {'date': d, 'total_wealth': float(v)}
                for d, v in sorted(daily_totals.items())
            ]

        return Response({
            'base_currency': base_currency,
            'start_date': start_date.isoformat(),
            'end_date': end_date.isoformat(),
            'granularity': granularity,
            'history': history,
        })


class WealthBreakdownView(APIView):
    """Get wealth breakdown by account, broker, or currency."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_profile = request.user.profile
        base_currency = user_profile.base_currency
        group_by = request.query_params.get('by', 'broker')

        accounts = FinancialAccount.objects.filter(user=request.user)
        breakdown = {}

        for account in accounts:
            snapshot = account.latest_snapshot
            if not snapshot:
                continue

            if snapshot.balance_base_currency:
                amount = snapshot.balance_base_currency
            elif snapshot.currency == base_currency:
                amount = snapshot.balance
            else:
                rate = ExchangeRate.get_rate(
                    snapshot.currency, base_currency, snapshot.snapshot_date
                )
                amount = snapshot.balance * rate if rate else Decimal('0')

            if group_by == 'broker':
                key = account.broker.name
            elif group_by == 'currency':
                key = snapshot.currency
            elif group_by == 'account_type':
                key = account.get_account_type_display()
            else:
                key = account.name

            if key not in breakdown:
                breakdown[key] = Decimal('0')
            breakdown[key] += amount

        total = sum(breakdown.values(), Decimal('0'))
        result = [
            {
                'category': k,
                'amount': float(v),
                'percentage': float(v / total * 100) if total else 0
            }
            for k, v in sorted(breakdown.items(), key=lambda x: -x[1])
        ]

        return Response({
            'base_currency': base_currency,
            'group_by': group_by,
            'total': float(total),
            'breakdown': result,
        })


class BrokerDiscoverView(APIView):
    """Authenticate with a broker and discover available accounts."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from brokers.integrations import get_broker_integration
        from brokers.models import Broker

        broker_code = request.data.get('broker_code')
        credentials = request.data.get('credentials', {})

        if not broker_code:
            return Response(
                {'error': 'broker_code is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            broker = Broker.objects.get(code=broker_code, is_active=True)
        except Broker.DoesNotExist:
            return Response(
                {'error': f'Broker "{broker_code}" not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Cleanup expired sessions periodically
        _cleanup_expired_sessions()

        try:
            integration = get_broker_integration(broker, credentials)
            auth_result = integration.authenticate()

            if not auth_result.success:
                if auth_result.requires_2fa:
                    # Generate session token and store integration for 2FA completion
                    # NOTE: Using 1 gunicorn worker, so in-memory storage works
                    session_token = str(uuid.uuid4())
                    _set_session(session_token, {
                        'integration': integration,
                        'broker_code': broker_code,
                        'session_data': auth_result.session_data or {},
                        'created_at': time(),
                    })

                    return Response({
                        'status': 'pending_auth',
                        'session_token': session_token,
                        'message': 'Two-factor authentication required',
                        'two_fa_type': auth_result.two_fa_type,
                        'challenge': auth_result.challenge_data,
                    })
                return Response(
                    {'error': auth_result.error_message or 'Authentication failed'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Auth succeeded — discover accounts and fetch balances
            accounts = integration.get_accounts()

            account_list = []
            for a in accounts:
                entry = {
                    'identifier': a.identifier,
                    'name': a.name,
                    'account_type': a.account_type,
                    'currency': a.currency,
                    'balance': None,
                }
                try:
                    balance_info = integration.get_balance(a.identifier)
                    entry['balance'] = float(balance_info.balance)
                    entry['currency'] = balance_info.currency
                    entry['balance_date'] = balance_info.balance_date.isoformat()
                except Exception as e:
                    logger.warning(f"Failed to fetch balance for {a.identifier}: {e}")
                account_list.append(entry)

            integration.close()

            return Response({
                'status': 'success',
                'accounts': account_list,
            })

        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response(
                {'error': f'Discovery failed: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class BrokerDiscoverCompleteAuthView(APIView):
    """Complete 2FA authentication for broker discovery."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        session_token = request.data.get('session_token')
        auth_code = request.data.get('auth_code')

        if not session_token:
            return Response(
                {'error': 'session_token is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get the stored session from file
        session = _get_session(session_token)

        if not session:
            return Response(
                {'error': 'Session expired or invalid. Please restart discovery.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check if session is expired
        if time() - session.get('created_at', 0) > DISCOVERY_SESSION_TIMEOUT:
            integration = session.get('integration')
            if integration:
                try:
                    integration.close()
                except Exception:
                    pass
            _delete_session(session_token)
            return Response(
                {'error': 'Session expired. Please restart discovery.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        integration = session.get('integration')
        session_data = session.get('session_data', {})

        if not integration:
            _delete_session(session_token)
            return Response(
                {'error': 'Invalid session. Please restart discovery.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Complete 2FA
            auth_result = integration.complete_2fa(auth_code, session_data)

            if not auth_result.success:
                if auth_result.requires_2fa:
                    # Still needs 2FA (e.g., waiting for app approval)
                    return Response({
                        'status': 'pending_auth',
                        'session_token': session_token,
                        'message': auth_result.error_message or 'Still waiting for authentication',
                        'two_fa_type': auth_result.two_fa_type,
                        'challenge': auth_result.challenge_data,
                    })
                return Response(
                    {'error': auth_result.error_message or 'Authentication failed'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Auth succeeded — discover accounts and fetch balances
            accounts = integration.get_accounts()

            account_list = []
            for a in accounts:
                entry = {
                    'identifier': a.identifier,
                    'name': a.name,
                    'account_type': a.account_type,
                    'currency': a.currency,
                    'balance': None,
                }
                try:
                    balance_info = integration.get_balance(a.identifier)
                    entry['balance'] = float(balance_info.balance)
                    entry['currency'] = balance_info.currency
                    entry['balance_date'] = balance_info.balance_date.isoformat()
                except Exception as e:
                    logger.warning(f"Failed to fetch balance for {a.identifier}: {e}")
                account_list.append(entry)

            # Cleanup session
            _delete_session(session_token)
            integration.close()

            return Response({
                'status': 'success',
                'accounts': account_list,
            })

        except Exception as e:
            logger.exception("Discovery 2FA completion failed")
            # Cleanup on error
            _delete_session(session_token)
            try:
                integration.close()
            except Exception:
                pass
            return Response(
                {'error': f'Authentication failed: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class BulkAccountCreateView(KEKAuthenticationMixin, APIView):
    """Create multiple accounts for a broker with shared credentials."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from brokers.models import Broker

        broker_code = request.data.get('broker_code')
        credentials = request.data.get('credentials')
        accounts_data = request.data.get('accounts', [])

        if not broker_code or not accounts_data:
            return Response(
                {'error': 'broker_code and accounts are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            broker = Broker.objects.get(code=broker_code, is_active=True)
        except Broker.DoesNotExist:
            return Response(
                {'error': f'Broker "{broker_code}" not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Strip out one-time codes before storing (they expire quickly)
        # Permanent tokens like 'flex_token' are kept, while 'token' is a generic one-time code
        one_time_fields = ('token', 'totp_token', 'otp', 'tan', 'sms_code')
        stored_credentials = {k: v for k, v in (credentials or {}).items()
                             if k not in one_time_fields}
        encrypted = self.encrypt_account_credentials(
            request, stored_credentials
        ) if stored_credentials else None

        user_profile = request.user.profile
        base_currency = user_profile.base_currency

        created = []
        for acct in accounts_data:
            account = FinancialAccount.objects.create(
                user=request.user,
                broker=broker,
                name=acct.get('name', ''),
                account_identifier=acct.get('identifier', ''),
                account_type=acct.get('account_type', 'checking'),
                currency=acct.get('currency', 'EUR'),
                is_manual=False,
                encrypted_credentials=encrypted,
                sync_enabled=True,
            )

            # Create initial snapshot if balance was provided
            balance_value = acct.get('balance')
            if balance_value is not None:
                snapshot_currency = acct.get('currency', 'EUR')
                # Use balance_date from discovery if provided, otherwise today
                balance_date_str = acct.get('balance_date')
                if balance_date_str:
                    snapshot_date = date.fromisoformat(balance_date_str)
                else:
                    snapshot_date = date.today()
                snapshot = AccountSnapshot.objects.create(
                    account=account,
                    balance=Decimal(str(balance_value)),
                    currency=snapshot_currency,
                    snapshot_date=snapshot_date,
                    snapshot_source='auto',
                )
                # Convert to base currency
                if snapshot_currency != base_currency:
                    rate = ExchangeRate.get_rate(
                        snapshot_currency, base_currency, snapshot.snapshot_date
                    )
                    if rate:
                        snapshot.balance_base_currency = snapshot.balance * rate
                        snapshot.base_currency = base_currency
                        snapshot.exchange_rate_used = rate
                        snapshot.save()

                account.status = 'active'
                account.last_sync_at = timezone.now()
                account.save()

            created.append({
                'id': account.id,
                'name': account.name,
                'identifier': account.account_identifier,
                'account_type': account.account_type,
                'currency': account.currency,
                'balance': balance_value,
            })

        return Response({
            'status': 'success',
            'message': f'Created {len(created)} accounts',
            'accounts': created,
        }, status=status.HTTP_201_CREATED)


class CSVImportView(APIView):
    """Import snapshots from a CSV file."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        Import CSV data into an account.

        Expected CSV format:
            date,balance,currency
            2025-01-26,77047,CHF

        Request body:
            - account_id: ID of the account to import into
            - csv_data: CSV content as string
            - skip_duplicates: bool (default True)
        """
        import csv
        from datetime import datetime
        from io import StringIO

        account_id = request.data.get('account_id')
        csv_data = request.data.get('csv_data')
        skip_duplicates = request.data.get('skip_duplicates', True)

        if not account_id:
            return Response(
                {'error': 'account_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not csv_data:
            return Response(
                {'error': 'csv_data is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            account = FinancialAccount.objects.get(pk=account_id, user=request.user)
        except FinancialAccount.DoesNotExist:
            return Response(
                {'error': 'Account not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Parse CSV
        reader = csv.DictReader(StringIO(csv_data))
        required_fields = {'date', 'balance', 'currency'}

        if not required_fields.issubset(set(reader.fieldnames or [])):
            return Response(
                {'error': f'CSV must have columns: {", ".join(required_fields)}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        imported = 0
        skipped = 0
        errors = []
        base_currency = request.user.profile.base_currency

        for row_num, row in enumerate(reader, start=2):
            try:
                # Parse date
                date_str = row['date'].strip()
                try:
                    snapshot_date = datetime.strptime(date_str, '%Y-%m-%d').date()
                except ValueError:
                    errors.append(f'Row {row_num}: Invalid date format "{date_str}"')
                    continue

                # Parse balance
                balance_str = row['balance'].strip().replace(',', '').replace("'", '')
                try:
                    balance = Decimal(balance_str)
                except:
                    errors.append(f'Row {row_num}: Invalid balance "{row["balance"]}"')
                    continue

                currency = row['currency'].strip().upper()

                # Check for duplicate
                existing = AccountSnapshot.objects.filter(
                    account=account,
                    snapshot_date=snapshot_date,
                ).first()

                if existing:
                    if skip_duplicates:
                        skipped += 1
                        continue
                    else:
                        # Update existing
                        existing.balance = balance
                        existing.currency = currency
                        existing.save()
                        imported += 1
                else:
                    # Create new snapshot (imported = manual)
                    snapshot = AccountSnapshot.objects.create(
                        account=account,
                        snapshot_date=snapshot_date,
                        balance=balance,
                        currency=currency,
                        snapshot_source='manual',
                    )

                    # Convert to base currency if needed
                    if currency != base_currency:
                        from exchange_rates.services import ExchangeRateService
                        rate = ExchangeRateService.get_rate(currency, base_currency, snapshot_date)
                        if rate and rate != Decimal('1.0'):
                            snapshot.balance_base_currency = balance * rate
                            snapshot.base_currency = base_currency
                            snapshot.exchange_rate_used = rate
                            snapshot.save()
                    else:
                        snapshot.balance_base_currency = balance
                        snapshot.base_currency = base_currency
                        snapshot.exchange_rate_used = Decimal('1')
                        snapshot.save()

                    imported += 1

            except Exception as e:
                errors.append(f'Row {row_num}: {str(e)}')

        return Response({
            'status': 'success',
            'imported': imported,
            'skipped': skipped,
            'errors': errors[:10] if errors else [],
            'total_errors': len(errors),
        })
