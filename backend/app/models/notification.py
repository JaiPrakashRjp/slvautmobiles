"""In-app notification — verification alerts to the super admin (NOT WhatsApp)."""
from datetime import datetime

from sqlalchemy import BigInteger, Boolean, ForeignKey, Identity, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.enums import NotificationEntity, NotificationType, pg_enum


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    recipient_user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[NotificationType] = mapped_column(
        pg_enum(NotificationType, "notification_type"),
        nullable=False,
        server_default=NotificationType.verification_request.value,
    )
    title: Mapped[str] = mapped_column(Text, nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    entity_type: Mapped[NotificationEntity | None] = mapped_column(
        pg_enum(NotificationEntity, "notification_entity")
    )
    entity_id: Mapped[int | None] = mapped_column(BigInteger)
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
