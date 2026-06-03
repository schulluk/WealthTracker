"""ASGI WebSocket endpoint for the MS relay — the VPS/bridge side.

The user's phone (or the ``ms_relay_exit`` stand-in) connects here as the relay
EXIT. This side runs a :class:`RelayBridge` plus a local SOCKS5 server that
Chromium uses during the Morgan Stanley sync, so MS sees the phone's residential
IP instead of the datacenter. Raw ASGI — no Channels.

Authentication: the user's SimpleJWT *access* token, taken from the
``Authorization: Bearer …`` header or a ``?token=…`` query parameter. Only the
``user_id`` claim is needed (signature + expiry are verified; no DB hit), which
binds the relay to that user so their sync — and only theirs — routes through it.
"""
import logging
from urllib.parse import parse_qs

from . import registry
from .bridge import RelayBridge

logger = logging.getLogger(__name__)

PATH = "/ws/ms-relay/"


def _token_from_scope(scope) -> str | None:
    for name, value in scope.get("headers", []):
        if name == b"authorization":
            v = value.decode("latin1")
            if v[:7].lower() == "bearer ":
                return v[7:].strip()
    qs = parse_qs(scope.get("query_string", b"").decode("latin1"))
    vals = qs.get("token")
    return vals[0] if vals else None


def _user_id_from_token(token: str) -> int | None:
    from rest_framework_simplejwt.exceptions import TokenError
    from rest_framework_simplejwt.tokens import AccessToken
    try:
        return AccessToken(token)["user_id"]
    except (TokenError, KeyError):
        return None


async def ms_relay_app(scope, receive, send):
    """ASGI app for a single MS-relay WebSocket connection."""
    assert scope["type"] == "websocket"

    event = await receive()
    if event["type"] != "websocket.connect":
        return

    token = _token_from_scope(scope)
    user_id = _user_id_from_token(token) if token else None
    if user_id is None:
        await send({"type": "websocket.close", "code": 4401})  # unauthorized
        logger.warning("MS relay: rejected unauthenticated connection")
        return

    await send({"type": "websocket.accept"})

    async def send_frame(frame: bytes):
        await send({"type": "websocket.send", "bytes": frame})

    bridge = RelayBridge(send_frame=send_frame)
    port = await bridge.start_socks()
    registry.register(user_id, port)
    try:
        while True:
            event = await receive()
            etype = event["type"]
            if etype == "websocket.receive":
                data = event.get("bytes")
                if data:
                    await bridge.on_frame(data)
            elif etype == "websocket.disconnect":
                break
    except Exception:
        logger.exception("MS relay: receive loop error (user=%s)", user_id)
    finally:
        registry.unregister(user_id)
        await bridge.stop()
        logger.info("MS relay: closed (user=%s)", user_id)
