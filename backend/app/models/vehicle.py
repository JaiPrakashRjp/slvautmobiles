"""Vehicle model (Auto Sale). Files live in VehicleDocument, not here."""
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    ForeignKey,
    Identity,
    Numeric,
    SmallInteger,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import (
    Branch,
    EntityStatus,
    FuelType,
    InventoryStatus,
    SaleStatus,
    Showroom,
    VehicleHand,
    pg_enum,
)


class Vehicle(Base):
    __tablename__ = "vehicles"
    __table_args__ = (
        CheckConstraint(
            "owned_hand <> 'second_hand' OR reg_no IS NOT NULL",
            name="vehicles_second_hand_reg_no_chk",
        ),
        CheckConstraint(
            "owned_hand <> 'first_hand' OR showroom IS NOT NULL",
            name="vehicles_first_hand_showroom_chk",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )

    # categorisation
    branch: Mapped[Branch] = mapped_column(pg_enum(Branch, "branch"), nullable=False)
    owned_hand: Mapped[VehicleHand] = mapped_column(
        pg_enum(VehicleHand, "vehicle_hand"), nullable=False
    )

    # common
    chassis_no: Mapped[str] = mapped_column(Text, nullable=False)
    model: Mapped[str] = mapped_column(Text, nullable=False)
    fuel_type: Mapped[FuelType | None] = mapped_column(pg_enum(FuelType, "fuel_type"))
    purchase_date: Mapped[date | None] = mapped_column(Date)
    buying_expenses: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))

    # first-hand only
    showroom: Mapped[Showroom | None] = mapped_column(pg_enum(Showroom, "showroom"))
    # RC / Permit / Insurance — independent flags, shown for both hand types
    rc: Mapped[bool] = mapped_column(nullable=False, server_default="false")
    permit: Mapped[bool] = mapped_column(nullable=False, server_default="false")
    insurance: Mapped[bool] = mapped_column(nullable=False, server_default="false")

    remarks: Mapped[str | None] = mapped_column(Text)

    # second-hand only
    reg_no: Mapped[str | None] = mapped_column(Text)
    insurance_date: Mapped[date | None] = mapped_column(Date)
    fc_date: Mapped[date | None] = mapped_column(Date)
    permit_date: Mapped[date | None] = mapped_column(Date)
    prev_owner_name: Mapped[str | None] = mapped_column(Text)
    prev_owner_mobile: Mapped[str | None] = mapped_column(String(10))
    prev_owner_address: Mapped[str | None] = mapped_column(Text)

    # financer (optional FK to the vehicle financer master)
    financer_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("vehicle_financers.id", ondelete="SET NULL")
    )

    # inventory / sale / service
    inventory_status: Mapped[InventoryStatus] = mapped_column(
        pg_enum(InventoryStatus, "inventory_status"),
        nullable=False,
        server_default=InventoryStatus.available.value,
    )
    sale_status: Mapped[SaleStatus] = mapped_column(
        pg_enum(SaleStatus, "sale_status"),
        nullable=False,
        server_default=SaleStatus.not_sold.value,
    )
    next_service_due_date: Mapped[date | None] = mapped_column(Date)
    assigned_to_customer_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("customers.id")
    )

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

    documents: Mapped[list["VehicleDocument"]] = relationship(  # noqa: F821
        back_populates="vehicle", cascade="all, delete-orphan"
    )
