"""Process-global registry of connected MS relays (one entry per user).

The relay WebSocket handler (running in the ASGI event loop) registers a user's
local SOCKS port here when their phone — or the `ms_relay_exit` stand-in —
connects. The sync worker thread later reads that port to point Chromium's proxy
at the right SOCKS server. Only the port (an int) ever crosses the
event-loop ↔ sync-thread boundary; the ``RelayBridge`` itself stays in the loop.

Single-process assumption: the wealth ASGI service runs ONE worker
(``GUNICORN_WORKERS=1``) so the WS connection, the sync request, and the sync
worker thread all share this module's state — the same pattern FinTS 2FA already
relies on. See docs/morgan-stanley-integration.md.
"""
import logging
import threading
import time

logger = logging.getLogger(__name__)

_lock = threading.Lock()
_sessions: dict[int, dict] = {}   # user_id -> {"port": int, "since": float}


def register(user_id: int, port: int) -> None:
    """Record that ``user_id`` has a relay whose SOCKS5 server listens on ``port``."""
    with _lock:
        _sessions[int(user_id)] = {"port": port, "since": time.time()}
    logger.info("MS relay registered: user=%s socks_port=%s", user_id, port)


def unregister(user_id: int) -> None:
    with _lock:
        _sessions.pop(int(user_id), None)
    logger.info("MS relay unregistered: user=%s", user_id)


def get_port(user_id: int) -> int | None:
    """The localhost SOCKS port for ``user_id``'s relay, or None if not connected."""
    with _lock:
        sess = _sessions.get(int(user_id))
    return sess["port"] if sess else None


def is_connected(user_id: int) -> bool:
    return get_port(user_id) is not None


def active_sessions() -> dict[int, dict]:
    """Snapshot of all connected relays (for status/debug)."""
    with _lock:
        return {uid: dict(s) for uid, s in _sessions.items()}
