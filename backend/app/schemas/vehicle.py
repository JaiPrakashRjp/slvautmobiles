"""Pydantic request/response schemas for the vehicles module."""
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.models.enums import (
    Branch,
    EntityStatus,
    FuelType,
    InventoryStatus,
    SaleStatus,
    Showroom,
    VehicleDocType,
    VehicleHand,
)


class VehicleBase(BaseModel):
    # protected_namespaces=() so the `model` field doesn't clash with pydantic
    model_config = ConfigDict(protected_namespaces=())

    branch: Branch
    owned_hand: VehicleHand
    chassis_no: str
    model: str
    fuel_type: FuelType | None = None
    purchase_date: date | None = None
    buying_expenses: Decimal | None = None
    # first-hand
    showroom: Showroom | None = None
    # RC / Permit / Insurance — independent flags (both hand types)
    rc: bool = False
    permit: bool = False
    insurance: bool = False
    # second-hand
    reg_no: str | None = None
    insurance_date: date | None = None
    fc_date: date | None = None
    permit_date: date | None = None
    prev_owner_name: str | None = None
    prev_owner_mobile: str | None = None
    prev_owner_address: str | None = None
    remarks: str | None = None
    financer_id: int | None = None


class VehicleCreate(VehicleBase):
    module_code: str = "auto_sale"
    status: EntityStatus | None = None  # optional override; else derived from role


class VehicleUpdate(BaseModel):
    """All fields optional — only provided keys are changed (PATCH)."""
    model_config = ConfigDict(protected_namespaces=())

    branch: Branch | None = None
    owned_hand: VehicleHand | None = None
    chassis_no: str | None = None
    model: str | None = None
    fuel_type: FuelType | None = None
    purchase_date: date | None = None
    buying_expenses: Decimal | None = None
    showroom: Showroom | None = None
    rc: bool | None = None
    permit: bool | None = None
    insurance: bool | None = None
    reg_no: str | None = None
    insurance_date: date | None = None
    fc_date: date | None = None
    permit_date: date | None = None
    prev_owner_name: str | None = None
    prev_owner_mobile: str | None = None
    prev_owner_address: str | None = None
    sale_status: SaleStatus | None = None
    status: EntityStatus | None = None
    remarks: str | None = None
    financer_id: int | None = None


class DocumentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    doc_type: VehicleDocType
    file_name: str
    mime_type: str
    size_bytes: int | None = None
    uploaded_at: datetime


class VehicleOut(VehicleBase):
    model_config = ConfigDict(from_attributes=True, protected_namespaces=())

    id: int
    module_id: int
    inventory_status: InventoryStatus
    sale_status: SaleStatus
    is_seized: bool = False
    next_service_due_date: date | None = None
    assigned_to_customer_id: int | None = None
    status: EntityStatus
    created_by: int
    created_at: datetime
    confirmed_by: int | None = None
    confirmed_at: datetime | None = None
    rejection_reason: str | None = None
    documents: list[DocumentOut] = []
