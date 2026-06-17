"""Module lookup — the three business modules (Auto Sale / Rental / Loan)."""
from datetime import datetime

from sqlalchemy import Identity, SmallInteger, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Module(Base):
    __tablename__ = "modules"

    id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    code: Mapped[str] = mapped_column(Text, unique=True, nullable=False)  # auto_sale | rental | loan
    name: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
