# Morgan Stanley at Work Integration

## Overview

Morgan Stanley at Work is an employee stock plan platform. This integration uses their internal GraphQL API to fetch portfolio data.

> **2026-05-30 UPDATE — fully programmatic auth is SOLVED.** The old conclusion in this doc ("the JWT cannot be obtained programmatically") is **wrong** and has been superseded. The JWT is minted by a plain REST call we can replicate. See [Programmatic Authentication (Solved)](#programmatic-authentication-solved) below. The manual DevTools JWT-paste flow still works as a fallback, but is no longer required.

## Programmatic Authentication (Solved)

The full, browser-free auth chain (reverse-engineered from HAR captures on 2026-05-29/30):

```
1. POST /solium/servlet/userLogin.do        (form login -> session cookies)
2. [if 2FA challenged] GWT-RPC TOTP          (only on an untrusted device)
3. GET  /solium/servlet/ui                   (HTML embeds SW.initialData)
4. POST /rest/participant/v2/auth/tokens     (session -> JWT)   <-- the missing piece
5. fetch via /graphql OR REST /rest/participant/v2/...
```

### Step 4 — the JWT mint endpoint (the breakthrough)

`POST https://atwork.morganstanley.com/rest/participant/v2/auth/tokens`
with session cookies and a JSON body:

```json
{
  "authType": "SWPTPAPI_TOKEN",
  "sessionToken": "<SW.initialData.apiKey>",
  "employeeId":  <SW.initialData.activeAccount.employeePK>,
  "locale": "en-US",
  "canPromptUserToRegisterDevice": false,
  "msSessionId": "<SW.initialData.msSessionId>"
}
```

Every dynamic field is read straight off `SW.initialData` in the `/solium/servlet/ui` HTML:

| Body field      | Source in `SW.initialData`               | Notes |
|-----------------|------------------------------------------|-------|
| `sessionToken`  | `apiKey` (top-level)                      | per-session, == JWT `ses` claim |
| `employeeId`    | `activeAccount.employeePK`                | stable; == `employeeid` GraphQL header |
| `msSessionId`   | `msSessionId` (top-level)                 | per-session |
| `authType`      | constant `"SWPTPAPI_TOKEN"`               | |
| `locale`        | constant / `dialect`                      | |

`sessionToken` and `msSessionId` are **per-login** — scrape them fresh each time, do not hardcode. `employeePK` is stable.

Response (`application/json`) contains the JWT plus an account summary and a full REST endpoint catalog:

```json
{
  "accessToken": { "accessToken": "eyJ...", "expiresIn": 900, "tokenType": "Bearer", "scope": "READ_WRITE" },
  "accounts": [ { "employeeId": ..., "accountId": ..., "companyName": "Alphabet, Inc.", ... } ],
  "endpoints": [ { "type": "Holdings", "href": "/v2/holdings" }, ... ]
}
```

### Token characteristics

- **RS256** (server-signed — cannot be forged client-side).
- **Lifetime: 15 minutes** (`expiresIn: 900`) — NOT the "~1 hour" claimed elsewhere in this doc. Mint fresh per sync.
- Key claims: `sub` = `accountPK`, `ses` = `apiKey`, plus `msSessionId`, `scope`, `ms2FaRequired`, `deviceRegistrationRequired`, `isDeviceRegistered`.

### Why the old investigation missed it

It only ever filtered DevTools by `graphql`, so it saw the JWT *used* on every request but never the one-shot bootstrap call that *fetched* it. It also guessed paths like `/solium/api/auth/token` and `/oauth/token` — the real path is `/rest/participant/v2/auth/tokens` (different prefix, plural). A blind "record all, grep every response for `eyJ`" found it immediately.

### Useful REST data endpoints (from the catalog)

Often simpler than GraphQL — base is `/rest/participant` + the `href`:

- `/v2/portfolio/summary`, `/v2/portfolio/portfolio-data`
- `/v2/holdings`
- `/v2/ms/share-holdings`, `/v2/ms/retail-accounts`
- `/v2/grants`, `/v2/awards`, `/v2/events`, `/v2/release-events`
- `/v2/auth/refresh-tokens/{deviceId}` — **mobile** app's long-lived re-auth (not used by web; needs a mobile capture to exploit)

## Login & 2FA Mechanics

### Login (step 1)

`POST /solium/servlet/userLogin.do` (form-urlencoded). Notable fields:
- `account_number`, `password`
- `TO_<random>` — CSRF token; scrape from the login page (`GET userLogin.do`)
- `ms_rsa_footprint` — deterministic encoding of browser/screen/timezone props (reconstructable)
- `symantec_device_fingerprint` — the Symantec VIP device blob (see below)

On a **trusted device the 2FA dance is skipped entirely** — login collapses to `userLogin.do` → `ui` → `auth/tokens`.

### 2FA (step 2 — only when the device is untrusted)

The web 2FA runs over **GWT-RPC** at `POST /solium/servlet/userLoginRequirementsGwtService` (pipe-delimited RPC, fragile to hand-craft). Observed calls: `getMorganStanleyAuthPageData`, `getTotp2faPageData`, `validateTotp`, `logTotpVerificationRequest`, `setAllLoginRequirementsComplete`.

- **2FA method = TOTP** (6-digit, e.g. `validateTotp|...|535899|...`). A masked phone (`XXXXX4474`) and SMS/call/push/authenticator options exist; we use **authenticator TOTP**, automatable via a stored seed with `pyotp` (same pattern as TrueWealth).
- After TOTP, the SPA calls `POST /rest/participant/v2/device-registration/register-device` (body: `deviceFingerPrint`). Response is just `{"reasonCode":"SUCCESS"}` — **no refresh token, no deviceId**. Web device-trust is keyed on the **fingerprint**, not a stored client token.

The cleaner REST 2FA endpoints (`/v2/auth/send-otp`, `/v2/auth/otpnumbers/{uuid}/session/{sessionId}`, `/v2/multi-factor`) are the **mobile** app's path, not the web flow.

## Symantec Device Fingerprint (`symantec_device_fingerprint`)

Generated by `vipsymantec/iadfp_1.3.js` (Symantec/Broadcom VIP "IaDfp", global `IaDfp`, format marker `_v02`). Findings from three login captures + JS analysis:

- **~6.5 KB blob, 98.7% byte-stable** across logins. Pre-obfuscation it's a `key=value|...` string of device signals: canvas (`cnvfp`), WebGL (`wglfp`/`wglvrfp`/`wglextfp`), audio codecs (`aufp`), `navigator.*`, `screen.*`, storage-availability flags. Obfuscation is a reversible multi-layer char transform (XOR/base64 layers).
- The only varying window (~95 chars) is a **per-browser-context** value (randomized canvas/WebGL render + storage flags), **not** a per-login timestamp. It's **computed once per context and cached** — reused tab → byte-identical; new tab/private window → different. (This is why breakpoints in the generator don't fire on a plain reload: the cached value is reused.)
- Persistent device tag is stored in cookie **`_iat1`** (`__vip_ia_tag__` / `_ia_tag_id`), wrapped in a `TimestampedValue` carrying its **original tag-creation time** (not `Date.now()` at each use) — so an old timestamp is normal for a returning device.
- **Replay is accepted**: login 3 reused login 2's exact blob (separate session, fresh `sessionToken`/`msSessionId`) and the server accepted it — no freshness/uniqueness check observed.
- Device-trust is anchored on the **stable** signals (same hardware/browser across tabs), not the variable window.

### Synthesis vs. replay vs. headless

- **Synthesize from scratch**: hard — requires reversing the multi-layer obfuscation. Not pursued.
- **Replay a captured blob**: proven to work, simplest, but a static blob from a datacenter IP is a mild fraud-anomaly risk over time.
- **Headless browser (CHOSEN)**: a Playwright step loads the login page with the persisted `_iat1` cookie, lets the real JS generate a fresh, correctly-timestamped fingerprint, auto-fills the TOTP from the seed, and hands the established session to the mint→fetch code. Looks exactly like the user's returning browser. Lowest fraud risk.

## Credential Requirements (current design)

- **Required:** `username`, `password`, `totp_secret` (base32 seed — same as TrueWealth; the seed is set at authenticator enrollment and never transmitted, so it must be provided, not captured).
- **Derived at runtime:** CSRF `TO_*`, `ms_rsa_footprint`, `sessionToken`/`apiKey`, `msSessionId`, `employeePK`, session cookies, and (via the headless step) the `symantec_device_fingerprint`.
- Persist the `_iat1` device-tag cookie between runs to keep the device trusted and avoid re-challenging 2FA.

## Implementation (Headless Browser)

Implemented 2026-05-30. The login step runs a real Chromium via Playwright; data
fetching is unchanged (curl_cffi GraphQL with the minted JWT).

### Files

- [`backend/brokers/integrations/morganstanley_browser.py`](../backend/brokers/integrations/morganstanley_browser.py) — `browser_login()`: loads persisted device-trust state, fills `account_number`/`password`, auto-fills the TOTP (`pyotp`) on a 2FA challenge, ticks "trust this device", captures the JWT by intercepting the `POST /rest/participant/v2/auth/tokens` response, reads `employeePK` from `SW.initialData`, and saves `storage_state`. Playwright is imported lazily — the module imports fine without it.
- [`backend/brokers/integrations/morganstanley.py`](../backend/brokers/integrations/morganstanley.py) — `authenticate()` calls `_browser_authenticate()` when `username`+`password`+`totp_secret` are present; on success it sets `_jwt_token` + `employee_id` and the existing GraphQL path takes over. `BrowserLoginUnavailable` (no Playwright/Chromium) falls back to the manual JWT path; `BrowserLoginError` surfaces as an auth failure.
- Factory `get_broker_integration(broker, credentials, account_id=...)` threads the `FinancialAccount.id` through so device-trust state is keyed per account.

### Device-trust persistence

`storage_state` (cookies incl. `_iat1`, localStorage) is written to
`MS_BROWSER_STATE_DIR/ms_account_<id>_<hash>.json` (mode `0600`), keyed by
`FinancialAccount.id`. Default dir is `<BASE_DIR>/ms_browser_state` (gitignored).
**Set `MS_BROWSER_STATE_DIR` to a persistent volume in Docker** so device trust
survives rebuilds; otherwise every sync logs in as a new device (still works via
the TOTP seed, but re-registers each time).

### Deployment

- `requirements.txt` pins `playwright==1.60.0`.
- The backend Dockerfile runs `playwright install --with-deps chromium` (browsers under `/ms-playwright`). For a non-Docker host, run that once in the venv.
- Env vars: `MS_BROWSER_STATE_DIR` (persistent state dir), `MS_HEADLESS=0` (run headful to watch/debug the flow).

### Selector caveat (needs one live verification)

The `userLogin.do` field selectors (`account_number`, `password`) are
high-confidence. The **TOTP / "trust this device" page is GWT-rendered and its DOM
was never captured**, so `_TOTP_*` / `_TRUST_*` selectors in `morganstanley_browser.py`
are best-effort with fallbacks. Run once with `MS_HEADLESS=0` against a real
account, watch the 2FA step, and adjust those selectors if they miss. The JWT
capture itself is selector-independent (network interception), so only the 2FA
form-filling depends on selectors.

### Migrating an existing account

Use the web UI's **Change type** action (Account Settings → Change type) or, for a
manual MS account, switch it to the Morgan Stanley broker and add
username/password/TOTP. Changing the broker drops any old stored credentials
server-side. Balance history is preserved (it hangs off the account).

## Authentication Architecture

Morgan Stanley uses a complex authentication system with multiple IDs that are easily confused:

### Key IDs (IMPORTANT - These are DIFFERENT values!)

| ID Type | Example Value | Where Found | Purpose |
|---------|---------------|-------------|---------|
| `employeePK` | `37493646648` | Dashboard HTML `SW.initialData.activeAccount.employeePK` | **Used as `employeeid` header in GraphQL requests** |
| `accountPK` | `37498936179` | Dashboard HTML `SW.initialData.activeAccount.accountPK` | Same as JWT `sub` claim - NOT used for GraphQL! |
| JWT `sub` claim | `37498936179` | JWT payload | Identifies the account, but NOT the employee ID header |

**CRITICAL**: The `employeeid` header required for GraphQL is `employeePK`, NOT the JWT's `sub` claim. Using the wrong value causes 500 Internal Server Error.

## API Endpoints

### GraphQL Endpoint
- URL: `https://atwork.morganstanley.com/graphql`
- Method: POST
- Required Headers:
  - `authorization`: JWT token (without "Bearer " prefix)
  - `employeeid`: The `employeePK` value (NOT JWT sub!)
  - `content-type`: application/json

### Login Endpoint
- URL: `https://atwork.morganstanley.com/solium/servlet/userLogin.do`
- Method: POST
- Content-Type: `application/x-www-form-urlencoded`
- Redirects to: `/solium/servlet/ui` on success

### Dashboard Page
- URL: `https://atwork.morganstanley.com/solium/servlet/ui`
- Contains: `SW.initialData` JavaScript object with all user/account data
- Key data in `SW.initialData.activeAccount`:
  - `employeePK`: Required for GraphQL `employeeid` header
  - `accountPK`: Same as JWT `sub` claim
  - `userPK`: User primary key
  - `employeeFullName`, `companyName`, etc.

## Working GraphQL Query

```graphql
query {
  portfolio {
    availableValue { amount currency }
    unavailableValue { amount currency }
    totalValue { amount currency }
  }
}
```

### Available GraphQL Queries (from schema introspection)
- `aggregatePortfolio`
- `currencyRates`
- `aggregateRelease`
- `company`
- `events`
- `portfolio`
- `portfolioModelling`
- `funds`
- `transactions`
- `offering`
- `grantElections`
- `retailAccount`
- `enrollments`
- `enrollmentDetails`
- `sellSharesInitialData`
- `participantDetails`

## Authentication Methods

### Method 1: Username + Password (Preferred)
1. POST login credentials to `/solium/servlet/userLogin.do`
2. Follow redirect to `/solium/servlet/ui`
3. Extract `employeePK` from `SW.initialData.activeAccount.employeePK`
4. **Problem**: JWT token is generated by frontend JavaScript, not returned in login response
5. **Result**: Login may succeed, but JWT still needs to be provided manually

### Method 2: JWT + Employee ID (Fallback)
1. User logs in via browser
2. Opens DevTools > Network > filters by "graphql"
3. Copies `authorization` header value (JWT token)
4. Copies `employeeid` header value (this is `employeePK`)
5. Provides both to the integration

## Bot Detection

Morgan Stanley has strong bot detection (Akamai). The integration uses `curl_cffi` with Chrome TLS fingerprint impersonation to help bypass it:

```python
from curl_cffi import requests as curl_requests
session = curl_requests.Session(impersonate="chrome")
```

Login may still fail due to bot detection. In that case, users must use Method 2 (JWT + Employee ID).

## Example Working Request

```bash
curl 'https://atwork.morganstanley.com/graphql' \
  -H 'authorization: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...' \
  -H 'employeeid: 37493646648' \
  -H 'content-type: application/json' \
  --data-raw '{"operationName":null,"variables":{},"query":"{ portfolio { availableValue { amount currency } } }"}'
```

## Response Format

```json
{
  "data": {
    "portfolio": {
      "availableValue": {
        "amount": "244380.1",
        "currency": "USD"
      },
      "unavailableValue": {
        "amount": "301855.10852",
        "currency": "USD"
      },
      "totalValue": {
        "amount": "546235.20852",
        "currency": "USD"
      }
    }
  }
}
```

- `availableValue`: Vested shares (can be sold)
- `unavailableValue`: Unvested shares (still vesting)
- `totalValue`: Sum of both

## Common Errors

### 500 Internal Server Error on portfolio queries
**Cause**: Wrong `employeeid` header value (using JWT `sub` instead of `employeePK`)
**Solution**: Use `employeePK` from dashboard HTML, not JWT payload

### 400 Bad Request
**Cause**: Missing `employeeid` header
**Solution**: Provide the `employeeid` header

### "invalid token signature"
**Cause**: JWT token expired (tokens last ~1 hour)
**Solution**: Get fresh JWT from browser DevTools

## Implementation Files

- Integration: `backend/brokers/integrations/morganstanley.py`
- Fixtures: `backend/brokers/fixtures/initial_brokers.json`
- Factory: `backend/brokers/integrations/__init__.py`

## Credential Schema

```json
{
  "type": "object",
  "required": ["username", "password"],
  "properties": {
    "username": { "type": "string", "title": "Username" },
    "password": { "type": "string", "title": "Password", "format": "password" },
    "jwt_token": { "type": "string", "title": "JWT Token (if login fails)", "format": "password" },
    "employee_id": { "type": "string", "title": "Employee ID (if login fails)" }
  }
}
```

## Investigation History (2026-01-30)

1. Initial problem: GraphQL queries returning 500 errors
2. Found that JWT authentication was working (schema introspection succeeded)
3. Discovered `employeeid` header value in working curl example was different from JWT `sub`
4. Tested with correct `employeeid` (from header, not JWT) - worked!
5. Analyzed HAR/dashboard HTML to find source of `employeeid`
6. Found `employeePK` in `SW.initialData.activeAccount` - this is the correct value
7. Updated integration to extract `employeePK` from dashboard after login
8. Updated credential schema to support both auth methods

## Key Learnings

1. **JWT `sub` is NOT the employee ID** - this was the main bug
2. `employeePK` and `accountPK` are different values for the same user
3. The frontend JavaScript generates/retrieves JWT - it's not in login response
4. Bot detection may block programmatic login, requiring manual JWT extraction
5. Headers must be lowercase (`authorization`, `employeeid`)
6. JWT should NOT have "Bearer " prefix when sent to Morgan Stanley

## JWT Token Investigation (2026-01-30)

### The Problem
The JWT token required for GraphQL calls is NOT returned in the login response. After successful login with username/password, we can extract `employeePK` from the dashboard HTML, but the JWT must still be provided manually.

### Investigation Attempts

We tried multiple approaches to obtain the JWT programmatically:

1. **Token endpoints tested** (all failed to return JWT):
   - `/solium/api/auth/token`
   - `/solium/api/session/token`
   - `/solium/servlet/mobileAuth.do`
   - `/solium/servlet/getToken.do`
   - `/api/auth/token`
   - `/oauth/token`

2. **GraphQL mutations tested**:
   - `{ getToken { token } }` - Query doesn't exist
   - `mutation { login { token } }` - Mutation doesn't exist
   - `{ session { token } }` - Query doesn't exist
   - Schema introspection shows no auth-related queries/mutations

3. **Dashboard analysis**:
   - `SW.initialData` contains `apiKey` which matches JWT's `ses` claim
   - No JWT or token field found in `SW.initialData`
   - JWT not found embedded anywhere in dashboard HTML

### Conclusion (SUPERSEDED 2026-05-30 — see [Programmatic Authentication (Solved)](#programmatic-authentication-solved))

> The conclusion below was wrong. The JWT IS obtainable programmatically via `POST /rest/participant/v2/auth/tokens` using values scraped from `SW.initialData`. The reasoning errors: (1) DevTools was always filtered to `graphql`, hiding the one-shot mint call; (2) the guessed token paths used the wrong prefix. Kept for historical context only.

The JWT is generated by frontend JavaScript in a way we haven't been able to replicate:
- JWT uses RS256 (RSA signature), so it MUST be generated server-side
- The frontend likely calls an internal API that we couldn't identify
- Possible mechanisms: WebSocket, encrypted endpoint, or dynamic JS-based auth

### Current Workaround

Users must provide JWT + Employee ID manually from browser DevTools:

1. Log into Morgan Stanley at Work in browser
2. Open DevTools (F12 or Cmd+Option+I)
3. Go to Network tab
4. Navigate to any page that loads portfolio data (or refresh)
5. Filter by "graphql"
6. Click on any graphql request
7. In the Headers section, copy:
   - `authorization` header value → JWT Token
   - `employeeid` header value → Employee ID

**Note**: JWT tokens expire after ~1 hour. Users will need to refresh credentials periodically.

### Future Improvements

To fully automate this, we would need to:
1. Reverse-engineer the frontend JavaScript bundle to find token generation
2. Check for WebSocket messages that might deliver the token
3. Monitor all XHR requests after page load to find the token endpoint
4. Consider using browser automation (Playwright/Puppeteer) to extract the token

Using browser automation would be more reliable but adds significant complexity.
