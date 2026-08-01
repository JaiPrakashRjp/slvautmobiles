"""Rental model — a vehicle rented to a customer (advance + rent collection).

Mirrors Sale: a rental header with a total, an advance, and a remaining amount
that drops as rent payments come in. Role-gated (admin → pending_confirmation,
super_admin → active) and repossess-able (seize).
"""
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    ForeignKey,
    Identity,
    Numeric,
    SmallInteger,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import EntityStatus, RentalLifecycle, RentalType, pg_enum


class Rental(Base):
    __tablename__ = "rentals"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )
    vehicle_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("vehicles.id"), nullable=False
    )
    customer_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("customers.id"), nullable=False
    )

    # Recurring rent model: rent is charged per period (weekly/daily) and rolls
    # forward from each payment. total_amount is nullable (legacy balance model
    # only); recurring rentals use rental_type + period_amount instead.
    rental_type: Mapped[RentalType | None] = mapped_column(
        pg_enum(RentalType, "rental_type")
    )
    period_amount: Mapped[float | None] = mapped_column(Numeric(12, 2))
    total_amount: Mapped[float | None] = mapped_column(Numeric(12, 2))
    advance_amount: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    remaining_amount: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    start_date: Mapped[date | None] = mapped_column(Date)
    invoice_no: Mapped[str | None] = mapped_column(Text)
    remarks: Mapped[str | None] = mapped_column(Text)

    rental_status: Mapped[RentalLifecycle] = mapped_column(
        pg_enum(RentalLifecycle, "rental_lifecycle"),
        nullable=False,
        server_default=RentalLifecycle.active.value,
    )
    completed_at: Mapped[datetime | None] = mapped_column()

    # role-gate / audit
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

    # seizure (repossession) — set when the vehicle is taken back from the renter
    seized_at: Mapped[datetime | None] = mapped_column()
    seized_by: Mapped[int | None] = mapped_column(BigInteger)
    seize_reason: Mapped[str | None] = mapped_column(Text)
    # NULL | 'pending' (admin requested, awaiting super admin) | 'seized'
    seize_stage: Mapped[str | None] = mapped_column(Text)

    # edit approval (admin's edit held until a super admin approves)
    pending_edit: Mapped[dict | None] = mapped_column(JSONB)
    edit_stage: Mapped[str | None] = mapped_column(Text)
    edit_requested_by: Mapped[int | None] = mapped_column(BigInteger)

    installments: Mapped[list["RentalInstallment"]] = relationship(  # noqa: F821
        back_populates="rental",
        cascade="all, delete-orphan",
        order_by="RentalInstallment.number",
    )
    payments: Mapped[list["RentalPayment"]] = relationship(  # noqa: F821
        back_populates="rental", cascade="all, delete-orphan"
    )
