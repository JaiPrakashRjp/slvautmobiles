"""Sale financer master — finance companies used for SALE finance.

Completely separate from vehicle financers (app.models.financer.Financer): a
financer added for a sale never appears in the vehicle list and vice-versa. The
same sale financer can be reused across many sales (Sale.financer_id).
"""
from datetime import datetime

from sqlalchemy import BigInteger, Identity, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class SaleFinancer(Base):
    __tablename__ = "sale_financers"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
