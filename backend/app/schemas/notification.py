"""Pydantic schemas for in-app notifications."""
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.enums import NotificationEntity, NotificationType


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    recipient_user_id: int
    type: NotificationType
    title: str
    message: str
    entity_type: NotificationEntity | None = None
    entity_id: int | None = None
    is_read: bool
    created_at: datetime
