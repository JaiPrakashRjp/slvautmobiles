"""Link table — the financer assigned to a sale.

One financer per sale (UNIQUE on sale_id); the same financer may be linked to
many different sales (it lives in the shared `financers` master list).
"""
from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Identity, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class SaleFinancer(Base):
    __tablename__ = "sale_financers"
    __table_args__ = (
        UniqueConstraint("sale_id", name="sale_financers_sale_unique"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    sale_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("sales.id", ondelete="CASCADE"), nullable=False
    )
    financer_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("financers.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    sale: Mapped["Sale"] = relationship(back_populates="financer_link")  # noqa: F821
    financer: Mapped["Financer"] = relationship()  # noqa: F821
