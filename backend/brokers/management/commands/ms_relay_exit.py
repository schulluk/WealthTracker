"""Run the MS relay EXIT node (a stand-in for the phone) from this machine.

Connects to the wealth server's ``/ws/ms-relay/`` WebSocket as the relay exit and
forwards raw TCP over whatever network this machine sits on. This lets a laptop
on a residential connection substitute for the phone, so a full Morgan Stanley
sync can be validated over the relay before any Dart exit exists.

The exit only ever forwards already-encrypted bytes — it never sees the MS
session. Authentication uses the user's SimpleJWT *access* token (the same token
the app uses); the server binds the relay to that user, so their MS sync routes
through this exit.

Example (laptop as the residential exit for a server-side sync):

    python manage.py ms_relay_exit \\
        --url wss://your-server.example.com/ws/ms-relay/ \\
        --token <access-jwt>

Then trigger the MS sync from the app (or the test_ms_login command on the
server); its browser egress will exit through this machine.
"""
import asyncio
from urllib.parse import urlparse

from django.core.management.base import BaseCommand, CommandError

from brokers.ms_relay.exit_node import RelayExit


class Command(BaseCommand):
    help = "Run the MS relay exit node (phone stand-in), connecting to the server WebSocket."

    def add_arguments(self, parser):
        parser.add_argument("--url", required=True, help="WebSocket URL, e.g. wss://your-server.example.com/ws/ms-relay/")
        parser.add_argument("--token", required=True, help="SimpleJWT access token for the user")
        parser.add_argument("--insecure", action="store_true", help="Skip TLS verification (local testing only)")

    def handle(self, *args, **opts):
        try:
            import websockets  # noqa: F401
        except ImportError:
            raise CommandError("The 'websockets' package is required: pip install websockets")
        try:
            asyncio.run(self._run(opts["url"], opts["token"], opts["insecure"]))
        except KeyboardInterrupt:
            self.stdout.write("\nRelay exit stopped.")

    async def _run(self, url, token, insecure):
        import ssl

        import websockets

        # Token in the query string keeps us independent of websockets-version
        # header-kwarg naming (extra_headers vs additional_headers).
        sep = "&" if urlparse(url).query else "?"
        full_url = f"{url}{sep}token={token}"

        ssl_ctx = None
        if url.startswith("wss://"):
            ssl_ctx = ssl.create_default_context()
            if insecure:
                ssl_ctx.check_hostname = False
                ssl_ctx.verify_mode = ssl.CERT_NONE

        self.stdout.write(f"Connecting to {urlparse(url).netloc} as relay exit …")
        async with websockets.connect(
            full_url, ssl=ssl_ctx, max_size=None, ping_interval=20, ping_timeout=20,
        ) as ws:
            self.stdout.write(self.style.SUCCESS(
                "Relay exit connected. Forwarding traffic (Ctrl-C to stop)."
            ))

            async def send_frame(frame: bytes):
                await ws.send(frame)

            exit_node = RelayExit(send_frame=send_frame)
            async for message in ws:
                if isinstance(message, (bytes, bytearray)):
                    await exit_node.on_frame(bytes(message))
