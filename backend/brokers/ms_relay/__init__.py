"""
Morgan Stanley sync relay — route the VPS browser's egress through the user's
phone (a residential/mobile IP) so MS doesn't see the blocked datacenter IP.

The phone is a dumb TCP exit node: it relays raw, TLS-encrypted bytes between the
VPS and MS, so it never sees the user's MS session. Pieces:

- protocol  : the wire frames (multiplexed TCP over one WebSocket).
- bridge    : VPS side. A local SOCKS5 server Chromium uses as its proxy; every
              connection is multiplexed to the phone over the frame channel.
- exit_node : reference exit (Python). The Flutter app reimplements this in Dart:
              receive OPEN/DATA/CLOSE, open real sockets over mobile data, pipe.

Transport-agnostic: bridge/exit take a `send_frame` coroutine and are fed inbound
frames via `on_frame`, so the same logic runs over Django ASGI WebSockets (prod),
a Dart WebSocket (phone), or in-process queues (tests).
"""
