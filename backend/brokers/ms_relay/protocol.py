"""Wire protocol for the MS relay.

Each WebSocket message is exactly one binary frame:

    byte 0      : type
    bytes 1..5  : stream id (uint32, big-endian)
    bytes 5..   : payload (type-specific)

Types:
    OPEN    (1)  bridge -> exit   open a TCP stream. payload = hostlen(1) host(utf8) port(uint16)
    OPEN_OK (2)  exit -> bridge   stream connected.  payload = (none)
    OPEN_ERR(3)  exit -> bridge   connect failed.    payload = reason(utf8)
    DATA    (4)  both directions  relay bytes.        payload = raw bytes
    CLOSE   (5)  both directions  close the stream.   payload = (none)

A stream id is allocated by the bridge per SOCKS connection and is unique for the
life of one relay session.
"""
import struct

OPEN = 1
OPEN_OK = 2
OPEN_ERR = 3
DATA = 4
CLOSE = 5

_HEADER = struct.Struct("!BI")          # type (1), stream id (4)
_PORT = struct.Struct("!H")


def encode(ftype: int, stream_id: int, payload: bytes = b"") -> bytes:
    return _HEADER.pack(ftype, stream_id) + payload


def decode(frame: bytes):
    """Return (ftype, stream_id, payload)."""
    ftype, stream_id = _HEADER.unpack_from(frame, 0)
    return ftype, stream_id, frame[_HEADER.size:]


def encode_open(stream_id: int, host: str, port: int) -> bytes:
    hb = host.encode("idna") if any(ord(c) > 127 for c in host) else host.encode()
    if len(hb) > 255:
        raise ValueError("host too long")
    return encode(OPEN, stream_id, bytes([len(hb)]) + hb + _PORT.pack(port))


def decode_open(payload: bytes):
    """Return (host, port) from an OPEN payload."""
    hlen = payload[0]
    host = payload[1:1 + hlen].decode()
    port = _PORT.unpack_from(payload, 1 + hlen)[0]
    return host, port
