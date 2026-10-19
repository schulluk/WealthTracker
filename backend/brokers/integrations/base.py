"""
Abstract base class for broker integrations.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal
from typing import Any, Dict, List, Optional


class NoNewDataError(Exception):
    """The broker has no new data to report right now — a benign no-op, not a failure.

    Raised by ``get_balance`` when there is simply nothing new to record (e.g. EBICS
    ``090005 EBICS_NO_DOWNLOAD_DATA_AVAILABLE`` on a quiet day, a weekend, or a period
    whose statement was already fetched). The sync worker treats this as "no change":
    the account stays ``active`` with its last snapshot, ``last_sync_at`` advances, and
    no error is recorded. It must never be surfaced as a sync failure.
    """


@dataclass
class AccountInfo:
    """Standardized account information returned by brokers."""
    identifier: str  # IBAN, account number, or external ID
    name: str  # Account name/description
    account_type: str  # checking, savings, brokerage, etc.
    currency: str  # Account currency (ISO 4217)


@dataclass
class BalanceInfo:
    """Standardized balance information returned by brokers."""
    balance: Decimal
    currency: str
    balance_date: date
    available_balance: Optional[Decimal] = None
    raw_data: Optional[Dict[str, Any]] = None


@dataclass
class PositionInfo:
    """Standardized position information for investment accounts."""
    symbol: str
    name: str
    quantity: Decimal
    price_per_unit: Decimal
    market_value: Decimal
    currency: str
    isin: Optional[str] = None
    cost_basis: Optional[Decimal] = None
    asset_class: str = 'other'


@dataclass
class TransactionInfo:
    """Standardized booking entry (bank transaction) returned by brokers.

    ``amount`` is signed: negative = money left the account. ``external_id`` is the
    bank's own unique reference for the entry (e.g. camt.053 ``AcctSvcrRef``) when it
    provides one — the importer uses it for exact dedup and falls back to a content
    hash otherwise.
    """
    booking_date: date
    amount: Decimal
    currency: str
    value_date: Optional[date] = None
    counterparty: str = ''  # Other party's name (creditor for debits, debtor for credits)
    counterparty_account: str = ''  # Other party's IBAN/account number if reported
    description: str = ''  # Remittance info / purpose text
    external_id: Optional[str] = None
    status: str = 'BOOK'  # ISO entry status: BOOK (booked), PDNG (pending)
    raw_data: Optional[Dict[str, Any]] = None


@dataclass
class AuthResult:
    """Result of authentication attempt."""
    success: bool
    requires_2fa: bool = False
    two_fa_type: Optional[str] = None  # 'app', 'sms', 'tan', etc.
    session_data: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None
    challenge_data: Optional[Dict[str, Any]] = None  # For TAN challenges


class BrokerIntegrationBase(ABC):
    """Abstract base class for broker integrations."""

    def __init__(self, credentials: Dict[str, Any]):
        self.credentials = credentials
        self._session = None

    @abstractmethod
    def authenticate(self) -> AuthResult:
        """
        Authenticate with the broker.
        Returns AuthResult indicating success or if 2FA is needed.
        """
        pass

    @abstractmethod
    def complete_2fa(
        self,
        auth_code: Optional[str],
        session_data: Dict[str, Any]
    ) -> AuthResult:
        """
        Complete 2FA authentication.
        For decoupled auth (app approval), auth_code may be None.
        """
        pass

    @abstractmethod
    def get_accounts(self) -> List[AccountInfo]:
        """
        Fetch list of accounts from the broker.
        Must be authenticated first.
        """
        pass

    @abstractmethod
    def get_balance(self, account_identifier: str) -> BalanceInfo:
        """
        Fetch balance for a specific account.
        Must be authenticated first.
        """
        pass

    def requires_reauth_before_2fa(self) -> bool:
        """Must ``authenticate()`` run again before ``complete_2fa()``?

        True for stateless protocols such as FinTS, where the second request
        rebuilds the dialog from scratch. False where the first call already
        started something the user is responding to — repeating it would send
        a second SMS and invalidate the code they are holding.
        """
        return True

    def supports_positions(self) -> bool:
        """
        Returns True if this integration can fetch per-asset holdings.
        Override in subclasses that implement get_positions().
        """
        return False

    def get_positions(self, account_identifier: str) -> List[PositionInfo]:
        """
        Fetch positions for an investment account.
        Override in subclasses that support this.
        """
        return []

    def supports_transactions(self) -> bool:
        """
        Returns True if this integration can fetch booking entries (transactions).
        Override in subclasses that implement get_transactions().
        """
        return False

    def get_transactions(
        self,
        account_identifier: str,
        start_date: date,
        end_date: date
    ) -> List['TransactionInfo']:
        """
        Fetch booked transactions for an account in the inclusive date range.
        Override in subclasses that support this. Returns empty list by default.
        """
        return []

    def prefetched_transactions_from(self) -> Optional[date]:
        """Start of the window ``get_transactions`` can answer from memory.

        Some brokers hand over a long history in the same session that logs
        in (Swisscard: the session dies within minutes, so a year is pulled
        up front). The importer then stores all of it instead of only the
        days around the newest stored entry — the extra rows cost no request,
        and dedup drops what is already there. None, the default, means the
        integration queries the range it is asked for and the importer keeps
        its narrow window.
        """
        return None

    def get_transactions_for_range(
        self,
        account_identifier: str,
        start_date: date,
        end_date: date
    ) -> List['TransactionInfo']:
        """
        Fetch transactions for an explicit PAST range (history backfill).

        Defaults to ``get_transactions``, which is correct for brokers that
        query the range directly (e.g. FinTS). Override where the normal sync
        reads a pending delivery instead of a queried period (e.g. EBICS, which
        needs a dated download to see anything older than the current delivery).
        """
        return self.get_transactions(account_identifier, start_date, end_date)

    def get_historical_balances(
        self,
        account_identifier: str,
        start_date: date,
        end_date: date
    ) -> List[BalanceInfo]:
        """
        Fetch historical balances for an account.
        Override in subclasses that support historical data (e.g., IBKR Flex).
        Returns empty list by default.
        """
        return []

    def supports_historical_data(self) -> bool:
        """
        Returns True if this integration supports fetching historical data.
        Override in subclasses that support this.
        """
        return False

    def historical_data_requires_extra_request(self) -> bool:
        """
        Returns True if fetching historical data requires an additional API call.
        If False, historical data comes with the main sync (e.g., IBKR Flex report).
        Override in subclasses. Default is True (extra request needed).
        """
        return True

    def close(self):
        """Clean up any resources (sessions, connections)."""
        if self._session:
            self._session = None
