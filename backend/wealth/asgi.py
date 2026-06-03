"""
ASGI config for wealth project.

Exposes the ASGI callable as a module-level variable named ``application``.

Composition is raw ASGI (no Channels): Django serves HTTP, and the MS relay
serves its one WebSocket route (``/ws/ms-relay/``). A minimal lifespan handler is
included so the uvicorn worker starts cleanly.

https://docs.djangoproject.com/en/4.2/howto/deployment/asgi/
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'wealth.settings')

_django_app = get_asgi_application()


async def _lifespan(receive, send):
    while True:
        message = await receive()
        if message["type"] == "lifespan.startup":
            await send({"type": "lifespan.startup.complete"})
        elif message["type"] == "lifespan.shutdown":
            await send({"type": "lifespan.shutdown.complete"})
            return


async def _reject_ws(receive, send):
    event = await receive()
    if event["type"] == "websocket.connect":
        await send({"type": "websocket.close", "code": 4404})


async def application(scope, receive, send):
    stype = scope["type"]
    if stype == "websocket":
        from brokers.ms_relay.server import PATH, ms_relay_app
        if scope.get("path") == PATH:
            await ms_relay_app(scope, receive, send)
        else:
            await _reject_ws(receive, send)
        return
    if stype == "lifespan":
        await _lifespan(receive, send)
        return
    await _django_app(scope, receive, send)
