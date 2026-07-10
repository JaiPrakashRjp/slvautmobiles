"""Device token model — an app install's FCM token, used to push to that phone."""
from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Identity, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    # The FCM registration token is unique per app install; if a different user
    # signs in on the same device, we re-point the existing row to them.
    token: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    platform: Mapped[str | None] = mapped_column(Text)  # android | ios
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
