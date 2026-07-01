"""Reminder log — one row per recipient per reminder; sent_at = when dispatched."""
from datetime import date, datetime

from sqlalchemy import BigInteger, Date, ForeignKey, Identity, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.enums import (
    ReminderChannel,
    ReminderRecipient,
    ReminderStatus,
    pg_enum,
)


class ReminderLog(Base):
    __tablename__ = "reminder_logs"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    # nullable so standalone / test sends (not tied to a sale) can be logged too
    sale_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("sales.id", ondelete="CASCADE")
    )
    installment_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("sale_installments.id", ondelete="SET NULL")
    )
    recipient_type: Mapped[ReminderRecipient] = mapped_column(
        pg_enum(ReminderRecipient, "reminder_recipient"), nullable=False
    )
    recipient_phone: Mapped[str] = mapped_column(Text, nullable=False)
    channel: Mapped[ReminderChannel] = mapped_column(
        pg_enum(ReminderChannel, "reminder_channel"),
        nullable=False,
        server_default=ReminderChannel.whatsapp.value,
    )
    message: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    due_date: Mapped[date | None] = mapped_column(Date)
    sent_at: Mapped[datetime | None] = mapped_column()
    status: Mapped[ReminderStatus] = mapped_column(
        pg_enum(ReminderStatus, "reminder_status"),
        nullable=False,
        server_default=ReminderStatus.pending.value,
    )
    provider_message_id: Mapped[str | None] = mapped_column(Text)
    error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
