"""Rent payment ledger row — a received rent payment (installment / manual)."""
from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Identity, Numeric, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import EntityStatus, PaymentKind, pg_enum


class RentalPayment(Base):
    __tablename__ = "rental_payments"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    rental_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("rentals.id", ondelete="CASCADE"), nullable=False
    )
    installment_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("rental_installments.id", ondelete="SET NULL")
    )
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    paid_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    kind: Mapped[PaymentKind] = mapped_column(
        pg_enum(PaymentKind, "payment_kind"),
        nullable=False,
        server_default=PaymentKind.installment.value,
    )
    recorded_by: Mapped[int] = mapped_column(BigInteger, nullable=False)

    # super-admin approval gate: admin-submitted payments wait as
    # pending_confirmation; super-admin submissions are active immediately.
    status: Mapped[EntityStatus] = mapped_column(
        pg_enum(EntityStatus, "entity_status"),
        nullable=False,
        server_default=EntityStatus.active.value,
    )
    confirmed_by: Mapped[int | None] = mapped_column(BigInteger)
    confirmed_at: Mapped[datetime | None] = mapped_column()
    rejection_reason: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    rental: Mapped["Rental"] = relationship(back_populates="payments")  # noqa: F821
    documents: Mapped[list["RentalPaymentDocument"]] = relationship(  # noqa: F821
        back_populates="payment", cascade="all, delete-orphan"
    )

    @property
    def document_ids(self) -> list[int]:
        """Ids of attached proof screenshots (for the API response)."""
        return [d.id for d in self.documents]
