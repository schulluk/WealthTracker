#!/bin/bash

# Enter virtual environment
. /venv-python/bin/activate

set -e

DJANGO_PROJECT_NAME="${1}"
BASE_PATH='/var/www'
APP_PATH="${BASE_PATH}/app"

# Install pip requirements
if [ -f ${APP_PATH}/requirements.txt ]; then
    python -m pip install --no-cache-dir --upgrade -r ${APP_PATH}/requirements.txt
fi

# Wait for database
echo "Waiting for database..."
while ! python -c "import psycopg2; psycopg2.connect('${DATABASE_URL}')" 2>/dev/null; do
    sleep 1
done
echo "Database is ready!"

# Migrate models
yes "yes" | python ${APP_PATH}/manage.py migrate

# Collect static files
python ${APP_PATH}/manage.py collectstatic --noinput

# Set up cron jobs if crontabs file exists
if test -f "/crontabs"; then
    echo "Setting up cron jobs..."
    # Export environment variables for cron (cron doesn't inherit container env)
    # Use proper quoting to handle values with spaces/special chars
    printenv | grep -E '^(DATABASE_URL|SECRET_KEY|FINTS_PRODUCT_ID|ADMIN_EMAIL|EMAIL_|DEFAULT_FROM_EMAIL|DEBUG|ALLOWED_HOSTS|DEMO_USERS)' | while IFS='=' read -r name value; do
      echo "export ${name}=\"${value}\""
    done > /etc/cron.env
    service cron start
    cat /crontabs | crontab -u root -
fi

# Start gunicorn with uvicorn worker
# GUNICORN_WORKERS defaults to 1 for FinTS 2FA (German banks require maintaining
# an active TCP connection during 2FA - the bank closes dialogs that are
# paused/serialized, making multi-worker 2FA impossible without Redis).
python -m gunicorn \
  ${DJANGO_PROJECT_NAME}.asgi:application \
  --bind 0.0.0.0:8000 \
  --workers ${GUNICORN_WORKERS:-1} \
  --worker-class uvicorn_worker.UvicornWorker \
  --chdir ${APP_PATH} \
  --access-logformat "%({x-forwarded-for}i)s %(l)s %(u)s %(t)s \"%(r)s\" %(s)s %(b)s \"%(f)s\" \"%(a)s\"" \
  --access-logfile -
