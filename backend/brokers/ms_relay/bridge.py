"""VPS side of the relay.

`RelayBridge` runs a local SOCKS5 server that Chromium uses as its proxy
(`--proxy-server=socks5://127.0.0.1:<port>`, i.e. MS_PROXY). Every accepted
connection is given a stream id and multiplexed to the phone over the frame
channel; bytes are piped both ways. The bridge is transport-agnostic: construct
it with an async `send_frame(frame: bytes)` and feed inbound frames to
`on_frame(frame)`.
"""
import asyncio
import logging
import struct

from . import protocol as P

logger = logging.getLogger(__name__)

_SOCKS_VER = 0x05


async def _socks5_handshake(reader, writer):
    """Do the SOCKS5 no-auth + CONNECT handshake. Return (host, port) or None."""
    # Greeting: VER, NMETHODS, METHODS...
    head = await reader.readexactly(2)
    if head[0] != _SOCKS_VER:
        return None
    await reader.readexactly(head[1])           # method list (ignored)
    writer.write(bytes([_SOCKS_VER, 0x00]))     # select "no auth"
    await writer.drain()

    # Request: VER, CMD, RSV, ATYP, ADDR, PORT
    req = await reader.readexactly(4)
    if req[0] != _SOCKS_VER or req[1] != 0x01:  # only CONNECT
        return None
    atyp = req[3]
    if atyp == 0x01:                            # IPv4
        host = ".".join(str(b) for b in await reader.readexactly(4))
    elif atyp == 0x03:                          # domain
        n = (await reader.readexactly(1))[0]
        host = (await reader.readexactly(n)).decode()
    elif atyp == 0x04:                          # IPv6
        raw = await reader.readexactly(16)
        host = ":".join(raw[i:i + 2].hex() for i in range(0, 16, 2))
    else:
        return None
    port = struct.unpack("!H", await reader.readexactly(2))[0]
    return host, port


async def _socks5_reply(writer, ok: bool):
    # VER, REP, RSV, ATYP=IPv4, BND.ADDR=0.0.0.0, BND.PORT=0
    rep = 0x00 if ok else 0x05
    writer.write(bytes([_SOCKS_VER, rep, 0x00, 0x01, 0, 0, 0, 0, 0, 0]))
    await writer.drain()


class _Stream:
    __slots__ = ("reader", "writer", "open_result")

    def __init__(self, reader, writer):
        self.reader = reader
        self.writer = writer
        self.open_result = asyncio.get_event_loop().create_future()


class RelayBridge:
    def __init__(self, send_frame):
        self._send = send_frame                 # async callable(frame: bytes)
        self._streams: dict[int, _Stream] = {}
        self._next_id = 1
        self._server = None

    async def start_socks(self, host="127.0.0.1", port=0) -> int:
        """Start the SOCKS5 listener; return the bound port."""
        self._server = await asyncio.start_server(self._on_socks_client, host, port)
        bound = self._server.sockets[0].getsockname()[1]
        logger.info("MS relay bridge: SOCKS5 listening on %s:%s", host, bound)
        return bound

    async def stop(self):
        if self._server:
            self._server.close()
            try:
                await self._server.wait_closed()
            except Exception:
                pass
        for sid in list(self._streams):
            self._close_stream(sid)

    async def on_frame(self, frame: bytes):
        """Handle a frame arriving from the exit (phone)."""
        ftype, sid, payload = P.decode(frame)
        stream = self._streams.get(sid)
        if stream is None:
            return
        if ftype == P.OPEN_OK:
            if not stream.open_result.done():
                stream.open_result.set_result(True)
        elif ftype == P.OPEN_ERR:
            if not stream.open_result.done():
                stream.open_result.set_result(False)
        elif ftype == P.DATA:
            try:
                stream.writer.write(payload)
                await stream.writer.drain()
            except Exception:
                self._close_stream(sid)
        elif ftype == P.CLOSE:
            self._close_stream(sid)

    def _close_stream(self, sid: int):
        stream = self._streams.pop(sid, None)
        if stream:
            if not stream.open_result.done():
                stream.open_result.set_result(False)
            try:
                stream.writer.close()
            except Exception:
                pass

    async def _on_socks_client(self, reader, writer):
        try:
            target = await _socks5_handshake(reader, writer)
        except (asyncio.IncompleteReadError, ConnectionError):
            writer.close()
            return
        if target is None:
            await _socks5_reply(writer, False)
            writer.close()
            return

        host, port = target
        sid = self._next_id
        self._next_id += 1
        stream = _Stream(reader, writer)
        self._streams[sid] = stream

        await self._send(P.encode_open(sid, host, port))
        try:
            ok = await asyncio.wait_for(stream.open_result, timeout=30)
        except asyncio.TimeoutError:
            ok = False
        await _socks5_reply(writer, ok)
        if not ok:
            self._close_stream(sid)
            return

        # Pump SOCKS-client bytes -> DATA frames until either side closes.
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                await self._send(P.encode(P.DATA, sid, data))
        except Exception:
            pass
        finally:
            if sid in self._streams:
                try:
                    await self._send(P.encode(P.CLOSE, sid))
                except Exception:
                    pass
            self._close_stream(sid)
