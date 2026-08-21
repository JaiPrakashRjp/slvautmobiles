"""Personal loan — a simple monthly-EMI loan (no interest, no penalty).

Captures a vehicle number, a (personal-loan-scoped) financer, the loan/EMI
amounts, tenure and the phone to remind. EMIs are a flat monthly schedule; each
month is simply marked paid.
"""
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    ForeignKey,
    Identity,
    Integer,
    Numeric,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class PersonalLoan(Base):
    __tablename__ = "personal_loans"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    vehicle_number: Mapped[str] = mapped_column(Text, nullable=False)
    financer_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("personal_loan_financers.id", ondelete="SET NULL")
    )
    loan_amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    emi_amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    tenure_months: Mapped[int] = mapped_column(Integer, nullable=False)
    loan_date: Mapped[date] = mapped_column(Date, nullable=False)
    first_due_date: Mapped[date] = mapped_column(Date, nullable=False)
    # Phone the monthly reminder is sent to (WhatsApp).
    phone: Mapped[str | None] = mapped_column(Text)

    loan_status: Mapped[str] = mapped_column(Text, nullable=False, server_default="active")
    closed_at: Mapped[datetime | None] = mapped_column()
    remarks: Mapped[str | None] = mapped_column(Text)

    created_by: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    financer: Mapped["PersonalLoanFinancer | None"] = relationship()  # noqa: F821
    emis: Mapped[list["PersonalLoanEmi"]] = relationship(  # noqa: F821
        back_populates="loan",
        cascade="all, delete-orphan",
        order_by="PersonalLoanEmi.sequence_number",
    )

    @property
    def financer_name(self) -> str | None:
        return self.financer.name if self.financer else None
