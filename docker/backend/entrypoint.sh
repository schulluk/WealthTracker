#!/bin/bash

# Enter virtual environment
. /venv-python/bin/activate

set -e

DJANGO_PROJECT_NAME="${1}"
BASE_PATH="${2}"

if [ -z "${BASE_PATH}" ]
then
  BASE_PATH='/var/www'
fi
APP_PATH="${BASE_PATH}/app"

# App deps are baked into the image at build time (from the `app` build
# context's requirements.txt) — no pip install here. Dependency changes
# require an image rebuild (`docker compose up -d --build`).

# Chromium is baked into the image (PLAYWRIGHT_BROWSERS_PATH). Self-heal if the
# baked browser somehow drifted from the installed playwright (cheap no-op otherwise).
python -m playwright install chromium >/dev/null 2>&1 || true

# Wait for database
if [ -n "${DATABASE_URL}" ]; then
    echo "Waiting for database..."
    while ! python -c "import psycopg2; psycopg2.connect('${DATABASE_URL}')" 2>/dev/null; do
        sleep 1
    done
    echo "Database is ready!"
fi

# Start a virtual display for headful Chromium (MS's Akamai blocks headless) when
# the MS browser login runs in server mode. gunicorn + cron (below) inherit DISPLAY.
if [ "${MS_SERVER_MODE}" = "1" ]; then
    export DISPLAY="${DISPLAY:-:99}"
    if ! pgrep -x Xvfb >/dev/null 2>&1; then
        # A container restart (e.g. host reboot) keeps /tmp, so the previous run's
        # lock survives. Its PID can match an unrelated process in the new run, and
        # Xvfb then exits with "Server is already active". No Xvfb is running here,
        # so the lock and socket are stale.
        DISPLAY_NUM="${DISPLAY#:}"
        DISPLAY_NUM="${DISPLAY_NUM%%.*}"
        rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"
        echo "Starting Xvfb on ${DISPLAY}..."
        Xvfb "${DISPLAY}" -screen 0 1280x1024x24 -nolisten tcp &
        for _ in 1 2 3 4 5; do
            [ -S "/tmp/.X11-unix/X${DISPLAY_NUM}" ] && break
            sleep 1
        done
        if ! pgrep -x Xvfb >/dev/null 2>&1; then
            echo "WARNING: Xvfb failed to start on ${DISPLAY}; the Morgan Stanley browser login will fail." >&2
        fi
    fi
fi

# Migrate models
yes "yes" | python ${APP_PATH}/manage.py migrate

# Load broker fixtures (idempotent). Kept here — after migrate — so it always
# runs once the DB schema is current. Doing it in a post-deploy script instead
# races container startup, so keep broker seeding inside the entrypoint.
python ${APP_PATH}/manage.py loaddata initial_brokers

# Collect static files
python ${APP_PATH}/manage.py collectstatic --noinput

# Set up cron jobs if crontabs file exists
if test -f "/crontabs"; then
    echo "Setting up cron jobs..."
    # Export environment variables for cron (cron doesn't inherit container env).
    # Include DISPLAY + MS_* + PLAYWRIGHT so cron-triggered syncs find the browser.
    printenv | grep -E '^(DATABASE_URL|SECRET_KEY|FINTS_PRODUCT_ID|ADMIN_EMAIL|EMAIL_|DEFAULT_FROM_EMAIL|DEBUG|ALLOWED_HOSTS|DEMO_USERS|DISPLAY|MS_|PLAYWRIGHT)' | while IFS='=' read -r name value; do
      echo "export ${name}=\"${value}\""
    done > /etc/cron.env
    service cron start
    cat /crontabs | crontab -u root -
fi

# Start gunicorn with uvicorn worker
# GUNICORN_WORKERS defaults to 1 for FinTS 2FA (German banks require maintaining
# an active TCP connection during 2FA - the bank closes dialogs that are
# paused/serialized, making multi-worker 2FA impossible without Redis) and for
# other in-memory state (discovery sessions, sync task queue).
python -m gunicorn \
  ${DJANGO_PROJECT_NAME}.asgi:application \
  --bind 0.0.0.0:8000 \
  --workers ${GUNICORN_WORKERS:-1} \
  --worker-class uvicorn_worker.UvicornWorker \
  --chdir ${APP_PATH} \
  --access-logformat "%({x-forwarded-for}i)s %(l)s %(u)s %(t)s \"%(r)s\" %(s)s %(b)s \"%(f)s\" \"%(a)s\"" \
  --access-logfile -
