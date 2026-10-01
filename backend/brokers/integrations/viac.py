"""
VIAC integration.

VIAC is a Swiss digital pension (Pillar 3a) provider.
This integration uses their internal web API endpoints.

Authentication flow:
1. Get initial cookies from /
2. Login with username and password (no 2FA required typically)
3. Use session to fetch wealth summary

Note: VIAC uses CSRF tokens with a custom header format (x-csrft759).
"""
import logging
import re
from datetime import date
from decimal import Decimal, InvalidOperation
from typing import Any, Dict, List, Optional

import requests

from .base import (
    AccountInfo,
    AuthResult,
    BalanceInfo,
    BrokerIntegrationBase,
    PositionInfo,
)

logger = logging.getLogger(__name__)


def _describe(value: Any) -> str:
    """Say what VIAC sent where a number was expected, for the sync error."""
    if isinstance(value, dict):
        return f"an object ({', '.join(sorted(value))})"
    if isinstance(value, str):
        return f"text ({value[:40]!r})"
    return f"a {type(value).__name__}"


class VIACIntegration(BrokerIntegrationBase):
    """
    Integration for VIAC Swiss pension (Pillar 3a) provider.

    Requires:
    - username (email)
    - password
    """

    BASE_URL = "https://app.viac.ch"

    def __init__(self, credentials: Dict[str, Any]):
        super().__init__(credentials)
        self.username = credentials.get('username')
        self.password = credentials.get('password')
        self._session = requests.Session()
        self._setup_session()
        self._authenticated = False
        self._csrf_token: Optional[str] = None
        self._wealth_data: Optional[Dict] = None

    def _setup_session(self):
        """Configure session with required headers."""
        self._session.headers.update({
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'en-US,en;q=0.9',
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            'DNT': '1',
            'Sec-Ch-Ua': '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"macOS"',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
            'X-Same-Domain': '1',
        })

    def _get_initial_cookies(self) -> bool:
        """Fetch initial cookies including CSRF token."""
        try:
            response = self._session.get(
                f"{self.BASE_URL}/",
                headers={
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
                    'Sec-Fetch-Dest': 'document',
                    'Sec-Fetch-Mode': 'navigate',
                    'Sec-Fetch-Site': 'same-origin',
                    'Sec-Fetch-User': '?1',
                    'Upgrade-Insecure-Requests': '1',
                },
                timeout=30
            )
            response.raise_for_status()

            # Extract CSRF token from cookies
            # VIAC uses cookies like CSRFT759-S
            for cookie in self._session.cookies:
                if 'CSRFT' in cookie.name.upper():
                    self._csrf_token = cookie.value
                    # Extract the token number for the header name
                    match = re.search(r'CSRFT(\d+)', cookie.name.upper())
                    if match:
                        self._csrf_header = f'x-csrft{match.group(1)}'
                    else:
                        self._csrf_header = 'x-csrft759'
                    break

            if not self._csrf_token:
                # Try to find it in the response
                self._csrf_token = ''
                self._csrf_header = 'x-csrft759'

            return True
        except Exception as e:
            logger.error(f"Failed to get initial cookies: {e}")
            return False

    def authenticate(self) -> AuthResult:
        """
        Authenticate with VIAC.

        Requires username and password.
        """
        if not self.username or not self.password:
            return AuthResult(
                success=False,
                error_message="Username and password are required."
            )

        # VIAC expects phone number in international format (+41...)
        if self.username.startswith('0'):
            return AuthResult(
                success=False,
                error_message="Please use international format for phone number (e.g., +41791234567 instead of 0791234567)."
            )

        # Get initial cookies
        if not self._get_initial_cookies():
            return AuthResult(
                success=False,
                error_message="Failed to initialize session with VIAC."
            )

        return self._do_login()

    def _do_login(self) -> AuthResult:
        """Perform the actual login with credentials."""
        try:
            headers = {
                'Accept': 'application/json, text/plain, */*',
                'Content-Type': 'application/json',
                'Referer': f"{self.BASE_URL}/",
                'X-Same-Domain': '1',
            }

            if self._csrf_token:
                headers[self._csrf_header] = self._csrf_token

            login_payload = {'username': self.username, 'password': self.password}

            response = self._session.post(
                f"{self.BASE_URL}/external-login/public/authentication/password/check/",
                json=login_payload,
                headers=headers,
                timeout=30
            )

            logger.info(f"VIAC login response: status={response.status_code}")

            if response.status_code == 200:
                self._authenticated = True
                return AuthResult(success=True)

            elif response.status_code == 401:
                error_data = response.json() if response.text else {}
                error_msg = error_data.get('message', 'Invalid credentials.')
                return AuthResult(
                    success=False,
                    error_message=error_msg
                )

            elif response.status_code == 403:
                # May need 2FA or account locked
                error_data = response.json() if response.text else {}
                if 'two' in str(error_data).lower() or '2fa' in str(error_data).lower():
                    return AuthResult(
                        success=False,
                        requires_2fa=True,
                        two_fa_type='app',
                        error_message="Two-factor authentication required."
                    )
                return AuthResult(
                    success=False,
                    error_message=error_data.get('message', 'Access denied.')
                )

            else:
                # Log response body for debugging
                try:
                    error_data = response.json()
                    logger.error(f"VIAC login failed: status={response.status_code}, body={error_data}")

                    # VIAC uses JSON:API error format with 'errors' array
                    if 'errors' in error_data and error_data['errors']:
                        error_code = error_data['errors'][0].get('code', '')
                        if error_code == 'USERNAME_PASSWORD_WRONG':
                            error_msg = 'Invalid username or password.'
                        else:
                            error_msg = error_code or str(error_data['errors'][0])
                    else:
                        error_msg = error_data.get('message', error_data.get('error', str(error_data)))
                except Exception:
                    error_msg = response.text[:200] if response.text else 'Unknown error'
                    logger.error(f"VIAC login failed: status={response.status_code}, body={error_msg}")
                return AuthResult(
                    success=False,
                    error_message=f"Login failed: {error_msg}"
                )

        except requests.RequestException as e:
            logger.error(f"Login request failed: {e}")
            return AuthResult(
                success=False,
                error_message=f"Connection error: {str(e)}"
            )

    def complete_2fa(
        self,
        auth_code: Optional[str],
        session_data: Dict[str, Any]
    ) -> AuthResult:
        """
        Complete 2FA if required.

        VIAC typically doesn't require 2FA for web login,
        but this is here for compatibility.
        """
        if not auth_code:
            return AuthResult(
                success=False,
                error_message="Authentication code is required."
            )

        # Re-initialize if needed
        if not self._csrf_token:
            self._get_initial_cookies()

        # Try to complete 2FA - endpoint may vary
        try:
            headers = {
                'Content-Type': 'application/json',
                'Referer': f"{self.BASE_URL}/",
            }
            if self._csrf_token:
                headers[self._csrf_header] = self._csrf_token

            response = self._session.post(
                f"{self.BASE_URL}/external-login/public/authentication/2fa/verify/",
                json={'code': auth_code},
                headers=headers,
                timeout=30
            )

            if response.status_code == 200:
                self._authenticated = True
                return AuthResult(success=True)
            else:
                return AuthResult(
                    success=False,
                    error_message="2FA verification failed."
                )

        except Exception as e:
            return AuthResult(
                success=False,
                error_message=f"2FA verification error: {str(e)}"
            )

    def _fetch_wealth_summary(self) -> Dict[str, Any]:
        """Fetch the wealth summary from VIAC."""
        try:
            headers = {
                'Accept': 'application/json',
                'Referer': f"{self.BASE_URL}/",
            }

            response = self._session.get(
                f"{self.BASE_URL}/rest/web/wealth/summary",
                headers=headers,
                timeout=30
            )
            response.raise_for_status()

            return response.json()

        except requests.RequestException as e:
            logger.error(f"Failed to fetch wealth summary: {e}")
            raise RuntimeError(f"Failed to fetch wealth summary: {str(e)}")

    def get_accounts(self) -> List[AccountInfo]:
        """Fetch list of accounts (portfolios) from VIAC."""
        if not self._authenticated:
            result = self.authenticate()
            if not result.success:
                raise RuntimeError(result.error_message)

        # Fetch wealth data to discover accounts
        if not self._wealth_data:
            self._wealth_data = self._fetch_wealth_summary()

        accounts = []

        # VIAC typically has multiple portfolios (e.g., 3a accounts)
        portfolios = self._wealth_data.get('portfolios', [])
        if portfolios:
            for portfolio in portfolios:
                portfolio_id = str(portfolio.get('id', portfolio.get('portfolioId', '')))
                accounts.append(AccountInfo(
                    identifier=portfolio_id,
                    name=portfolio.get('name', f'VIAC Portfolio {portfolio_id}'),
                    account_type='retirement',  # Pillar 3a is retirement savings
                    currency=portfolio.get('currency', 'CHF')
                ))
        else:
            # Single account structure
            accounts.append(AccountInfo(
                identifier='main',
                name='VIAC Pillar 3a',
                account_type='retirement',
                currency='CHF'
            ))

        return accounts

    def get_balance(self, account_identifier: str) -> BalanceInfo:
        """
        Fetch account balance (total value).

        Uses the wealth/summary endpoint which returns totalValue.
        """
        if not self._authenticated:
            result = self.authenticate()
            if not result.success:
                raise RuntimeError(result.error_message)

        # Fetch fresh wealth data
        self._wealth_data = self._fetch_wealth_summary()

        # Extract total value. No default: a missing total must fail the sync,
        # not be recorded as a 0 balance.
        total_value = self._wealth_data.get('totalValue')
        currency = self._wealth_data.get('currency', 'CHF')

        # If we have multiple portfolios, try to find the specific one
        portfolios = self._wealth_data.get('portfolios', [])
        for portfolio in portfolios:
            portfolio_id = str(portfolio.get('id', portfolio.get('portfolioId', '')))
            if portfolio_id == account_identifier:
                total_value = portfolio.get('value', portfolio.get('totalValue', total_value))
                currency = portfolio.get('currency', currency)
                break

        return BalanceInfo(
            balance=self._balance_amount(total_value),
            currency=currency,
            balance_date=date.today(),
            raw_data=self._wealth_data
        )

    def _balance_amount(self, value: Any) -> Decimal:
        """Convert the reported total to a Decimal, or fail the sync saying what
        VIAC sent instead. The log line lists the summary's field types (no
        amounts) so a changed API shape can be read straight from the logs."""
        if isinstance(value, (int, float, str)) and not isinstance(value, bool):
            try:
                return Decimal(str(value))
            except InvalidOperation:
                pass
        logger.warning(
            "VIAC wealth summary has no numeric total; field types: %s",
            {key: type(field).__name__ for key, field in self._wealth_data.items()},
        )
        if value is None:
            reason = "VIAC returned no total value."
        else:
            reason = f"VIAC returned the total as {_describe(value)} instead of a number."
        raise RuntimeError(f"{reason} Its API may have changed.")

    def get_positions(self, account_identifier: str) -> List[PositionInfo]:
        """
        Fetch portfolio positions/holdings.

        VIAC invests in ETFs based on user's strategy selection.
        """
        if not self._authenticated:
            result = self.authenticate()
            if not result.success:
                raise RuntimeError(result.error_message)

        positions = []

        try:
            # Try to get detailed holdings
            headers = {
                'Accept': 'application/json',
                'Referer': f"{self.BASE_URL}/",
            }

            # Try portfolio-specific endpoint
            response = self._session.get(
                f"{self.BASE_URL}/rest/web/portfolio/{account_identifier}/positions",
                headers=headers,
                timeout=30
            )

            if response.status_code == 200:
                data = response.json()
                holdings = data if isinstance(data, list) else data.get('positions', data.get('holdings', []))

                for holding in holdings:
                    positions.append(self._parse_holding(holding))

        except Exception as e:
            logger.warning(f"Failed to fetch positions: {e}")

            # Try to extract from wealth summary
            if self._wealth_data:
                allocations = self._wealth_data.get('allocations', self._wealth_data.get('holdings', []))
                for alloc in allocations:
                    positions.append(self._parse_holding(alloc))

        return positions

    def _parse_holding(self, holding: Dict) -> PositionInfo:
        """Parse a holding into PositionInfo."""
        quantity = holding.get('quantity', holding.get('units', holding.get('shares', 0)))
        price = holding.get('price', holding.get('pricePerUnit', holding.get('nav', 0)))
        market_value = holding.get('value', holding.get('marketValue', 0))

        # If we don't have market_value but have quantity and price
        if not market_value and quantity and price:
            market_value = float(quantity) * float(price)

        # Determine asset class based on VIAC's typical holdings
        asset_type = holding.get('assetClass', holding.get('type', '')).lower()
        asset_class_map = {
            'equity': 'equity',
            'stock': 'equity',
            'shares': 'equity',
            'bond': 'fixed_income',
            'bonds': 'fixed_income',
            'fixed income': 'fixed_income',
            'cash': 'cash',
            'real estate': 'real_estate',
            'realestate': 'real_estate',
            'commodity': 'commodity',
            'gold': 'commodity',
            'precious metals': 'commodity',
        }
        asset_class = asset_class_map.get(asset_type, 'other')

        return PositionInfo(
            symbol=holding.get('symbol', holding.get('ticker', holding.get('isin', ''))),
            name=holding.get('name', holding.get('description', '')),
            isin=holding.get('isin'),
            quantity=Decimal(str(quantity)) if quantity else Decimal('0'),
            price_per_unit=Decimal(str(price)) if price else Decimal('0'),
            market_value=Decimal(str(market_value)),
            currency=holding.get('currency', 'CHF'),
            cost_basis=Decimal(str(holding['costBasis'])) if holding.get('costBasis') else None,
            asset_class=asset_class
        )

    def supports_historical_data(self) -> bool:
        """VIAC provides daily wealth history via /rest/web/wealth/summary."""
        return True

    def get_historical_balances(
        self,
        account_identifier: str,
        start_date: date,
        end_date: date
    ) -> List[BalanceInfo]:
        """
        Fetch historical balances from VIAC wealth/summary endpoint.

        Note: This endpoint returns historical data for ALL portfolios combined,
        not per-portfolio. The account_identifier is ignored.
        """
        del account_identifier  # Unused - VIAC returns combined data for all portfolios
        from datetime import datetime

        if not self._authenticated:
            result = self.authenticate()
            if not result.success:
                return []

        try:
            response = self._session.get(
                f"{self.BASE_URL}/rest/web/wealth/summary",
                headers={
                    'Accept': 'application/json',
                    'Referer': f"{self.BASE_URL}/",
                    'X-Same-Domain': '1',
                },
                timeout=30
            )

            if response.status_code != 200:
                logger.debug(f"VIAC wealth/summary not available: {response.status_code}")
                return []

            data = response.json()
            historical = []

            # Parse dailyWealth array: [{date: "YYYY-MM-DD", value: number}, ...]
            daily_wealth = data.get('dailyWealth', [])
            for entry in daily_wealth:
                entry_date = entry.get('date')
                entry_value = entry.get('value')
                if entry_date and entry_value is not None:
                    try:
                        bal_date = datetime.strptime(entry_date[:10], '%Y-%m-%d').date()
                        # Filter by date range
                        if start_date <= bal_date <= end_date:
                            historical.append(BalanceInfo(
                                balance=Decimal(str(entry_value)),
                                currency='CHF',
                                balance_date=bal_date
                            ))
                    except (ValueError, TypeError):
                        continue

            if historical:
                logger.info(f"VIAC: Found {len(historical)} historical entries")
            return historical

        except Exception as e:
            logger.warning(f"Failed to fetch VIAC historical data: {e}")
            return []

    def close(self):
        """Close the session."""
        if self._session:
            try:
                # Try to logout
                self._session.post(
                    f"{self.BASE_URL}/external-login/public/authentication/logout/",
                    headers={self._csrf_header: self._csrf_token} if self._csrf_token else {},
                    timeout=10
                )
            except Exception:
                pass
            self._session.close()
            self._session = None
        self._authenticated = False
        self._csrf_token = None
        self._wealth_data = None
