"""Payment ledger row — a received payment (installment / advance / early payoff)."""
from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Identity, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import PaymentKind, pg_enum


class SalePayment(Base):
    __tablename__ = "sale_payments"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    sale_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("sales.id", ondelete="CASCADE"), nullable=False
    )
    installment_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("sale_installments.id", ondelete="SET NULL")
    )
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    paid_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    kind: Mapped[PaymentKind] = mapped_column(
        pg_enum(PaymentKind, "payment_kind"),
        nullable=False,
        server_default=PaymentKind.installment.value,
    )
    recorded_by: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    sale: Mapped["Sale"] = relationship(back_populates="payments")  # noqa: F821
