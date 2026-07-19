"""Mint a short-lived SimpleJWT access token for the MS relay (testing helper).

The relay WebSocket (`/ws/ms-relay/`) authenticates with the user's access token.
This prints one (and, with --url, the ready-to-run ms_relay_exit command) so you
don't need the rest_framework_simplejwt shell incantation each time.

    python manage.py ms_relay_token --user alice
    python manage.py ms_relay_token --user alice --url wss://your-server.example.com/ws/ms-relay/

On the server:
    <compose exec> wealth-py /venv-python/bin/python /var/www/app/manage.py \\
        ms_relay_token --user alice --url wss://your-server.example.com/ws/ms-relay/
"""
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Mint a SimpleJWT access token for the MS relay WebSocket (testing)."

    def add_arguments(self, parser):
        parser.add_argument("--user", help="Username (defaults to the only user if there's just one)")
        parser.add_argument("--url", help="If given, also print the full ms_relay_exit command")

    def handle(self, *args, **opts):
        from rest_framework_simplejwt.tokens import RefreshToken

        User = get_user_model()
        username = opts.get("user")
        if username:
            try:
                user = User.objects.get(username=username)
            except User.DoesNotExist:
                names = ", ".join(User.objects.values_list("username", flat=True)[:50]) or "(none)"
                raise CommandError(f"No user '{username}'. Available: {names}")
        else:
            users = list(User.objects.all()[:2])
            if len(users) == 1:
                user = users[0]
            else:
                names = ", ".join(User.objects.values_list("username", flat=True)[:50]) or "(none)"
                raise CommandError(f"--user is required (more than one user). Available: {names}")

        token = str(RefreshToken.for_user(user).access_token)
        self.stdout.write(self.style.SUCCESS(token))

        url = opts.get("url")
        if url:
            self.stdout.write("")
            self.stdout.write(self.style.HTTP_INFO(
                f"python manage.py ms_relay_exit --url {url} --token {token}"
            ))
        self.stderr.write(f"(user={user.username}, valid 60 min)")
