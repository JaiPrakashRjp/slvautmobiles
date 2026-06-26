"""Pydantic request/response schemas for the customers module."""
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.models.enums import Branch, EntityStatus, KycDocType


class CustomerBase(BaseModel):
    first_name: str
    last_name: str = ""
    phone: str
    address: str = ""
    branch: Branch | None = None
    age: int | None = None
    dob: date | None = None
    assurity_name: str | None = None
    assurity_mobile: str | None = None
    remarks: str | None = None


class CustomerCreate(CustomerBase):
    module_code: str = "auto_sale"
    status: EntityStatus | None = None  # optional override; else derived from role


class CustomerUpdate(BaseModel):
    """All fields optional — only provided keys are changed (PATCH)."""
    first_name: str | None = None
    last_name: str | None = None
    phone: str | None = None
    address: str | None = None
    branch: Branch | None = None
    age: int | None = None
    dob: date | None = None
    assurity_name: str | None = None
    assurity_mobile: str | None = None
    status: EntityStatus | None = None
    remarks: str | None = None


class DocumentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    doc_type: KycDocType
    file_name: str
    mime_type: str
    size_bytes: int | None = None
    uploaded_at: datetime


class CustomerOut(CustomerBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    module_id: int
    status: EntityStatus
    created_by: int
    created_at: datetime
    confirmed_by: int | None = None
    confirmed_at: datetime | None = None
    rejection_reason: str | None = None
    documents: list[DocumentOut] = []
