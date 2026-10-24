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
    # cron starts its jobs with an almost empty environment. Save the container's (DJANGO_*,
    # DISPLAY, MS_*, PLAYWRIGHT_* and the rest), quoted for sh, and let every job's bash read it
    # through BASH_ENV, so cron-triggered commands see the same settings as gunicorn.
    python -c 'import os, re, shlex; print("".join(f"export {k}={shlex.quote(v)}\n" for k, v in sorted(os.environ.items()) if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k) and k not in ("HOME", "OLDPWD", "PWD", "SHLVL", "_")))' > /etc/cron.env
    chmod 600 /etc/cron.env
    service cron start
    { echo 'SHELL=/bin/bash'; echo 'BASH_ENV=/etc/cron.env'; cat /crontabs; } | crontab -u root -
fi

# Start gunicorn with uvicorn worker
# GUNICORN_WORKERS defaults to 1 for FinTS 2FA (German banks require maintaining
# an active TCP connection during 2FA - the bank closes dialogs that are
# paused/serialized, making multi-worker 2FA impossible without Redis) and for
# other in-memory state (discovery sessions, sync task queue).
# gunicorn.conf.py sets the standard log line and leaves out the access log.
python -m gunicorn \
  ${DJANGO_PROJECT_NAME}.asgi:application \
  --config /etc/gunicorn/gunicorn.conf.py \
  --bind 0.0.0.0:8000 \
  --workers ${GUNICORN_WORKERS:-1} \
  --worker-class uvicorn_worker.UvicornWorker \
  --chdir ${APP_PATH}
