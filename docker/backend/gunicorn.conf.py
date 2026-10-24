# Gunicorn settings for the backend image: gunicorn, uvicorn and the app all write the
# standard log line (see StdFormatter; backend/wealth/logformat.py has the app's copy, keep the
# two the same), and there is no access log because Traefik already logs every request.
import logging
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    ZONE = ZoneInfo('Europe/Zurich')
except ZoneInfoNotFoundError:  # image without tzdata: fall back to the process time zone
    ZONE = None


class StdFormatter(logging.Formatter):
    """The log line every app on the server writes:

        2026-10-24 08:50:21 INFO     wealth.sync: Synced 3 accounts

    Swiss local time whatever the process time zone is (Django switches it to TIME_ZONE),
    and a traceback continues on the following lines. Alloy keys on the leading timestamp
    to keep those lines in one record and reads the level that follows it.
    """

    def __init__(self):
        super().__init__('%(asctime)s %(levelname)-8s %(name)s: %(message)s', '%Y-%m-%d %H:%M:%S')

    def converter(self, timestamp):
        return datetime.fromtimestamp(timestamp, ZONE).timetuple()

    def format(self, record):
        # gunicorn.error and uvicorn.error carry every server message, not only errors
        if record.name in ('gunicorn.error', 'uvicorn.error'):
            record.name = record.name.partition('.')[0]
        return super().format(record)


logconfig_dict = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'std': {'()': StdFormatter},
    },
    'handlers': {
        'console': {'class': 'logging.StreamHandler', 'formatter': 'std', 'stream': 'ext://sys.stdout'},
    },
    'root': {'level': 'INFO', 'handlers': ['console']},
    'loggers': {
        'gunicorn.error': {'level': 'INFO', 'handlers': ['console'], 'propagate': False},
        # UvicornWorker hands uvicorn's access log to this logger; WARNING keeps it quiet.
        'gunicorn.access': {'level': 'WARNING', 'handlers': [], 'propagate': False},
    },
}
