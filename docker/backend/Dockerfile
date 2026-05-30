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

# Install the Chromium browser + OS deps used by the Morgan Stanley headless login.
# PLAYWRIGHT_BROWSERS_PATH makes the install location explicit and cache-friendly.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN . /venv-python/bin/activate && python3 -m playwright install --with-deps chromium

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

CMD ["/bin/bash", "-c", "/entrypoint.sh ${DJANGO_PROJECT_NAME}"]
