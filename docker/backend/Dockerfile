FROM python:3.14

# Update & install packages
RUN apt-get update && apt-get install -y \
    ca-certificates  \
    sqlite3 \
    cron

# Create virtual environment
RUN python3 -m venv /venv-python --system-site-packages

# Upgrade PIP
RUN . /venv-python/bin/activate && python3 -m pip install -U pip

# Install base dependencies
COPY ./requirements.txt /tmp/base-requirements.txt
RUN . /venv-python/bin/activate && python3 -m pip install -r /tmp/base-requirements.txt

# Install the Chromium browser + OS deps used by the Morgan Stanley login, plus
# Xvfb — MS's Akamai blocks headless Chromium, so it runs HEADFUL under a virtual
# display. PLAYWRIGHT_BROWSERS_PATH makes the install location explicit/cacheable.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN . /venv-python/bin/activate && python3 -m playwright install --with-deps chromium \
    && apt-get update && apt-get install -y --no-install-recommends xvfb && rm -rf /var/lib/apt/lists/*

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

CMD ["/bin/bash", "-c", "/entrypoint.sh ${DJANGO_PROJECT_NAME}"]
