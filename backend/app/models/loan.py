"""Loan model — a no-interest loan booked against a customer (and a vehicle).

The customer repays a fixed EMI each month for `tenure_months`; a late month
accrues a penalty entered on that month's payment. EMIs live in LoanEmi,
payments in LoanPayment.
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
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import EntityStatus, pg_enum


class Loan(Base):
    __tablename__ = "loans"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )
    customer_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("customers.id"), nullable=False
    )
    # The loan vehicle (collateral). Nullable so a loan can exist without one.
    vehicle_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("vehicles.id", ondelete="SET NULL")
    )

    principal: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    emi_amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    tenure_months: Mapped[int] = mapped_column(Integer, nullable=False)
    loan_date: Mapped[date] = mapped_column(Date, nullable=False)
    first_due_date: Mapped[date] = mapped_column(Date, nullable=False)

    # 'active' | 'overdue' | 'closed' | 'foreclosed' | 'seized' | 'rejected'
    loan_status: Mapped[str] = mapped_column(Text, nullable=False, server_default="active")
    closed_at: Mapped[datetime | None] = mapped_column()

    # Seizure (repossession of the loan vehicle). seize_stage: NULL (none) |
    # 'pending' (admin requested, awaiting super admin) | 'seized' (confirmed —
    # vehicle repossessed, loan ended). Cancelling clears the stage and the loan
    # continues with the customer.
    seize_stage: Mapped[str | None] = mapped_column(Text)
    seize_reason: Mapped[str | None] = mapped_column(Text)
    seized_by: Mapped[int | None] = mapped_column(BigInteger)
    seized_at: Mapped[datetime | None] = mapped_column()
    seize_confirmed_by: Mapped[int | None] = mapped_column(BigInteger)
    seize_confirmed_at: Mapped[datetime | None] = mapped_column()
    seize_cancel_remarks: Mapped[str | None] = mapped_column(Text)

    # role-gate / audit (admin creates → pending; super admin confirms)
    status: Mapped[EntityStatus] = mapped_column(
        pg_enum(EntityStatus, "entity_status"),
        nullable=False,
        server_default=EntityStatus.pending_confirmation.value,
    )
    created_by: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    confirmed_by: Mapped[int | None] = mapped_column(BigInteger)
    confirmed_at: Mapped[datetime | None] = mapped_column()
    rejection_reason: Mapped[str | None] = mapped_column(Text)
    remarks: Mapped[str | None] = mapped_column(Text)

    emis: Mapped[list["LoanEmi"]] = relationship(  # noqa: F821
        back_populates="loan",
        cascade="all, delete-orphan",
        order_by="LoanEmi.sequence_number",
    )
    payments: Mapped[list["LoanPayment"]] = relationship(  # noqa: F821
        back_populates="loan", cascade="all, delete-orphan"
    )
