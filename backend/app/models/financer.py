"""Vehicle financer master — finance companies used for VEHICLE finance.

Sales use their own separate master (see app.models.sale_financer.SaleFinancer).
"""
from datetime import datetime

from sqlalchemy import BigInteger, Identity, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Financer(Base):
    __tablename__ = "vehicle_financers"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
