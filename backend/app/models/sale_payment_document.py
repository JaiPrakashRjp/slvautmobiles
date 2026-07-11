"""Sale payment proof — the screenshot attached when an installment is paid.

Stored as binary (BYTEA), mirroring VehicleDocument.
"""
from datetime import datetime

from sqlalchemy import BigInteger, ForeignKey, Identity, LargeBinary, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class SalePaymentDocument(Base):
    __tablename__ = "sale_payment_documents"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    payment_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("sale_payments.id", ondelete="CASCADE"), nullable=False
    )
    file_name: Mapped[str] = mapped_column(Text, nullable=False)
    mime_type: Mapped[str] = mapped_column(Text, nullable=False)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    # deferred: skip the blob on list/detail queries (metadata only); load it
    # lazily only when the document is downloaded. Keeps responses fast.
    content: Mapped[bytes] = mapped_column(
        LargeBinary, nullable=False, deferred=True
    )  # BYTEA
    uploaded_by: Mapped[int | None] = mapped_column(BigInteger)
    uploaded_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    payment: Mapped["SalePayment"] = relationship(  # noqa: F821
        back_populates="documents"
    )
