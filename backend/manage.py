#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import logging
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'wealth.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    try:
        execute_from_command_line(sys.argv)
    except Exception:
        # A crash becomes one standard log entry at ERROR. Printed as a bare traceback (a cron
        # job's output), it would merge into the previous entry in Grafana.
        logging.getLogger('manage').exception('manage.py %s failed', ' '.join(sys.argv[1:]))
        sys.exit(1)


if __name__ == '__main__':
    main()
