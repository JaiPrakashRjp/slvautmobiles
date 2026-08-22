"""One monthly EMI of a PersonalLoan — a flat amount, simply marked paid."""
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    ForeignKey,
    Identity,
    Integer,
    Numeric,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import InstallmentStatus, pg_enum


class PersonalLoanEmi(Base):
    __tablename__ = "personal_loan_emis"
    __table_args__ = (
        UniqueConstraint(
            "personal_loan_id", "sequence_number", name="personal_loan_emis_unique"
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    personal_loan_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("personal_loans.id", ondelete="CASCADE"), nullable=False
    )
    sequence_number: Mapped[int] = mapped_column(Integer, nullable=False)  # 1-based
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    status: Mapped[InstallmentStatus] = mapped_column(
        pg_enum(InstallmentStatus, "installment_status"),
        nullable=False,
        server_default=InstallmentStatus.pending.value,
    )
    paid_date: Mapped[date | None] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    loan: Mapped["PersonalLoan"] = relationship(back_populates="emis")  # noqa: F821
