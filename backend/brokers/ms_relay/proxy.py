"""Resolve the per-user relay SOCKS proxy for an MS sync.

The MS integration calls :func:`relay_proxy_for_account` from the sync worker
thread. When the account owner's phone/exit is connected, it returns a
``socks5://127.0.0.1:<port>`` URL that Chromium uses so MS sees a residential IP;
otherwise None (and, in server mode, the sync is skipped with an "open the app"
message — see ``MorganStanleyIntegration._browser_authenticate``).
"""
import logging

from . import registry

logger = logging.getLogger(__name__)


def relay_proxy_for_user(user_id) -> str | None:
    port = registry.get_port(user_id)
    if port is None:
        return None
    return f"socks5://127.0.0.1:{port}"


def relay_proxy_for_account(account_id) -> str | None:
    """SOCKS proxy URL for the account owner's relay, or None if not connected."""
    if account_id is None:
        return None
    try:
        from portfolio.models import FinancialAccount
        user_id = FinancialAccount.objects.values_list("user_id", flat=True).get(pk=account_id)
    except Exception as exc:  # account gone, DB error, etc. — treat as no relay
        logger.warning("relay_proxy_for_account(%s) failed: %s", account_id, exc)
        return None
    return relay_proxy_for_user(user_id)
