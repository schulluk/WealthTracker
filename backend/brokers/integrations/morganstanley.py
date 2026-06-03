"""
Morgan Stanley at Work integration.

Morgan Stanley at Work is a platform for employee stock plans and equity compensation.
This integration uses their internal web API and GraphQL endpoints.

Authentication flow:
1. Get initial cookies and CSRF token from /solium/servlet/userLogin.do
2. Login with account number and password (form-based) using curl_cffi for TLS impersonation
3. Follow redirects to dashboard
4. Extract JWT token from embedded React app data or API calls
5. Use GraphQL API to fetch portfolio data

Note: Morgan Stanley has strong bot detection. This uses curl_cffi to impersonate
Chrome's TLS fingerprint and carefully replicates browser behavior.
"""
import base64
import json
import logging
import os
import re
from datetime import date
from decimal import Decimal
from typing import Any, Dict, List, Optional

from curl_cffi import requests as curl_requests

from .base import (
    AccountInfo,
    AuthResult,
    BalanceInfo,
    BrokerIntegrationBase,
    PositionInfo,
)

logger = logging.getLogger(__name__)


class MorganStanleyIntegration(BrokerIntegrationBase):
    """
    Integration for Morgan Stanley at Work (employee stock plans).

    Requires:
    - account_number (employee/participant ID)
    - password

    Uses curl_cffi to impersonate Chrome's TLS fingerprint and bypass bot detection.
    """

    BASE_URL = "https://atwork.morganstanley.com"
    GRAPHQL_URL = "https://atwork.morganstanley.com/graphql"

    def __init__(self, credentials: Dict[str, Any], account_id: Any = None):
        super().__init__(credentials)
        self.account_id = account_id
        self.account_number = credentials.get('account_number') or credentials.get('username')
        self.password = credentials.get('password')
        self.totp_secret = credentials.get('totp_secret')
        self.employee_id = credentials.get('employee_id')
        # Whether to count unvested shares in the balance. Default False: only
        # vested value (shares that actually belong to the user).
        self.include_unvested = str(credentials.get('include_unvested', '')).lower() in ('1', 'true', 'yes', 'on')
        # Use curl_cffi session with Chrome impersonation for TLS fingerprint
        self._session = curl_requests.Session(impersonate="chrome")
        self._setup_session()
        self._authenticated = False
        # Support direct JWT token (bypasses login - recommended due to bot detection)
        self._jwt_token: Optional[str] = credentials.get('jwt_token')
        self._portfolio_data: Optional[Dict] = None
        self._login_page: Optional[str] = None
        self._dashboard_page: Optional[str] = None

        # If JWT token provided, we're already authenticated
        if self._jwt_token and self.employee_id:
            self._authenticated = True
            logger.info("Morgan Stanley: Using provided JWT token and employee ID")

    def _setup_session(self):
        """Configure session with required headers."""
        self._session.headers.update({
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
            'DNT': '1',
            'Connection': 'keep-alive',
            'Sec-Ch-Ua': '"Google Chrome";v="143", "Chromium";v="143", "Not A(Brand";v="24"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"macOS"',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
            'Upgrade-Insecure-Requests': '1',
        })

    def _get_initial_cookies(self) -> bool:
        """Fetch initial cookies and login page.

        NOTE: This method is currently unused. Login via username/password is disabled
        because we cannot extract the JWT token programmatically. Kept for potential
        future use if JWT extraction is figured out.
        """
        try:
            response = self._session.get(
                f"{self.BASE_URL}/solium/servlet/userLogin.do",
                timeout=30
            )
            response.raise_for_status()

            # Store the page content for CSRF token extraction if needed
            self._login_page = response.text

            return True
        except Exception as e:
            logger.error(f"Failed to get initial cookies: {e}")
            return False

    def _extract_csrf_token(self) -> Optional[str]:
        """Extract CSRF token from login page if present."""
        if not hasattr(self, '_login_page'):
            return None

        # Look for hidden form fields with CSRF-like names
        patterns = [
            r'name="TO_[^"]+"\s+value="([^"]+)"',
            r'name="_csrf"\s+value="([^"]+)"',
            r'name="csrf_token"\s+value="([^"]+)"',
        ]

        for pattern in patterns:
            match = re.search(pattern, self._login_page)
            if match:
                return match.group(1)

        return None

    def authenticate(self) -> AuthResult:
        """
        Authenticate with Morgan Stanley at Work.

        IMPORTANT: Due to Morgan Stanley's complex authentication, JWT token and
        employee ID must be provided manually. The JWT is generated by frontend
        JavaScript and cannot be obtained programmatically.

        How to get credentials:
        1. Log into atwork.morganstanley.com in your browser
        2. Open DevTools (F12 or Cmd+Option+I)
        3. Go to Network tab
        4. Filter by "graphql"
        5. Click any graphql request
        6. Copy 'authorization' header value → jwt_token
        7. Copy 'employeeid' header value → employee_id

        Note: JWT expires after ~1 hour. Credentials need periodic refresh.
        """
        # Preferred path: full programmatic login in a headless browser using
        # username + password + TOTP seed. Falls through to the manual JWT path
        # if the browser/Playwright isn't available in this environment.
        if self.account_number and self.password and self.totp_secret:
            browser_result = self._browser_authenticate()
            if browser_result is not None:
                return browser_result

        # JWT token and employee_id are required
        if self._jwt_token and self.employee_id:
            self._authenticated = True
            logger.info("Morgan Stanley: Authenticated via JWT token + employee_id")
            return AuthResult(success=True)

        # If JWT provided but no employee_id, provide specific guidance
        if self._jwt_token and not self.employee_id:
            return AuthResult(
                success=False,
                error_message="Employee ID is required. In browser DevTools, find any /graphql "
                             "request and copy the 'employeeid' header value. "
                             "IMPORTANT: This is NOT the same as the JWT's 'sub' claim!"
            )

        # If employee_id provided but no JWT
        if self.employee_id and not self._jwt_token:
            return AuthResult(
                success=False,
                error_message="JWT Token is required. In browser DevTools > Network > filter 'graphql', "
                             "copy the 'authorization' header value (without 'Bearer ' prefix)."
            )

        # Neither provided - give full instructions
        return AuthResult(
            success=False,
            error_message="JWT Token and Employee ID are required. "
                         "To get them: 1) Log into atwork.morganstanley.com in browser, "
                         "2) Open DevTools (F12), 3) Go to Network tab, 4) Filter by 'graphql', "
                         "5) Copy 'authorization' header → JWT Token, "
                         "6) Copy 'employeeid' header → Employee ID. "
                         "Note: JWT expires after ~1 hour."
        )

    def _browser_authenticate(self) -> Optional[AuthResult]:
        """
        Run the headless-browser login (username + password + TOTP seed).

        Returns an AuthResult on a definitive outcome (success or failure), or
        None when the browser path is unavailable so the caller falls back to the
        manual JWT path. On success, sets self._jwt_token + self.employee_id; the
        rest of the integration (GraphQL fetch) then works unchanged.
        """
        from . import morganstanley_browser as msb

        # Route the browser's egress through the user's phone relay (residential
        # IP) when connected. In server mode (datacenter IP, blocked by Akamai)
        # with neither a relay nor an MS_PROXY, skip rather than fail blindly —
        # the app must open the relay first.
        relay_proxy = self._resolve_relay_proxy()
        if (
            os.environ.get("MS_SERVER_MODE") == "1"
            and not relay_proxy
            and not os.environ.get("MS_PROXY")
        ):
            return AuthResult(
                success=False,
                error_message=(
                    "Morgan Stanley sync needs the Wealth app's relay — your phone "
                    "provides the network exit. Open the app and retry the sync."
                ),
            )

        try:
            result = msb.browser_login(
                username=self.account_number,
                password=self.password,
                totp_secret=self.totp_secret,
                state_dir=self._browser_state_dir(),
                account_id=self.account_id,
                proxy=relay_proxy,  # None -> browser_login falls back to MS_PROXY env
            )
        except msb.BrowserLoginUnavailable as exc:
            logger.warning(
                "Morgan Stanley: browser login unavailable (%s); "
                "falling back to manual JWT if provided.", exc,
            )
            return None
        except msb.BrowserLoginError as exc:
            logger.error("Morgan Stanley: browser login failed: %s", exc)
            return AuthResult(success=False, error_message=str(exc))

        self._jwt_token = result['jwt_token']
        self.employee_id = result['employee_id']
        self._authenticated = True
        logger.info(
            "Morgan Stanley: authenticated via headless browser "
            "(employee_id=%s, device-trust persisted=%s)",
            self.employee_id, result.get('state_persisted'),
        )
        return AuthResult(success=True)

    def _resolve_relay_proxy(self) -> Optional[str]:
        """SOCKS proxy for this account owner's phone relay, or None.

        Returns ``socks5://127.0.0.1:<port>`` when the user's relay WebSocket is
        connected (see brokers/ms_relay), so MS sees a residential IP.
        """
        try:
            from brokers.ms_relay.proxy import relay_proxy_for_account
        except Exception:
            return None
        return relay_proxy_for_account(self.account_id)

    @staticmethod
    def _browser_state_dir() -> str:
        """Directory for persisted device-trust state (storage_state per account).

        Override with the MS_BROWSER_STATE_DIR setting/env var to point at a
        persistent volume (recommended for Docker so device-trust survives
        container rebuilds). Defaults to <BASE_DIR>/ms_browser_state.
        """
        from django.conf import settings
        configured = (
            getattr(settings, 'MS_BROWSER_STATE_DIR', None)
            or os.environ.get('MS_BROWSER_STATE_DIR')
        )
        if configured:
            return configured
        return os.path.join(str(getattr(settings, 'BASE_DIR', '.')), 'ms_browser_state')

    def _do_login(self) -> AuthResult:
        """Perform the actual login with credentials.

        NOTE: This method is currently unused. Login via username/password works to
        establish a session and extract employeePK, but we cannot extract the JWT token
        programmatically. Kept for potential future use.
        """
        try:
            # Build form data matching the browser request
            form_data = {
                'state': '',
                'lang': '',
                'browserwidth': '1452',
                'browserheight': '429',
                'screenwidth': '1512',
                'screenheight': '982',
                'requested_lang': 'en',
                'login_method': 'account_number',
                'account_number': self.account_number,
                'account_number_dummy': self.account_number,
                'password': self.password,
                'password_dummy': '',
                'remember': 'true',
            }

            # Add CSRF token if found (format: TO_xxxx=value)
            csrf_token = self._extract_csrf_token()
            if csrf_token:
                # The token name varies - try to find it
                token_match = re.search(r'name="(TO_[^"]+)"', self._login_page)
                if token_match:
                    form_data[token_match.group(1)] = csrf_token

            # Add fingerprints (simplified versions - Morgan Stanley may require these)
            # These are complex browser fingerprints; using minimal placeholders
            form_data['ms_rsa_footprint'] = 'version%3D3.5.1_4'
            form_data['symantec_device_fingerprint'] = ''

            headers = {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Cache-Control': 'max-age=0',
                'Origin': self.BASE_URL,
                'Referer': f"{self.BASE_URL}/solium/servlet/userLogin.do",
                'Sec-Fetch-Dest': 'document',
                'Sec-Fetch-Mode': 'navigate',
                'Sec-Fetch-Site': 'same-origin',
                'Sec-Fetch-User': '?1',
                'Upgrade-Insecure-Requests': '1',
            }

            logger.info(f"Morgan Stanley login attempt to {self.BASE_URL}/solium/servlet/userLogin.do")
            logger.debug(f"Morgan Stanley form data keys: {list(form_data.keys())}")

            response = self._session.post(
                f"{self.BASE_URL}/solium/servlet/userLogin.do",
                data=form_data,
                headers=headers,
                timeout=30,
                allow_redirects=True
            )

            logger.info(f"Morgan Stanley login response: status={response.status_code}, url={response.url}")
            logger.info(f"Morgan Stanley cookies after login: {[(c.name, c.domain) for c in self._session.cookies]}")
            logger.info(f"Morgan Stanley response headers: {dict(response.headers)}")

            # Store dashboard page for JWT extraction attempts
            self._dashboard_page = response.text

            # Log response snippet for debugging
            logger.warning(f"Morgan Stanley response body (first 2000 chars): {response.text[:2000]}")

            # Save full HTML for debugging
            try:
                with open('/tmp/ms_dashboard.html', 'w') as f:
                    f.write(response.text)
                logger.warning(f"Morgan Stanley: Saved full HTML ({len(response.text)} bytes) to /tmp/ms_dashboard.html")
            except Exception as e:
                logger.warning(f"Morgan Stanley: Failed to save HTML: {e}")

            # Look for embedded JSON data or participant info in the full page
            # Search for JSON objects in script tags
            script_data_patterns = [
                r'var\s+(\w+)\s*=\s*(\{[^;]+\});',  # var name = {...};
                r'window\.(\w+)\s*=\s*(\{[^;]+\});',  # window.name = {...};
                r'data-config=["\'](\{[^"\']+\})["\']',  # data-config="{...}"
            ]
            for pattern in script_data_patterns:
                for match in re.finditer(pattern, response.text[:50000]):
                    try:
                        var_name = match.group(1) if match.lastindex >= 1 else 'unknown'
                        json_str = match.group(2) if match.lastindex >= 2 else match.group(1)
                        data = json.loads(json_str)
                        logger.info(f"Morgan Stanley embedded data '{var_name}': {list(data.keys()) if isinstance(data, dict) else type(data)}")
                        # Check for useful fields
                        if isinstance(data, dict):
                            for key in ['token', 'jwt', 'authorization', 'participantId', 'employeeId', 'userId', 'accountId']:
                                if key in data:
                                    logger.info(f"Morgan Stanley found {key} in embedded data: {str(data[key])[:100]}")
                    except Exception:
                        pass

            # Look for participant ID in various formats
            participant_patterns = [
                r'participantId["\s:=]+["\']?(\d+)',
                r'participant_id["\s:=]+["\']?(\d+)',
                r'accountId["\s:=]+["\']?(\d+)',
                r'userId["\s:=]+["\']?(\d+)',
                r'employeeId["\s:=]+["\']?(\d+)',
            ]
            for pattern in participant_patterns:
                match = re.search(pattern, response.text, re.IGNORECASE)
                if match:
                    logger.info(f"Morgan Stanley found ID via pattern '{pattern[:30]}': {match.group(1)}")

            # Check for successful login
            if response.status_code == 200:
                # Look for JWT token in response or cookies
                jwt_token = self._extract_jwt_token(response)

                if jwt_token:
                    self._jwt_token = jwt_token
                    self._authenticated = True

                    # Try to extract employee ID from token
                    self._extract_employee_id_from_jwt()

                    return AuthResult(success=True)

                # Check if 2FA is required
                if 'two-factor' in response.text.lower() or 'verification' in response.text.lower() or 'mfa' in response.url.lower():
                    logger.info("Morgan Stanley 2FA required")
                    return AuthResult(
                        success=False,
                        requires_2fa=True,
                        two_fa_type='app',
                        error_message="Two-factor authentication required. Please complete 2FA in your browser first."
                    )

                # Check for device registration page
                if 'device' in response.text.lower() and 'register' in response.text.lower():
                    logger.info("Morgan Stanley device registration required")
                    return AuthResult(
                        success=False,
                        requires_2fa=True,
                        two_fa_type='device',
                        error_message="Device registration required. Please complete registration in your browser first."
                    )

                # Check for login errors - look for specific error messages
                error_patterns = [
                    r'(invalid\s+(?:account|password|credentials))',
                    r'(incorrect\s+(?:account|password|credentials))',
                    r'(login\s+failed)',
                    r'(authentication\s+failed)',
                ]
                for pattern in error_patterns:
                    match = re.search(pattern, response.text, re.IGNORECASE)
                    if match:
                        logger.error(f"Morgan Stanley login error detected: {match.group(1)}")
                        logger.error(f"Morgan Stanley response snippet: {response.text[:1000]}")
                        return AuthResult(
                            success=False,
                            error_message=f"Login failed: {match.group(1)}"
                        )

                # If we got here but no JWT, login may have partially succeeded
                # Try to get JWT from a token endpoint
                jwt_token = self._try_get_jwt_from_session()
                if jwt_token:
                    self._jwt_token = jwt_token
                    self._extract_employee_id_from_jwt()
                    self._authenticated = True
                    logger.info("Morgan Stanley: Obtained JWT from session endpoint")
                    return AuthResult(success=True)

                # Try to access the dashboard to confirm login worked
                if self._verify_login():
                    self._authenticated = True
                    # Even without JWT, we might be able to use session cookies
                    logger.warning("Morgan Stanley: Login succeeded but no JWT token obtained. GraphQL calls may fail.")
                    return AuthResult(success=True)

                return AuthResult(
                    success=False,
                    error_message="Login appeared to succeed but session not established."
                )

            else:
                return AuthResult(
                    success=False,
                    error_message=f"Login failed with status {response.status_code}"
                )

        except requests.RequestException as e:
            logger.error(f"Login request failed: {e}")
            return AuthResult(
                success=False,
                error_message=f"Connection error: {str(e)}"
            )

    def _extract_jwt_token(self, response) -> Optional[str]:
        """Extract JWT token from response."""
        # Check cookies
        for cookie in self._session.cookies:
            cookie_val = str(cookie.value) if hasattr(cookie, 'value') else str(cookie)
            logger.debug(f"Morgan Stanley cookie: {cookie.name}={cookie_val[:50] if len(cookie_val) > 50 else cookie_val}...")
            if 'jwt' in cookie.name.lower() or 'token' in cookie.name.lower() or 'auth' in cookie.name.lower():
                if cookie_val.startswith('eyJ'):  # JWT header
                    logger.info(f"Found JWT token in cookie: {cookie.name}")
                    return cookie_val

        # Check response headers
        auth_header = response.headers.get('Authorization', '') or response.headers.get('authorization', '')
        if auth_header.startswith('Bearer '):
            logger.info("Found JWT token in Authorization header")
            return auth_header[7:]
        elif auth_header.startswith('eyJ'):
            logger.info("Found JWT token in Authorization header (no Bearer prefix)")
            return auth_header

        # Check response body for token - comprehensive patterns
        response_text = response.text
        token_patterns = [
            # JSON embedded tokens
            (r'"authorization":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'authorization JSON'),
            (r'"token":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'token JSON'),
            (r'"jwt":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'jwt JSON'),
            (r'"accessToken":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'accessToken JSON'),
            (r'"access_token":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'access_token JSON'),
            (r'"idToken":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'idToken JSON'),
            (r'"id_token":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'id_token JSON'),
            # React/Angular state
            (r'window\.__INITIAL_STATE__\s*=\s*.*?"token":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', '__INITIAL_STATE__'),
            (r'window\.__PRELOADED_STATE__\s*=\s*.*?"token":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', '__PRELOADED_STATE__'),
            (r'window\.APP_CONFIG\s*=\s*.*?"token":\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'APP_CONFIG'),
            # Data attributes
            (r'data-token=["\']?(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)["\']?', 'data-token'),
            (r'data-auth=["\']?(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)["\']?', 'data-auth'),
            # Generic JWT pattern (last resort)
            (r'(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,})', 'generic JWT'),
        ]

        for pattern, name in token_patterns:
            match = re.search(pattern, response_text, re.IGNORECASE | re.DOTALL)
            if match:
                token = match.group(1)
                # Validate it looks like a real JWT (not too long, has 3 parts)
                if len(token) < 2000 and token.count('.') == 2:
                    logger.info(f"Found JWT token via pattern: {name}")
                    return token

        # Look for script tags that might contain config with tokens
        script_patterns = [
            r'<script[^>]*>\s*window\.(\w+)\s*=\s*(\{[^<]+\})\s*;?\s*</script>',
            r'<script[^>]*type=["\']application/json["\'][^>]*>(\{[^<]+\})</script>',
        ]
        for pattern in script_patterns:
            for match in re.finditer(pattern, response_text, re.IGNORECASE | re.DOTALL):
                try:
                    json_str = match.group(2) if match.lastindex >= 2 else match.group(1)
                    # Try to parse and find token
                    data = json.loads(json_str)
                    token = self._find_jwt_in_dict(data)
                    if token:
                        logger.info(f"Found JWT in embedded script data")
                        return token
                except (json.JSONDecodeError, Exception):
                    pass

        # Log a snippet of the response for debugging
        logger.warning(f"No JWT token found in response. Length: {len(response_text)}")
        return None

    def _find_jwt_in_dict(self, data: Any, depth: int = 0) -> Optional[str]:
        """Recursively search a dict for JWT tokens."""
        if depth > 5:  # Limit recursion depth
            return None

        if isinstance(data, str):
            if data.startswith('eyJ') and data.count('.') == 2 and len(data) < 2000:
                return data
            return None

        if isinstance(data, dict):
            # Check common token field names first
            for key in ['token', 'jwt', 'authorization', 'accessToken', 'access_token', 'idToken', 'id_token', 'authToken']:
                if key in data:
                    val = data[key]
                    if isinstance(val, str) and val.startswith('eyJ'):
                        return val

            # Also check for employee ID while we're here
            if not self.employee_id:
                for key in ['employeeId', 'employee_id', 'participantId', 'userId', 'user_id']:
                    if key in data:
                        self.employee_id = str(data[key])
                        logger.info(f"Found employee ID in embedded data: {self.employee_id}")

            # Recurse into nested dicts
            for value in data.values():
                result = self._find_jwt_in_dict(value, depth + 1)
                if result:
                    return result

        if isinstance(data, list):
            for item in data:
                result = self._find_jwt_in_dict(item, depth + 1)
                if result:
                    return result

        return None

    def _extract_employee_id_from_jwt(self):
        """Extract employee ID from JWT token payload.

        NOTE: This is only used as a fallback. The user-provided employee_id
        credential takes precedence because the JWT 'sub' claim is often NOT
        the same as the employeeid header value Morgan Stanley expects.
        """
        # Don't overwrite user-provided employee_id - it takes precedence
        if self.employee_id:
            logger.debug(f"Using user-provided employee_id: {self.employee_id}")
            return

        if not self._jwt_token:
            return

        try:
            # JWT format: header.payload.signature
            parts = self._jwt_token.split('.')
            if len(parts) >= 2:
                # Decode payload (add padding if needed)
                payload = parts[1]
                padding = 4 - len(payload) % 4
                if padding != 4:
                    payload += '=' * padding

                decoded = base64.urlsafe_b64decode(payload)
                data = json.loads(decoded)

                # Look for employee ID in common fields (fallback only)
                for field in ['employeeId', 'employee_id', 'userId', 'user_id', 'sub']:
                    if field in data:
                        self.employee_id = str(data[field])
                        logger.info(f"Extracted employee_id from JWT {field}: {self.employee_id}")
                        break

        except Exception as e:
            logger.debug(f"Could not extract employee ID from JWT: {e}")

    def _try_get_jwt_from_session(self) -> Optional[str]:
        """Try to get JWT token from session/auth endpoints after login."""
        # List of potential endpoints that might return a JWT
        token_endpoints = [
            '/solium/servlet/mobileAuth.do',
            '/solium/api/auth/token',
            '/solium/api/session',
            '/solium/servlet/getToken.do',
            '/solium/servlet/apiToken.do',
            '/api/auth/token',
            '/api/v1/auth/token',
            '/oauth/token',
        ]

        for endpoint in token_endpoints:
            try:
                logger.debug(f"Trying token endpoint: {endpoint}")
                response = self._session.get(
                    f"{self.BASE_URL}{endpoint}",
                    timeout=10
                )
                logger.debug(f"Token endpoint {endpoint}: status={response.status_code}")
                if response.status_code == 200:
                    # Check for JWT in response
                    try:
                        data = response.json()
                        logger.debug(f"Token endpoint {endpoint} JSON keys: {list(data.keys()) if isinstance(data, dict) else 'not dict'}")
                        # Look for token in various fields
                        for field in ['token', 'jwt', 'authorization', 'access_token', 'accessToken', 'authToken', 'id_token']:
                            if field in data and str(data[field]).startswith('eyJ'):
                                logger.info(f"Found JWT in {endpoint} response field: {field}")
                                # Also extract employee ID if present
                                if not self.employee_id:
                                    for eid_field in ['employeeId', 'employee_id', 'userId', 'user_id', 'sub', 'participantId']:
                                        if eid_field in data:
                                            self.employee_id = str(data[eid_field])
                                            break
                                return data[field]
                    except Exception:
                        pass
                    # Check raw response for JWT pattern
                    match = re.search(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', response.text)
                    if match:
                        logger.info(f"Found JWT in {endpoint} response body")
                        return match.group(0)
            except Exception as e:
                logger.debug(f"Failed to get JWT from {endpoint}: {e}")
                continue

        # Try POST to token endpoint (some require POST)
        try:
            response = self._session.post(
                f"{self.BASE_URL}/solium/api/auth/token",
                json={},
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            logger.debug(f"POST /solium/api/auth/token: status={response.status_code}")
            if response.status_code == 200:
                try:
                    data = response.json()
                    for field in ['token', 'jwt', 'authorization', 'access_token', 'accessToken']:
                        if field in data and str(data[field]).startswith('eyJ'):
                            logger.info(f"Found JWT via POST token endpoint")
                            return data[field]
                except Exception:
                    pass
        except Exception as e:
            logger.debug(f"POST token endpoint failed: {e}")

        # Try the GWT module load - sometimes tokens are in bootstrap data
        try:
            response = self._session.get(
                f"{self.BASE_URL}/solium/participant/participant.nocache.js",
                timeout=10
            )
            if response.status_code == 200:
                # Look for bootstrap data or config with tokens
                match = re.search(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', response.text)
                if match:
                    logger.info("Found JWT in GWT bootstrap")
                    return match.group(0)
        except Exception:
            pass

        # Try extracting from the dashboard page JavaScript/embedded data
        pages_to_search = []
        if hasattr(self, '_dashboard_page'):
            pages_to_search.append(('dashboard', self._dashboard_page))
        if hasattr(self, '_login_page'):
            pages_to_search.append(('login', self._login_page))

        for page_name, page in pages_to_search:
            # Look for JWT in script tags or data attributes
            patterns = [
                (r'authToken["\']?\s*[:=]\s*["\']?(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)', 'authToken'),
                (r'token["\']?\s*[:=]\s*["\']?(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)', 'token'),
                (r'jwt["\']?\s*[:=]\s*["\']?(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)', 'jwt'),
                (r'authorization["\']?\s*[:=]\s*["\']?(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)', 'authorization'),
                (r'Bearer\s+(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)', 'Bearer'),
                (r'"accessToken"\s*:\s*"(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)"', 'accessToken'),
            ]
            for pattern, name in patterns:
                match = re.search(pattern, page, re.IGNORECASE)
                if match:
                    token = match.group(1)
                    logger.info(f"Found JWT in {page_name} page via {name} pattern")
                    return token

            # Also try to extract employee/participant ID
            if not self.employee_id:
                id_patterns = [
                    r'"participantId"\s*:\s*"?(\d+)"?',
                    r'"employeeId"\s*:\s*"?(\d+)"?',
                    r'"userId"\s*:\s*"?(\d+)"?',
                    r'"sub"\s*:\s*"?(\d+)"?',
                    r'participantId=(\d+)',
                ]
                for pattern in id_patterns:
                    match = re.search(pattern, page)
                    if match:
                        self.employee_id = match.group(1)
                        logger.info(f"Found employee ID in {page_name} page: {self.employee_id}")
                        break

        return None

    def _verify_login(self) -> bool:
        """Verify login by accessing the dashboard and extract employee ID from SW.initialData."""
        try:
            # Fetch the main UI dashboard - this contains SW.initialData with employeePK
            response = self._session.get(
                f"{self.BASE_URL}/solium/servlet/ui",
                timeout=30
            )
            # If we get redirected to login, we're not authenticated
            if 'userLogin' in response.url:
                return False

            # Store this page for data extraction
            self._home_page = response.text
            logger.info(f"Morgan Stanley dashboard page length: {len(response.text)}")

            # Extract employeePK from SW.initialData - this is the employeeid header value!
            # IMPORTANT: The JWT 'sub' claim (accountPK) is DIFFERENT from employeePK
            employee_pk_match = re.search(r"employeePK:\s*'(\d+)'", response.text)
            if employee_pk_match:
                extracted_employee_id = employee_pk_match.group(1)
                logger.info(f"Morgan Stanley: Extracted employeePK from dashboard: {extracted_employee_id}")
                if not self.employee_id:
                    self.employee_id = extracted_employee_id
                elif self.employee_id != extracted_employee_id:
                    logger.warning(
                        f"Morgan Stanley: Provided employee_id ({self.employee_id}) differs from "
                        f"extracted employeePK ({extracted_employee_id}). Using extracted value."
                    )
                    self.employee_id = extracted_employee_id
            else:
                logger.warning("Morgan Stanley: Could not find employeePK in dashboard HTML")

            # Also extract accountPK for reference (this is the JWT 'sub' claim)
            account_pk_match = re.search(r"accountPK:\s*'(\d+)'", response.text)
            if account_pk_match:
                logger.info(f"Morgan Stanley: accountPK (JWT sub): {account_pk_match.group(1)}")

            # Try alternative endpoints that might return JSON with JWT
            json_endpoints = [
                '/solium/servlet/getParticipantSummary.do',
                '/solium/servlet/getAccountSummary.do',
                '/solium/api/participant/summary',
                '/solium/api/portfolio/summary',
                '/solium/api/auth/session',
                '/solium/api/session/token',
                '/api/auth/token',
            ]
            for endpoint in json_endpoints:
                try:
                    resp = self._session.get(f"{self.BASE_URL}{endpoint}", timeout=10)
                    logger.debug(f"Morgan Stanley {endpoint}: status={resp.status_code}, content-type={resp.headers.get('content-type', 'unknown')}")
                    if resp.status_code == 200:
                        content_type = resp.headers.get('content-type', '')
                        if 'json' in content_type:
                            logger.info(f"Morgan Stanley JSON endpoint found: {endpoint}")
                            try:
                                data = resp.json()
                                logger.info(f"Morgan Stanley JSON data keys: {list(data.keys()) if isinstance(data, dict) else 'not dict'}")
                                # Check for JWT or useful data
                                if isinstance(data, dict):
                                    for key in ['token', 'jwt', 'authorization', 'accessToken', 'access_token', 'idToken']:
                                        if key in data and str(data[key]).startswith('eyJ'):
                                            logger.info(f"Morgan Stanley found JWT in {endpoint} field {key}")
                                            self._jwt_token = data[key]
                                    for key in ['employeeId', 'employee_id', 'participantId', 'userId']:
                                        if key in data:
                                            self.employee_id = str(data[key])
                                            logger.info(f"Morgan Stanley found employee ID: {self.employee_id}")
                            except Exception:
                                pass
                except Exception as e:
                    logger.debug(f"Morgan Stanley endpoint {endpoint} failed: {e}")

            # Try a simple GraphQL query to test if session cookies work
            try:
                self._try_graphql_with_session()
            except Exception as e:
                logger.debug(f"Morgan Stanley GraphQL session test failed: {e}")

            return True
        except Exception as e:
            logger.error(f"Morgan Stanley verify login failed: {e}")
            return False

    def _try_graphql_with_session(self):
        """Try a GraphQL query using only session cookies to see if JWT is needed."""
        # Try a simple introspection-like query to see what's available
        test_query = """
        query {
            viewer {
                employeeId
                participantId
            }
        }
        """

        headers = {
            'Content-Type': 'application/json',
            'Origin': self.BASE_URL,
            'Referer': f'{self.BASE_URL}/solium/servlet/ui',
            'Accept': 'application/json',
        }

        payload = {
            'operationName': None,
            'variables': {},
            'query': test_query
        }

        try:
            response = self._session.post(
                self.GRAPHQL_URL,
                json=payload,
                headers=headers,
                timeout=15
            )
            logger.info(f"Morgan Stanley GraphQL session test: status={response.status_code}")

            if response.status_code == 200:
                data = response.json()
                logger.info(f"Morgan Stanley GraphQL session test response: {data}")

                # Check if we got valid data or an auth error
                if 'data' in data and data['data']:
                    viewer = data.get('data', {}).get('viewer', {})
                    if viewer:
                        if 'employeeId' in viewer:
                            self.employee_id = str(viewer['employeeId'])
                            logger.info(f"Morgan Stanley: Got employee ID from GraphQL: {self.employee_id}")
                        if 'participantId' in viewer:
                            self.employee_id = self.employee_id or str(viewer['participantId'])
                    logger.info("Morgan Stanley: GraphQL works with session cookies!")
                elif 'errors' in data:
                    # Check if the error contains token info
                    for error in data.get('errors', []):
                        error_str = str(error)
                        logger.debug(f"Morgan Stanley GraphQL error: {error_str}")

        except Exception as e:
            logger.debug(f"Morgan Stanley GraphQL session test error: {e}")

    def complete_2fa(
        self,
        auth_code: Optional[str],
        session_data: Dict[str, Any]
    ) -> AuthResult:
        """
        Complete 2FA if required.

        Morgan Stanley uses various 2FA methods. This may need to be
        completed through the browser first.
        """
        return AuthResult(
            success=False,
            error_message="2FA must be completed through the Morgan Stanley website. "
                         "Please log in via browser first, then try syncing again."
        )

    def _graphql_query(self, query: str, variables: Optional[Dict] = None) -> Dict:
        """Execute a GraphQL query."""
        headers = {
            'Content-Type': 'application/json',
            'Connection': 'keep-alive',
            'Origin': self.BASE_URL,
            'Referer': f'{self.BASE_URL}/solium/servlet/ui',
            'Accept': 'application/json',
        }

        # JWT token is required for GraphQL requests
        if not self._jwt_token:
            raise RuntimeError(
                "JWT token is required for GraphQL queries. Login may have succeeded but "
                "JWT wasn't obtained. Please provide JWT token from browser DevTools: "
                "Network > filter 'graphql' > Headers > 'authorization'."
            )

        # Remove Bearer prefix if present (user might copy full header value)
        token = self._jwt_token
        if token.lower().startswith('bearer '):
            token = token[7:]
        # Morgan Stanley expects lowercase 'authorization' header without Bearer prefix
        headers['authorization'] = token
        logger.info(f"Morgan Stanley: Sending JWT token (first 20 chars): {token[:20]}...")

        if self.employee_id:
            # Morgan Stanley expects lowercase 'employeeid' header
            # IMPORTANT: This is NOT the same as the JWT's 'sub' claim!
            headers['employeeid'] = self.employee_id
            logger.info(f"Morgan Stanley: Sending employee ID: {self.employee_id}")
        else:
            raise RuntimeError(
                "Employee ID is required. In browser DevTools, find any /graphql request "
                "and copy the 'employeeid' header value. Note: This is different from the "
                "JWT's 'sub' claim - they are NOT the same value."
            )

        payload = {
            'operationName': None,
            'variables': variables or {},
            'query': query
        }

        logger.info(f"Morgan Stanley GraphQL query to {self.GRAPHQL_URL}")
        logger.debug(f"Morgan Stanley GraphQL headers: {list(headers.keys())}")

        response = self._session.post(
            self.GRAPHQL_URL,
            json=payload,
            headers=headers,
            timeout=30
        )

        logger.info(f"Morgan Stanley GraphQL response: status={response.status_code}")

        # Check if the response contains a JWT token in headers (some APIs return it this way)
        auth_header = response.headers.get('authorization') or response.headers.get('Authorization')
        if auth_header and auth_header.startswith('eyJ') and not self._jwt_token:
            logger.info("Morgan Stanley: Found JWT in GraphQL response headers")
            self._jwt_token = auth_header

        if response.status_code != 200:
            logger.error(f"Morgan Stanley GraphQL error: {response.text[:500]}")
            # Try to extract error details
            try:
                error_data = response.json()
                if 'errors' in error_data:
                    error_msg = error_data['errors'][0].get('message', 'Unknown error')
                    # Check for token expiration/signature errors
                    if 'token' in error_msg.lower() and ('signature' in error_msg.lower() or 'expired' in error_msg.lower() or 'invalid' in error_msg.lower()):
                        raise RuntimeError(
                            f"JWT token expired or invalid. Please update your credentials with a fresh JWT token from browser DevTools. "
                            f"(Error: {error_msg})"
                        )
                    raise RuntimeError(f"GraphQL error: {error_msg}")
            except (ValueError, KeyError):
                pass

        response.raise_for_status()

        result = response.json()

        # Check for GraphQL-level errors (can happen even with 200 status)
        if 'errors' in result:
            errors = result['errors']
            logger.warning(f"Morgan Stanley GraphQL returned errors: {errors}")
            for error in errors:
                error_msg = error.get('message', str(error))
                # Check for token expiration/signature errors
                if 'token' in error_msg.lower() and ('signature' in error_msg.lower() or 'expired' in error_msg.lower() or 'invalid' in error_msg.lower()):
                    raise RuntimeError(
                        f"JWT token expired or invalid. Please update your credentials with a fresh JWT token from browser DevTools. "
                        f"(Error: {error_msg})"
                    )
                if 'unauthorized' in str(error).lower() or 'authentication' in str(error).lower():
                    raise RuntimeError(f"GraphQL authentication error: {error_msg}")

        return result

    def get_accounts(self) -> List[AccountInfo]:
        """Fetch list of accounts from Morgan Stanley."""
        if not self._authenticated:
            result = self.authenticate()
            if not result.success:
                raise RuntimeError(result.error_message)

        # For Morgan Stanley at Work, typically one account per employee
        accounts = [
            AccountInfo(
                identifier=self.account_number or self.employee_id or 'main',
                name='Morgan Stanley at Work',
                account_type='brokerage',
                currency='USD'
            )
        ]

        return accounts

    def get_balance(self, account_identifier: str) -> BalanceInfo:
        """
        Fetch account balance using GraphQL.

        Returns the total portfolio value (availableValue + unavailableValue).
        """
        if not self._authenticated:
            result = self.authenticate()
            if not result.success:
                raise RuntimeError(result.error_message)

        try:
            query = """
            query {
                portfolio {
                    availableValue {
                        amount
                        currency
                    }
                    unavailableValue {
                        amount
                        currency
                    }
                }
            }
            """

            data = self._graphql_query(query, {'cumulative': True})
            self._portfolio_data = data

            portfolio = data.get('data', {}).get('portfolio', {})

            available = portfolio.get('availableValue', {})
            unavailable = portfolio.get('unavailableValue', {})

            available_amount = Decimal(str(available.get('amount', 0)))
            unavailable_amount = Decimal(str(unavailable.get('amount', 0)))

            currency = available.get('currency', 'USD') or unavailable.get('currency', 'USD')

            # Default: only vested (available) value — unvested shares aren't truly
            # owned yet. Opt in to include unvested via the include_unvested credential.
            balance_amount = available_amount
            if self.include_unvested:
                balance_amount = available_amount + unavailable_amount

            return BalanceInfo(
                balance=balance_amount,
                currency=currency,
                balance_date=date.today(),
                available_balance=available_amount,
                raw_data={
                    'vestedValue': float(available_amount),
                    'unvestedValue': float(unavailable_amount),
                    'includeUnvested': self.include_unvested,
                    'currency': currency
                }
            )

        except Exception as e:
            logger.error(f"Failed to fetch balance: {e}")
            raise RuntimeError(f"Failed to fetch portfolio balance: {str(e)}")

    def get_positions(self, account_identifier: str) -> List[PositionInfo]:
        """
        Fetch portfolio positions using GraphQL.

        Fetches stock grants, options, and other holdings.
        """
        if not self._authenticated:
            result = self.authenticate()
            if not result.success:
                raise RuntimeError(result.error_message)

        positions = []

        try:
            # Query for holdings/grants
            query = """
            query {
                holdings {
                    symbol
                    name
                    quantity
                    currentPrice {
                        amount
                        currency
                    }
                    marketValue {
                        amount
                        currency
                    }
                    costBasis {
                        amount
                        currency
                    }
                    grantType
                    vestingStatus
                }
            }
            """

            data = self._graphql_query(query)
            holdings = data.get('data', {}).get('holdings', [])

            for holding in holdings:
                if holding:
                    positions.append(self._parse_holding(holding))

        except Exception as e:
            logger.warning(f"Failed to fetch positions via holdings query: {e}")

            # Try alternative query
            try:
                query = """
                query {
                    stockGrants {
                        symbol
                        grantName
                        vestedShares
                        unvestedShares
                        currentPrice
                        vestedValue
                        grantType
                    }
                }
                """

                data = self._graphql_query(query)
                grants = data.get('data', {}).get('stockGrants', [])

                for grant in grants:
                    if grant:
                        positions.append(self._parse_grant(grant))

            except Exception as e2:
                logger.warning(f"Failed to fetch positions via grants query: {e2}")

        return positions

    def _parse_holding(self, holding: Dict) -> PositionInfo:
        """Parse a holding into PositionInfo."""
        current_price = holding.get('currentPrice', {})
        market_value = holding.get('marketValue', {})
        cost_basis = holding.get('costBasis', {})

        quantity = holding.get('quantity', 0)
        price = current_price.get('amount', 0) if current_price else 0
        value = market_value.get('amount', 0) if market_value else 0
        cost = cost_basis.get('amount') if cost_basis else None

        # Determine asset class based on grant type
        grant_type = holding.get('grantType', '').upper()
        if 'OPTION' in grant_type:
            asset_class = 'equity'  # Stock options
        elif 'RSU' in grant_type or 'STOCK' in grant_type:
            asset_class = 'equity'
        else:
            asset_class = 'equity'

        return PositionInfo(
            symbol=holding.get('symbol', ''),
            name=holding.get('name', holding.get('grantName', '')),
            quantity=Decimal(str(quantity)),
            price_per_unit=Decimal(str(price)),
            market_value=Decimal(str(value)),
            currency=current_price.get('currency', 'USD') if current_price else 'USD',
            cost_basis=Decimal(str(cost)) if cost else None,
            asset_class=asset_class
        )

    def _parse_grant(self, grant: Dict) -> PositionInfo:
        """Parse a stock grant into PositionInfo."""
        vested = grant.get('vestedShares', 0)
        price = grant.get('currentPrice', 0)
        value = grant.get('vestedValue', 0)

        return PositionInfo(
            symbol=grant.get('symbol', ''),
            name=grant.get('grantName', ''),
            quantity=Decimal(str(vested)),
            price_per_unit=Decimal(str(price)),
            market_value=Decimal(str(value)),
            currency='USD',
            asset_class='equity'
        )

    def supports_historical_data(self) -> bool:
        """
        Morgan Stanley does NOT support historical portfolio value snapshots.

        Their GraphQL API is event/transaction-based (vesting, releases, exercises)
        rather than providing daily portfolio value history. Available queries:
        - portfolio: current state only
        - events: vesting events (past, in-progress, upcoming)
        - transactions: transaction history with pagination

        None of these provide daily portfolio value snapshots needed for
        historical wealth tracking.
        """
        return False

    def close(self):
        """Close the session."""
        if self._session:
            try:
                # Try to logout
                self._session.get(
                    f"{self.BASE_URL}/solium/servlet/userLogout.do",
                    timeout=10
                )
            except Exception:
                pass
            self._session.close()
            self._session = None
        self._authenticated = False
        self._jwt_token = None
        self._portfolio_data = None
