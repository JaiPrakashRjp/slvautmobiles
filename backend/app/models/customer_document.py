"""Customer KYC document — stored as binary (BYTEA), like vehicle documents."""
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    ForeignKey,
    Identity,
    LargeBinary,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.enums import KycDocType, pg_enum


class CustomerDocument(Base):
    __tablename__ = "customer_documents"
    __table_args__ = (
        UniqueConstraint("customer_id", "doc_type", name="customer_documents_unique"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    customer_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("customers.id", ondelete="CASCADE"), nullable=False
    )
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )
    doc_type: Mapped[KycDocType] = mapped_column(
        pg_enum(KycDocType, "kyc_doc_type"), nullable=False
    )
    file_name: Mapped[str] = mapped_column(Text, nullable=False)
    mime_type: Mapped[str] = mapped_column(Text, nullable=False)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    content: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)  # BYTEA
    uploaded_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    customer: Mapped["Customer"] = relationship(back_populates="documents")  # noqa: F821
