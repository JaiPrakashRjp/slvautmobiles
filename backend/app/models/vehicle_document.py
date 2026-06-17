"""Vehicle document — every file for a vehicle, stored as binary (BYTEA)."""
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
from app.models.enums import VehicleDocType, pg_enum


class VehicleDocument(Base):
    __tablename__ = "vehicle_documents"
    __table_args__ = (
        UniqueConstraint("vehicle_id", "doc_type", name="vehicle_documents_unique"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    vehicle_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False
    )
    module_id: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("modules.id"), nullable=False
    )
    doc_type: Mapped[VehicleDocType] = mapped_column(
        pg_enum(VehicleDocType, "vehicle_doc_type"), nullable=False
    )
    file_name: Mapped[str] = mapped_column(Text, nullable=False)
    mime_type: Mapped[str] = mapped_column(Text, nullable=False)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    content: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)  # BYTEA
    uploaded_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)

    vehicle: Mapped["Vehicle"] = relationship(back_populates="documents")  # noqa: F821
