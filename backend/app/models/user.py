"""User model — staff who log in (super admin creates admins)."""
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    ForeignKey,
    Identity,
    SmallInteger,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import AccountStatus, EntityStatus, pg_enum


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    first_name: Mapped[str] = mapped_column(Text, nullable=False)
    last_name: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
    email: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    phone: Mapped[str] = mapped_column(String(10), nullable=False)
    role_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("roles.id"), nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    account_status: Mapped[AccountStatus] = mapped_column(
        pg_enum(AccountStatus, "account_status"),
        nullable=False,
        server_default=AccountStatus.active.value,
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

    role: Mapped["Role"] = relationship()  # noqa: F821
    modules: Mapped[list["UserModule"]] = relationship(  # noqa: F821
        back_populates="user", cascade="all, delete-orphan"
    )
