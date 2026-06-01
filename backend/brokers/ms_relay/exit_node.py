"""Reference exit node (the phone's role).

`RelayExit` receives OPEN/DATA/CLOSE frames, opens real TCP sockets to the target
(over whatever network it runs on — the phone's mobile data), and pipes bytes
back. The Flutter app reimplements exactly this in Dart (WebSocket <-> dart:io
Socket, multiplexed by stream id). It only ever forwards raw, already-encrypted
bytes — it never sees the MS session.

Transport-agnostic: construct with an async `send_frame(frame)` and feed inbound
frames to `on_frame(frame)`. Also usable standalone (e.g. on a laptop) for tests.
"""
import asyncio
import logging

from . import protocol as P

logger = logging.getLogger(__name__)


class RelayExit:
    def __init__(self, send_frame):
        self._send = send_frame
        self._writers: dict[int, asyncio.StreamWriter] = {}

    async def on_frame(self, frame: bytes):
        ftype, sid, payload = P.decode(frame)
        if ftype == P.OPEN:
            host, port = P.decode_open(payload)
            asyncio.create_task(self._open(sid, host, port))
        elif ftype == P.DATA:
            writer = self._writers.get(sid)
            if writer:
                try:
                    writer.write(payload)
                    await writer.drain()
                except Exception:
                    self._close(sid)
        elif ftype == P.CLOSE:
            self._close(sid)

    def _close(self, sid: int):
        writer = self._writers.pop(sid, None)
        if writer:
            try:
                writer.close()
            except Exception:
                pass

    async def _open(self, sid: int, host: str, port: int):
        try:
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(host, port), timeout=20
            )
        except Exception as exc:
            await self._send(P.encode(P.OPEN_ERR, sid, str(exc)[:120].encode()))
            return
        self._writers[sid] = writer
        await self._send(P.encode(P.OPEN_OK, sid))
        # Pump target bytes -> DATA frames until the connection closes.
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                await self._send(P.encode(P.DATA, sid, data))
        except Exception:
            pass
        finally:
            if sid in self._writers:
                try:
                    await self._send(P.encode(P.CLOSE, sid))
                except Exception:
                    pass
            self._close(sid)
