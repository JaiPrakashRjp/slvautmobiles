"""A payment received against a loan EMI (part payments allowed).

Each record is one collection event — its amount, the date received, a note and
optional proof screenshots. The owning EMI's amount_paid / status is updated by
the service when a payment is recorded.
"""
from datetime import date, datetime

from sqlalchemy import BigInteger, Date, ForeignKey, Identity, Numeric, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class LoanPayment(Base):
    __tablename__ = "loan_payments"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    loan_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("loans.id", ondelete="CASCADE"), nullable=False
    )
    emi_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("loan_emis.id", ondelete="SET NULL")
    )
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    # penalty portion applied to the EMI at the time of this payment (for audit).
    penalty: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    received_date: Mapped[date | None] = mapped_column(Date)
    remarks: Mapped[str | None] = mapped_column(Text)
    recorded_by: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    loan: Mapped["Loan"] = relationship(back_populates="payments")  # noqa: F821
    documents: Mapped[list["LoanPaymentDocument"]] = relationship(  # noqa: F821
        back_populates="payment", cascade="all, delete-orphan"
    )

    @property
    def document_ids(self) -> list[int]:
        """Ids of attached proof screenshots (for the API response)."""
        return [d.id for d in self.documents]
