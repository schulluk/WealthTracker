# Wealth Tracker

A personal wealth tracking application that aggregates account balances from multiple financial institutions and provides portfolio analytics.

## Features

- **Multi-broker support**: Connect to German banks via FinTS (DKB, Commerzbank), Interactive Brokers, and other brokers
- **Account sync**: Fetch account balances with 2FA support (user-initiated)
- **Currency conversion**: Automatic conversion to your base currency using Frankfurter API
- **Historical tracking**: Store balance snapshots over time for growth visualization
- **Portfolio breakdown**: View wealth by broker, currency, or account type
- **Secure credential storage**: Per-user encryption with client-side key derivation

## Project Structure

```
wealth/
├── backend/                 # Django REST API
│   ├── accounts/           # User profiles and authentication
│   ├── brokers/            # Broker definitions and integrations
│   │   └── integrations/   # FinTS, REST API implementations
│   ├── portfolio/          # Financial accounts and snapshots
│   ├── exchange_rates/     # Currency conversion service
│   └── core/               # Shared utilities (encryption)
├── frontend/               # React + TypeScript (Vite)
├── exchange-rates/         # Standalone exchange rate scripts
└── venv/                   # Python virtual environment
```

## Quick Start

### Prerequisites

- Python 3.9+
- Node.js 18+
- npm or yarn

### Backend Setup

```bash
# Activate virtual environment
source venv/bin/activate

# Install dependencies (already installed)
pip install -r requirements.txt

# Navigate to backend
cd backend

# Run migrations
python manage.py migrate

# Load initial broker data
python manage.py loaddata initial_brokers

# Create a superuser (optional, for admin access)
python manage.py createsuperuser

# Start the development server
python manage.py runserver
```

The API will be available at `http://localhost:8000`

### Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

The frontend will be available at `http://localhost:5173`

## API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register/` | Register new user |
| POST | `/api/auth/login/` | Get JWT tokens |
| POST | `/api/auth/refresh/` | Refresh access token |
| GET | `/api/auth/me/` | Get current user |

### User Profile

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/profile/` | Get user profile |
| PATCH | `/api/profile/` | Update profile (base currency, etc.) |

### Brokers

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/brokers/` | List available brokers |
| GET | `/api/brokers/{code}/` | Get broker details |

### Financial Accounts

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/accounts/` | List user's accounts |
| POST | `/api/accounts/` | Create/link new account |
| GET | `/api/accounts/{id}/` | Get account details |
| PATCH | `/api/accounts/{id}/` | Update account |
| DELETE | `/api/accounts/{id}/` | Delete account |
| POST | `/api/accounts/{id}/sync/` | Trigger balance sync |
| POST | `/api/accounts/{id}/auth/` | Complete 2FA |

### Snapshots

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/accounts/{id}/snapshots/` | Get account history |
| POST | `/api/accounts/{id}/snapshots/` | Add manual snapshot |

### Wealth Dashboard

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/wealth/summary/` | Current total wealth |
| GET | `/api/wealth/history/?days=30` | Historical timeline |
| GET | `/api/wealth/breakdown/?by=broker` | Breakdown by category |

### Exchange Rates

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/exchange-rates/?date=2024-01-01` | Get rates for date |
| POST | `/api/exchange-rates/sync/` | Fetch latest rates |

## Supported Brokers

| Broker | Status | Integration Type | Notes |
|--------|--------|------------------|-------|
| DKB | ✅ Active | FinTS | German bank, 2FA via app |
| Commerzbank | ✅ Active | FinTS | German bank, 2FA via app |
| Interactive Brokers | ✅ Active | REST | Flex Web Service (recommended) or Gateway, see [setup guide](docs/IBKR_SETUP.md) |
| Manual Entry | ✅ Active | - | For accounts without API |
| Morgan Stanley | ✅ Active | GraphQL | Employee stock plans (at Work), see [setup guide](docs/MORGANSTANLEY_SETUP.md) |
| True Wealth | ✅ Active | REST | Swiss robo-advisor, requires TOTP, see [setup guide](docs/TRUEWEALTH_SETUP.md) |
| VIAC | ✅ Active | REST | Swiss pension (Pillar 3a), see [setup guide](docs/VIAC_SETUP.md) |

## Usage Examples

### Register and Login

```bash
# Register
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username": "user", "email": "user@example.com", "password": "securepass123", "password_confirm": "securepass123", "base_currency": "EUR"}'

# Login
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "user", "password": "securepass123"}'
```

### Add a DKB Account

```bash
# Get JWT token first, then:
curl -X POST http://localhost:8000/api/accounts/ \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DKB Girokonto",
    "broker_code": "dkb",
    "account_identifier": "DE89370400440532013000",
    "account_type": "checking",
    "currency": "EUR",
    "credentials": {
      "username": "your-dkb-username",
      "pin": "your-dkb-pin"
    }
  }'
```

### Sync Account Balance

```bash
# Initiate sync (may require 2FA)
curl -X POST http://localhost:8000/api/accounts/1/sync/ \
  -H "Authorization: Bearer <your-token>"

# If 2FA required, approve in banking app, then call again
# or for TAN-based auth:
curl -X POST http://localhost:8000/api/accounts/1/auth/ \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{"auth_code": "123456"}'
```

### View Wealth Summary

```bash
curl http://localhost:8000/api/wealth/summary/ \
  -H "Authorization: Bearer <your-token>"
```

### Add an Interactive Brokers Account

IBKR supports two methods: Flex Web Service (recommended) or Client Portal Gateway. See [IBKR Setup Guide](docs/IBKR_SETUP.md) for detailed instructions.

**Using Flex Web Service (recommended):**
```bash
curl -X POST http://localhost:8000/api/accounts/ \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Interactive Brokers",
    "broker_code": "ibkr",
    "account_identifier": "U1234567",
    "account_type": "brokerage",
    "currency": "USD",
    "credentials": {
      "token": "your-flex-token",
      "query_id": "123456"
    }
  }'
```

**Using Client Portal Gateway:**
```bash
curl -X POST http://localhost:8000/api/accounts/ \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Interactive Brokers",
    "broker_code": "ibkr",
    "account_identifier": "U1234567",
    "account_type": "brokerage",
    "currency": "USD",
    "credentials": {
      "gateway_url": "https://localhost:5000"
    }
  }'
```

## Configuration

### Environment Variables

Create a `.env` file in the `backend/` directory:

```env
# Django
DJANGO_SECRET_KEY=your-secret-key-here
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# Database (optional, defaults to SQLite)
DATABASE_URL=postgres://user:pass@localhost/wealth

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173

# FinTS Product ID for German bank integrations (DKB, Commerzbank)
# Required for FinTS/HBCI protocol - register at https://www.hbci-zka.de/
FINTS_PRODUCT_ID=your-fints-product-id
```

## Development

### Running Tests

```bash
cd backend
python manage.py test
```

### Django Admin

Access the admin interface at `http://localhost:8000/admin/` after creating a superuser.

### Database

- **Development**: SQLite (default)
- **Production**: PostgreSQL recommended (set `DATABASE_URL`)

## Security Notes

- Credentials are encrypted with per-user keys (derived from password via Argon2id)
- Password is never sent to the server - only a client-derived auth hash
- JWT tokens expire after 60 minutes (refresh tokens last 7 days)
- Never commit `.env` files or credentials to version control
- If you forget your password, credentials are lost (no server-side recovery)

---

## Production Deployment (Docker)

This section documents production deployment using Docker Compose with Traefik reverse proxy.

### Architecture

```
                    ┌─────────────┐
                    │   Traefik   │
                    │ (SSL/Auth)  │
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
    ┌─────▼─────┐    ┌─────▼─────┐    ┌─────▼─────┐
    │  Frontend │    │   Nginx   │    │           │
    │  (React)  │    │  (API)    │    │           │
    └───────────┘    └─────┬─────┘    │  wealth-db│
                           │          │ (Postgres)│
                     ┌─────▼─────┐    │           │
                     │ wealth-py │◄───┤           │
                     │ (Django)  │    └───────────┘
                     └───────────┘
```

### Environment Configuration

Create `.env.wealth` for production. See `.env.wealth.example` for reference:

```env
# NOTE: WEALTH_HTPASSWD must be in the main .env file (not here)
# because docker-compose needs it for label substitution.
# Generate with: htpasswd -nB admin
# Add to main .env: WEALTH_HTPASSWD=admin:$$2y$$05$$...

# Database (PostgreSQL container)
POSTGRES_USER=wealth
POSTGRES_PASSWORD=<generate-secure-password>
POSTGRES_DB=wealth_base

# Database (Django connection)
# Note: Password must be duplicated here (no variable interpolation in .env files)
DATABASE_URL=postgres://wealth:<same-password>@wealth-db:5432/wealth_base

# Django
DJANGO_SECRET_KEY=<generate-secret-key>
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=wealth.example.com,localhost

# CORS
CORS_ALLOWED_ORIGINS=https://wealth.example.com

# Django error notifications (format: Name:email,Name2:email2)
ADMINS=Admin:admin@example.com

# Email (for weekly reports and error notifications)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.example.com
EMAIL_PORT=587
# TLS vs SSL: Use only ONE of these, not both
# EMAIL_USE_TLS=True  → STARTTLS on port 587 (most common)
# EMAIL_USE_SSL=True  → Implicit SSL on port 465
EMAIL_USE_TLS=True
EMAIL_USE_SSL=False
EMAIL_HOST_USER=noreply@example.com
EMAIL_HOST_PASSWORD=<email-password>
DEFAULT_FROM_EMAIL=Wealth Tracker <noreply@example.com>
ADMIN_EMAIL=admin@example.com
```

### Generating Secrets

```bash
# Django Secret Key (random 50 chars)
python -c "import secrets; print(secrets.token_urlsafe(50))"

# Database Password (random 32 chars)
python -c "import secrets; print(secrets.token_urlsafe(32))"

# HTTP Basic Auth Password (bcrypt hash for Traefik)
htpasswd -nB admin
# Output: admin:$2y$05$... (add to main .env as WEALTH_HTPASSWD)
```

### Docker Compose Services

Add these services to your `docker-compose.yml`:

```yaml
wealth-nginx:
  image: nginx
  container_name: wealth-nginx
  restart: always
  working_dir: /etc/nginx
  environment:
    PYTHON_ENDPOINT: 'wealth-py'
  labels:
    traefik.enable: true
    traefik.http.routers.wealth.rule: Host(`api.wealth.example.com`)
    traefik.http.routers.wealth.entrypoints: 'websecure'
    traefik.http.routers.wealth.tls: true
    traefik.http.routers.wealth.tls.certresolver: 'default'
    traefik.http.routers.wealth.middlewares: 'wealth-auth'
    traefik.http.middlewares.wealth-auth.basicauth.users: '${WEALTH_HTPASSWD}'
  volumes:
    - './_nginx/nginx.conf:/etc/nginx/nginx.conf:ro'
    - './_nginx/default.conf.template:/etc/nginx/templates/default.conf.template:ro'
    - '/opt/data/wealth/public/media:/var/www/public/media:ro'
    - '/opt/data/wealth/public/static:/var/www/public/static:ro'
  depends_on:
    - wealth-py
  networks:
    - public

wealth-db:
  image: postgres:18
  container_name: wealth-db
  restart: always
  env_file: .env.wealth
  volumes:
    # IMPORTANT: PostgreSQL 18 requires mounting /var/lib/postgresql (not /data subdirectory)
    - '/opt/data/wealth/databases/postgresql:/var/lib/postgresql:rw'
  networks:
    - public

wealth-py:
  build: ./_gunicorn
  container_name: wealth-py
  restart: always
  working_dir: /var/www/app
  env_file: .env.wealth
  environment:
    DJANGO_PROJECT_NAME: 'wealth'
  volumes:
    # Git repo is at /opt/data/wealth/repo/ (monorepo with backend/ and frontend/)
    - '/opt/data/wealth/repo/backend:/var/www/app:rw'
    - '/opt/data/wealth/public/media:/var/www/public/media:rw'
    - '/opt/data/wealth/public/static:/var/www/public/static:rw'
    - '/opt/data/wealth/repo/docker/crontabs:/crontabs:ro'
  depends_on:
    - wealth-db
  networks:
    - public

wealth-frontend:
  build: ./_wealth-frontend
  container_name: wealth-frontend
  restart: always
  labels:
    traefik.enable: true
    traefik.http.routers.wealth-frontend.rule: Host(`wealth.example.com`)
    traefik.http.routers.wealth-frontend.entrypoints: 'websecure'
    traefik.http.routers.wealth-frontend.tls: true
    traefik.http.routers.wealth-frontend.tls.certresolver: 'default'
    traefik.http.routers.wealth-frontend.middlewares: 'wealth-auth'
    traefik.http.services.wealth-frontend.loadbalancer.server.port: 80
  networks:
    - public
```

### Scheduled Tasks (Cron)

Set up cron jobs for automated tasks:

```crontab
# Fetch daily exchange rates (6 AM)
0 6 * * * cd /var/www/app && python manage.py fetch_exchange_rates

# Send weekly wealth reports (Mondays at 8 AM)
0 8 * * 1 cd /var/www/app && python manage.py send_wealth_report
```

Note: Account syncing requires user interaction (KEK from client) and cannot be automated server-side.

### Management Commands

```bash
# Fetch latest exchange rates
python manage.py fetch_exchange_rates

# Fetch rates for a specific date
python manage.py fetch_exchange_rates --date 2024-01-15

# Backfill historical rates
python manage.py fetch_exchange_rates --backfill --start 2024-01-01 --end 2024-01-31

# Send weekly email reports
python manage.py send_wealth_report

# Send to specific users only
python manage.py send_wealth_report --users user1 user2
```

### Initial Deployment Checklist

1. **Create environment file**: Copy `.env.wealth.example` to `.env.wealth` and fill in all values
2. **Add htpasswd to main .env**: Generate with `htpasswd -nB admin` and add as `WEALTH_HTPASSWD`
3. **Create data directories**:
   ```bash
   mkdir -p /opt/data/wealth/{repo,databases/postgresql,public/media,public/static}
   ```
4. **Clone repository** to `/opt/data/wealth/repo`
5. **Build and start containers**: `docker-compose up -d wealth-db wealth-py wealth-nginx wealth-frontend`
6. **Run migrations**: `docker exec wealth-py python manage.py migrate`
7. **Collect static files**: `docker exec wealth-py python manage.py collectstatic --noinput`
8. **Load broker fixtures**: `docker exec wealth-py python manage.py loaddata initial_brokers`
9. **Create admin user**: `docker exec -it wealth-py python manage.py createsuperuser`
10. **Cron jobs** are in the repo at `docker/crontabs` (mounted automatically)

### Troubleshooting

**Database connection issues:**
- Verify `DATABASE_URL` in `.env.wealth` matches `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- Check container networking: `docker exec wealth-py ping wealth-db`

**Static files not loading:**
- Run `collectstatic`: `docker exec wealth-py python manage.py collectstatic --noinput`
- Check nginx volume mounts point to correct directories

**Email not working:**
- Test with Django shell: `docker exec -it wealth-py python manage.py shell`
  ```python
  from django.core.mail import send_mail
  send_mail('Test', 'Body', None, ['test@example.com'])
  ```
- Verify EMAIL_USE_TLS vs EMAIL_USE_SSL matches your SMTP port

**Exchange rates not updating:**
- Manually run: `docker exec wealth-py python manage.py fetch_exchange_rates`
- Check logs: `docker logs wealth-py`

## License

MIT
