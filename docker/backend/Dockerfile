FROM python:3.14

# Backend image for the Wealth Tracker: gunicorn/uvicorn Django server with a
# headful browser baked in — MS at Work's Akamai blocks headless Chromium, so
# the Morgan Stanley login runs HEADFUL under a virtual display (Xvfb).
#
# App code is NOT copied into the image — it is bind-mounted at /var/www/app
# at runtime. Python deps ARE baked in at build time from the app's
# requirements.txt, passed as the `app` additional build context:
#
#   build:
#     context: ./docker/backend
#     additional_contexts:
#       - app=./backend
#
# Dependency changes therefore need an image rebuild (`docker compose up -d
# --build` — a changed requirements.txt busts the layer cache).

# Update & install packages (+ xvfb for the virtual display)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    sqlite3 \
    cron \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python3 -m venv /venv-python --system-site-packages

# Upgrade PIP
RUN . /venv-python/bin/activate && python3 -m pip install -U pip

# Install server deps (gunicorn/uvicorn)
COPY ./requirements.txt /tmp/base-requirements.txt
RUN . /venv-python/bin/activate && python3 -m pip install -r /tmp/base-requirements.txt

# Bake the app's Python deps (incl. playwright) into the image
COPY --from=app requirements.txt /tmp/app-requirements.txt
RUN . /venv-python/bin/activate && python3 -m pip install --no-cache-dir -r /tmp/app-requirements.txt

# Bake Playwright's Chromium into the image at PLAYWRIGHT_BROWSERS_PATH — no
# runtime download and no volume needed. Runs AFTER the app deps install so
# the baked browser matches the app's playwright pin.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN . /venv-python/bin/activate && python3 -m playwright install --with-deps chromium

COPY ./gunicorn.conf.py /etc/gunicorn/gunicorn.conf.py
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

CMD ["/bin/bash", "-c", "/entrypoint.sh ${DJANGO_PROJECT_NAME} ${CHDIR_BASE_PATH}"]
