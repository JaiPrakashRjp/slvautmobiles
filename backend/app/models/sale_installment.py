"""One monthly installment row of a down-payment sale's schedule."""
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    ForeignKey,
    Identity,
    Integer,
    Numeric,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import InstallmentStatus, pg_enum


class SaleInstallment(Base):
    __tablename__ = "sale_installments"
    __table_args__ = (
        UniqueConstraint("sale_id", "month_number", name="sale_installments_unique"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    sale_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("sales.id", ondelete="CASCADE"), nullable=False
    )
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )
    month_number: Mapped[int] = mapped_column(Integer, nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    paid_date: Mapped[date | None] = mapped_column(Date)
    status: Mapped[InstallmentStatus] = mapped_column(
        pg_enum(InstallmentStatus, "installment_status"),
        nullable=False,
        server_default=InstallmentStatus.pending.value,
    )
    # reminder ownership + call lock (who is handling this collection call)
    created_by: Mapped[int | None] = mapped_column(BigInteger)
    taken_by: Mapped[int | None] = mapped_column(BigInteger)
    taken_at: Mapped[datetime | None] = mapped_column()
    cancel_reason: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    sale: Mapped["Sale"] = relationship(back_populates="installments")  # noqa: F821
