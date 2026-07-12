"""Sale model — a vehicle sold to a customer (full cash or down payment)."""
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
from app.models.enums import DepositType, EntityStatus, SaleLifecycle, pg_enum


class Sale(Base):
    __tablename__ = "sales"

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

    deposit_type: Mapped[DepositType] = mapped_column(
        pg_enum(DepositType, "deposit_type"), nullable=False
    )
    sale_price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    sale_date: Mapped[date | None] = mapped_column(Date)
    amount_received: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    remaining_amount: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    # sale-price breakdown (sale_price/total = sum of these five)
    vehicle_amount: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    additional_fitting: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    dl_charges: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    document_charges: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    other_expenses: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    # HP (hire-purchase / loan) amount — set by super admin only
    hp_amount: Mapped[float | None] = mapped_column(Numeric(12, 2))
    monthly_amount: Mapped[float | None] = mapped_column(Numeric(12, 2))
    installment_count: Mapped[int | None] = mapped_column(Integer)
    first_due_date: Mapped[date | None] = mapped_column(Date)
    customer_whatsapp: Mapped[str | None] = mapped_column(Text)
    invoice_no: Mapped[str | None] = mapped_column(Text)
    sale_status: Mapped[SaleLifecycle] = mapped_column(
        pg_enum(SaleLifecycle, "sale_lifecycle"),
        nullable=False,
        server_default=SaleLifecycle.active.value,
    )
    closed_at: Mapped[datetime | None] = mapped_column()

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
    unsell_reason: Mapped[str | None] = mapped_column(Text)
    # seizure (repossession): set when the vehicle is seized from this customer.
    seized_at: Mapped[datetime | None] = mapped_column()
    seized_by: Mapped[int | None] = mapped_column(BigInteger)
    seize_reason: Mapped[str | None] = mapped_column(Text)
    # seize lifecycle: NULL | 'pending' (admin requested, awaiting super admin) |
    # 'seized' (active — badge shown, cancel/confirm available) | 'confirmed'.
    seize_stage: Mapped[str | None] = mapped_column(Text)
    seize_confirmed_at: Mapped[datetime | None] = mapped_column()
    seize_confirmed_by: Mapped[int | None] = mapped_column(BigInteger)
    seize_confirm_remarks: Mapped[str | None] = mapped_column(Text)
    seize_cancel_remarks: Mapped[str | None] = mapped_column(Text)
    remarks: Mapped[str | None] = mapped_column(Text)

    installments: Mapped[list["SaleInstallment"]] = relationship(  # noqa: F821
        back_populates="sale",
        cascade="all, delete-orphan",
        order_by="SaleInstallment.month_number",
    )
    payments: Mapped[list["SalePayment"]] = relationship(  # noqa: F821
        back_populates="sale", cascade="all, delete-orphan"
    )
    # the sale's own financer (separate master from vehicle financers)
    financer_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("sale_financers.id", ondelete="SET NULL")
    )
    financer: Mapped["SaleFinancer | None"] = relationship()  # noqa: F821

    @property
    def financer_name(self) -> str | None:
        """The sale financer's name, for display."""
        return self.financer.name if self.financer else None
