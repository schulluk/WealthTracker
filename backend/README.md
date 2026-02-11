# Wealth Tracker Backend

Django REST Framework backend for the Wealth Tracker application.

## Architecture

### Apps

#### `accounts`
User authentication and profiles.

- **Models**: `UserProfile`
- **Endpoints**: `/api/auth/*`, `/api/profile/`

#### `brokers`
Broker definitions and integrations.

- **Models**: `Broker`
- **Endpoints**: `/api/brokers/`
- **Integrations**: `brokers/integrations/`

#### `portfolio`
Financial accounts, snapshots, and positions.

- **Models**: `FinancialAccount`, `AccountSnapshot`, `PortfolioPosition`
- **Endpoints**: `/api/accounts/`, `/api/wealth/*`

#### `exchange_rates`
Currency conversion service.

- **Models**: `ExchangeRate`
- **Endpoints**: `/api/exchange-rates/`
- **Service**: Frankfurter API integration

### Core Utilities

#### `core/user_encryption.py`
Per-user encryption for broker credentials using Argon2id key derivation.

Credentials are encrypted with a per-user key, which is itself encrypted with a KEK
(Key Encryption Key) derived from the user's password. The password never leaves the
client device - only a derived auth_hash is sent for authentication.

```python
from core.kek_auth import KEKAuthenticationMixin

# In views that need to handle credentials
class MyView(KEKAuthenticationMixin, APIView):
    def post(self, request):
        # Encrypt credentials using user's KEK from request header
        encrypted = self.encrypt_account_credentials(request, credentials_dict)

        # Decrypt credentials
        credentials = self.decrypt_account_credentials(request, account)
```

## Data Models

### UserProfile
```python
user: User (OneToOne)
base_currency: str  # EUR, USD, CHF, GBP
auto_sync_enabled: bool
sync_frequency_hours: int
```

### Broker
```python
code: str           # dkb, commerzbank, etc.
name: str
integration_type: str  # fints, rest, graphql
bank_identifier: str   # BLZ for German banks
fints_server: str
api_base_url: str
credential_schema: dict  # JSON schema for required credentials
```

### FinancialAccount
```python
user: User
broker: Broker
name: str
account_identifier: str  # IBAN or account number
account_type: str        # checking, savings, brokerage, retirement
currency: str
encrypted_credentials: bytes
status: str              # active, inactive, error, pending_auth
is_manual: bool
```

### AccountSnapshot
```python
account: FinancialAccount
balance: Decimal
currency: str
balance_base_currency: Decimal  # Converted amount
exchange_rate_used: Decimal
snapshot_date: date
snapshot_source: str  # auto, manual, import
raw_data: dict        # Full broker response
```

### PortfolioPosition
```python
snapshot: AccountSnapshot
symbol: str
isin: str
name: str
quantity: Decimal
price_per_unit: Decimal
market_value: Decimal
currency: str
cost_basis: Decimal
asset_class: str  # equity, fixed_income, cash, etc.
```

### ExchangeRate
```python
from_currency: str
to_currency: str
rate: Decimal
rate_date: date
source: str  # frankfurter
```

## Broker Integrations

### Base Interface

All broker integrations implement `BrokerIntegrationBase`:

```python
class BrokerIntegrationBase(ABC):
    def authenticate(self) -> AuthResult
    def complete_2fa(self, auth_code, session_data) -> AuthResult
    def get_accounts(self) -> List[AccountInfo]
    def get_balance(self, account_identifier) -> BalanceInfo
    def get_positions(self, account_identifier) -> List[PositionInfo]
    def close()
```

### FinTS Integration

For German banks (DKB, Commerzbank):

```python
from brokers.integrations import get_broker_integration

integration = get_broker_integration(broker, credentials)
auth_result = integration.authenticate()

if auth_result.requires_2fa:
    # Wait for app approval or get TAN
    auth_result = integration.complete_2fa(tan_code, session_data)

accounts = integration.get_accounts()
balance = integration.get_balance(account.iban)
integration.close()
```

### Adding New Brokers

Follow these steps to add support for a new broker:

#### Step 1: Create Integration Class

Create a new file in `brokers/integrations/` (e.g., `new_broker.py`):

```python
# brokers/integrations/new_broker.py
from datetime import date
from decimal import Decimal
from typing import Any, Dict, List, Optional

from .base import (
    BrokerIntegrationBase,
    AuthResult,
    AccountInfo,
    BalanceInfo,
    PositionInfo,
)


class NewBrokerIntegration(BrokerIntegrationBase):
    """Integration for New Broker."""

    def authenticate(self) -> AuthResult:
        """
        Authenticate with the broker API.

        Returns:
            AuthResult with success=True, or requires_2fa=True if 2FA needed.
        """
        username = self.credentials.get('username')
        password = self.credentials.get('password')

        # Implement your authentication logic here
        # ...

        return AuthResult(success=True)

    def complete_2fa(
        self,
        auth_code: Optional[str],
        session_data: Dict[str, Any]
    ) -> AuthResult:
        """
        Complete 2FA authentication.

        For app-based approval (decoupled), auth_code may be None.
        For SMS/TAN codes, auth_code contains the user-entered code.
        """
        # Implement 2FA verification if broker requires it
        return AuthResult(success=True)

    def get_accounts(self) -> List[AccountInfo]:
        """Fetch list of accounts from the broker."""
        # Return list of AccountInfo objects
        return [
            AccountInfo(
                identifier='account-123',
                name='Main Account',
                account_type='brokerage',  # checking, savings, brokerage, retirement
                currency='EUR',
            )
        ]

    def get_balance(self, account_identifier: str) -> BalanceInfo:
        """Fetch current balance for an account."""
        # Fetch and return balance
        return BalanceInfo(
            balance=Decimal('10000.00'),
            currency='EUR',
            balance_date=date.today(),
            raw_data={'original': 'response'},  # Store full API response
        )

    def get_positions(self, account_identifier: str) -> List[PositionInfo]:
        """Fetch positions for investment accounts (optional)."""
        return [
            PositionInfo(
                symbol='AAPL',
                name='Apple Inc.',
                quantity=Decimal('10'),
                price_per_unit=Decimal('150.00'),
                market_value=Decimal('1500.00'),
                currency='USD',
                isin='US0378331005',
                asset_class='equity',  # equity, fixed_income, cash, crypto, etc.
            )
        ]

    def supports_historical_data(self) -> bool:
        """Return True if broker provides historical balance data."""
        return False

    def get_historical_balances(
        self,
        account_identifier: str,
        start_date: date,
        end_date: date
    ) -> List[BalanceInfo]:
        """Fetch historical balances (optional, override if supported)."""
        return []
```

#### Step 2: Register in Factory

Add your broker to `brokers/integrations/__init__.py`:

```python
def get_broker_integration(broker, credentials):
    if broker.code == 'new_broker':
        from .new_broker import NewBrokerIntegration
        return NewBrokerIntegration(credentials)
    # ... existing brokers ...
```

#### Step 3: Add Broker Fixture

Add the broker definition to `brokers/fixtures/initial_brokers.json`:

```json
{
  "model": "brokers.broker",
  "pk": 8,
  "fields": {
    "code": "new_broker",
    "name": "New Broker Name",
    "integration_type": "rest",
    "bank_identifier": "",
    "fints_server": "",
    "api_base_url": "https://api.newbroker.com",
    "logo_url": "",
    "website_url": "https://www.newbroker.com",
    "country": "US",
    "is_active": true,
    "supports_2fa": true,
    "supports_auto_sync": true,
    "credential_schema": {
      "type": "object",
      "required": ["username", "password"],
      "properties": {
        "username": {
          "type": "string",
          "title": "Username",
          "description": "Your login username"
        },
        "password": {
          "type": "string",
          "title": "Password",
          "format": "password",
          "description": "Your account password"
        },
        "totp_secret": {
          "type": "string",
          "title": "TOTP Secret (optional)",
          "format": "password",
          "description": "Base32 secret for 2FA (if applicable)"
        }
      },
      "description": "Optional: Add usage instructions here"
    },
    "created_at": "2026-01-20T00:00:00Z",
    "updated_at": "2026-01-20T00:00:00Z"
  }
}
```

#### Step 4: Load Fixture

```bash
python manage.py loaddata initial_brokers
```

### Broker Configuration Reference

#### Broker Model Fields

| Field | Description |
|-------|-------------|
| `code` | Unique identifier (lowercase, no spaces) |
| `name` | Display name shown to users |
| `integration_type` | `fints` (German banks), `rest`, `graphql` |
| `bank_identifier` | BLZ for German banks, empty otherwise |
| `fints_server` | FinTS server URL (German banks only) |
| `api_base_url` | Base URL for REST/GraphQL APIs |
| `country` | ISO country code (DE, US, CH, etc.) |
| `is_active` | Whether broker is available to users |
| `supports_2fa` | Whether 2FA is required/supported |
| `supports_auto_sync` | Whether automatic sync is possible |
| `credential_schema` | JSON Schema defining required credentials |

#### Credential Schema

The `credential_schema` uses JSON Schema to define what credentials are needed:

```json
{
  "type": "object",
  "required": ["username", "password"],
  "properties": {
    "username": {
      "type": "string",
      "title": "Display Label",
      "description": "Help text for users"
    },
    "password": {
      "type": "string",
      "format": "password",
      "title": "Password"
    }
  },
  "description": "Overall instructions shown to users"
}
```

**Supported `format` values:**
- `password` - Masks input in the UI
- (no format) - Plain text input

#### Integration Types

| Type | Use Case | Example |
|------|----------|---------|
| `fints` | German banks using FinTS/HBCI protocol | DKB, Commerzbank |
| `rest` | Standard REST APIs | TrueWealth, VIAC, IBKR |
| `graphql` | GraphQL APIs | Morgan Stanley |

### Data Classes Reference

```python
@dataclass
class AccountInfo:
    identifier: str      # IBAN, account number, or external ID
    name: str            # Account name/description
    account_type: str    # checking, savings, brokerage, retirement
    currency: str        # ISO 4217 currency code

@dataclass
class BalanceInfo:
    balance: Decimal
    currency: str
    balance_date: date
    available_balance: Optional[Decimal] = None
    raw_data: Optional[Dict[str, Any]] = None

@dataclass
class PositionInfo:
    symbol: str
    name: str
    quantity: Decimal
    price_per_unit: Decimal
    market_value: Decimal
    currency: str
    isin: Optional[str] = None
    cost_basis: Optional[Decimal] = None
    asset_class: str = 'other'  # equity, fixed_income, cash, crypto, etc.

@dataclass
class AuthResult:
    success: bool
    requires_2fa: bool = False
    two_fa_type: Optional[str] = None  # 'app', 'sms', 'tan'
    session_data: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None
    challenge_data: Optional[Dict[str, Any]] = None
```

## API Authentication

Uses JWT (JSON Web Tokens) via `djangorestframework-simplejwt`.

```bash
# Get tokens
POST /api/auth/login/
{"username": "user", "password": "pass"}
# Returns: {"access": "...", "refresh": "..."}

# Use access token
GET /api/accounts/
Authorization: Bearer <access_token>

# Refresh token
POST /api/auth/refresh/
{"refresh": "<refresh_token>"}
```

## Management Commands

```bash
# Run migrations
python manage.py migrate

# Load broker fixtures
python manage.py loaddata initial_brokers

# Create superuser
python manage.py createsuperuser

# Shell with auto-imports
python manage.py shell

# Check for issues
python manage.py check
```

### Exchange Rates

```bash
# Fetch today's exchange rates (also fixes missing snapshot conversions)
python manage.py fetch_exchange_rates

# Fetch rates for a specific date
python manage.py fetch_exchange_rates --date 2024-01-15

# Backfill historical rates
python manage.py fetch_exchange_rates --backfill --start 2024-01-01 --end 2024-06-30

# Skip auto-fixing missing conversions
python manage.py fetch_exchange_rates --skip-conversions
```

### Snapshot Maintenance

```bash
# Fix snapshots missing base currency conversions
python manage.py fix_missing_conversions

# Preview without making changes
python manage.py fix_missing_conversions --dry-run

# Limit to N snapshots
python manage.py fix_missing_conversions --limit 50

# Backfill historical snapshot data for all accounts
python manage.py backfill_snapshots

# Send weekly wealth report emails
python manage.py send_wealth_report
```

## Testing

```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test accounts
python manage.py test brokers
python manage.py test portfolio

# With coverage
coverage run manage.py test
coverage report
```
