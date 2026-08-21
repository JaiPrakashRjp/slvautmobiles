"""One EMI (monthly installment) of a Loan.

The month owes `amount` (the EMI) plus any late `penalty`; part payments
accumulate into `amount_paid` until the whole (amount + penalty) is cleared,
at which point `status` becomes paid and `paid_date` is stamped.
"""
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


class LoanEmi(Base):
    __tablename__ = "loan_emis"
    __table_args__ = (
        UniqueConstraint("loan_id", "sequence_number", name="loan_emis_unique"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    loan_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("loans.id", ondelete="CASCADE"), nullable=False
    )
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )
    sequence_number: Mapped[int] = mapped_column(Integer, nullable=False)  # 1-based
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)  # the EMI
    penalty: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    amount_paid: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    received_date: Mapped[date | None] = mapped_column(Date)  # last payment date
    paid_date: Mapped[date | None] = mapped_column(Date)  # fully cleared on
    remarks: Mapped[str | None] = mapped_column(Text)
    status: Mapped[InstallmentStatus] = mapped_column(
        pg_enum(InstallmentStatus, "installment_status"),
        nullable=False,
        server_default=InstallmentStatus.pending.value,
    )
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    loan: Mapped["Loan"] = relationship(back_populates="emis")  # noqa: F821
