"""FCM push sender (Firebase Admin SDK).

Sends data+notification messages to device tokens. Best-effort: no exception
ever escapes, so a push failure never breaks the request that triggered it.
Delivery reaches the app even when it is closed/killed (unlike local notifications).
"""
from __future__ import annotations

import firebase_admin
from firebase_admin import credentials, messaging

from app.config import settings

_initialized = False


def _ensure_init() -> bool:
    """Lazily initialise the Firebase app from the service-account file."""
    global _initialized
    if _initialized:
        return True
    if not settings.fcm_enabled:
        return False
    try:
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_FILE)
        # Guard against double-init if another code path already created it.
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        _initialized = True
        return True
    except Exception:
        return False


class FcmService:
    @staticmethod
    def send(
        tokens: list[str],
        *,
        title: str,
        body: str,
        data: dict | None = None,
    ) -> None:
        """Push a notification to the given device tokens. Silent on any error."""
        tokens = [t for t in (tokens or []) if t]
        if not tokens or not _ensure_init():
            return
        try:
            message = messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(title=title, body=body),
                # data values must be strings; the app reads these for routing.
                data={k: str(v) for k, v in (data or {}).items()},
                android=messaging.AndroidConfig(priority="high"),
            )
            messaging.send_each_for_multicast(message)
        except Exception:
            # best-effort — never propagate
            return
