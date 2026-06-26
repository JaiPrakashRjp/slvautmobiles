"""Customer model (Auto Sale). KYC files live in CustomerDocument, not here."""
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    ForeignKey,
    Identity,
    SmallInteger,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import Branch, EntityStatus, pg_enum


class Customer(Base):
    __tablename__ = "customers"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )

    first_name: Mapped[str] = mapped_column(Text, nullable=False)
    last_name: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    phone: Mapped[str] = mapped_column(String(10), nullable=False)
    address: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    branch: Mapped[Branch | None] = mapped_column(pg_enum(Branch, "branch"))
    age: Mapped[int | None] = mapped_column(SmallInteger)
    dob: Mapped[date | None] = mapped_column(Date)

    # guarantor / assurity person
    assurity_name: Mapped[str | None] = mapped_column(Text)
    assurity_mobile: Mapped[str | None] = mapped_column(String(10))

    remarks: Mapped[str | None] = mapped_column(Text)

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

    documents: Mapped[list["CustomerDocument"]] = relationship(  # noqa: F821
        back_populates="customer", cascade="all, delete-orphan"
    )
