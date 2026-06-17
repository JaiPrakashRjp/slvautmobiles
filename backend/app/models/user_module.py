"""Per-user module assignment (references the existing modules table)."""
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    ForeignKey,
    Identity,
    SmallInteger,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class UserModule(Base):
    __tablename__ = "user_modules"
    __table_args__ = (
        UniqueConstraint("user_id", "module_id", name="user_modules_unique"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )
    assigned_by: Mapped[int | None] = mapped_column(BigInteger)
    assigned_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    user: Mapped["User"] = relationship(back_populates="modules")  # noqa: F821
    module: Mapped["Module"] = relationship()  # noqa: F821
