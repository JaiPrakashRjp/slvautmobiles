"""Role lookup — super_admin / admin (and any custom roles)."""
from datetime import datetime

from sqlalchemy import Identity, SmallInteger, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    name: Mapped[str] = mapped_column(Text, unique=True, nullable=False)  # super_admin | admin
    label: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
