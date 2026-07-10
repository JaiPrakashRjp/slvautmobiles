"""Schemas for device (FCM) token registration."""
from pydantic import BaseModel


class DeviceTokenIn(BaseModel):
    token: str
    platform: str | None = None  # android | ios
