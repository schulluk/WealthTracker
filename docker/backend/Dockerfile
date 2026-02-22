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

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

CMD ["/bin/bash", "-c", "/entrypoint.sh ${DJANGO_PROJECT_NAME}"]
