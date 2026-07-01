"""WhatsApp sender — Meta Cloud API.

Thin wrapper over `POST /{phone_number_id}/messages`. Every call returns a
(ok, message_id, error) tuple so callers can log the outcome to reminder_logs
(sent + provider_message_id, or failed + error) — see the reminder logging
requirement. No exception ever escapes.
"""
from __future__ import annotations

import re

import httpx

from app.config import settings

GRAPH_URL = "https://graph.facebook.com/v21.0"


def _normalize(number: str) -> str:
    """Meta wants digits with country code and no '+' / spaces."""
    return re.sub(r"\D", "", number or "")


class WhatsAppService:
    @staticmethod
    def _send(payload: dict) -> tuple[bool, str | None, str | None]:
        if not settings.whatsapp_enabled:
            return False, None, "WhatsApp is not configured (token/phone id missing)"
        url = f"{GRAPH_URL}/{settings.WHATSAPP_PHONE_NUMBER_ID}/messages"
        headers = {"Authorization": f"Bearer {settings.WHATSAPP_TOKEN}"}
        try:
            resp = httpx.post(url, headers=headers, json=payload, timeout=20.0)
        except Exception as e:  # network / DNS / timeout
            return False, None, f"request failed: {e}"
        if resp.status_code >= 400:
            # surface Meta's error body so failures are auditable
            return False, None, resp.text
        try:
            msg_id = resp.json()["messages"][0]["id"]
        except Exception:
            msg_id = None
        return True, msg_id, None

    @staticmethod
    def send_template(
        to: str,
        template: str,
        *,
        lang: str = "en_US",
        components: list | None = None,
    ) -> tuple[bool, str | None, str | None]:
        """Send an approved template message. Returns (ok, message_id, error)."""
        tmpl: dict = {"name": template, "language": {"code": lang}}
        if components:
            tmpl["components"] = components
        payload = {
            "messaging_product": "whatsapp",
            "to": _normalize(to),
            "type": "template",
            "template": tmpl,
        }
        return WhatsAppService._send(payload)
