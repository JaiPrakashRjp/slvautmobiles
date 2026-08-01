"""Pydantic schemas for rentals, rent-collection installments, payments."""
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.models.enums import (
    EntityStatus,
    InstallmentStatus,
    PaymentKind,
    RentalLifecycle,
    RentalType,
)


class RentalCreate(BaseModel):
    module_code: str = "rental"
    vehicle_id: int
    customer_id: int
    # Recurring rent: type (weekly/daily) + per-period amount. total_amount is
    # legacy/optional (balance model only).
    rental_type: RentalType | None = None
    period_amount: float | None = None
    total_amount: float | None = None
    advance_amount: float = 0  # advance received now (recorded only)
    start_date: date | None = None
    remarks: str | None = None
    status: EntityStatus | None = None  # optional override; else from role


class RentalEdit(BaseModel):
    """Editable fields of a rental. Super admin applies at once; admin's is held
    pending until a super admin approves."""
    rental_type: RentalType | None = None
    period_amount: float | None = None
    total_amount: float | None = None
    advance_amount: float = 0
    start_date: date | None = None
    remarks: str | None = None


class ReminderCreate(BaseModel):
    """Schedule a rent-collection reminder (date + amount) on a rental."""
    due_date: date
    amount: float


class InstallmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    number: int
    due_date: date
    amount: float
    paid_date: date | None = None
    status: InstallmentStatus
    created_by: int | None = None
    taken_by: int | None = None
    cancel_reason: str | None = None


class PaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    installment_id: int | None = None
    amount: float
    paid_at: datetime
    kind: PaymentKind
    recorded_by: int
    status: EntityStatus
    confirmed_by: int | None = None
    rejection_reason: str | None = None
    document_ids: list[int] = []


class RentalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    module_id: int
    vehicle_id: int
    customer_id: int
    rental_type: RentalType | None = None
    period_amount: float | None = None
    total_amount: float | None = None
    advance_amount: float
    remaining_amount: float
    start_date: date | None = None
    invoice_no: str | None = None
    remarks: str | None = None
    rental_status: RentalLifecycle
    completed_at: datetime | None = None
    status: EntityStatus
    created_by: int
    created_at: datetime
    confirmed_by: int | None = None
    confirmed_at: datetime | None = None
    rejection_reason: str | None = None
    seized_at: datetime | None = None
    seized_by: int | None = None
    seize_reason: str | None = None
    seize_stage: str | None = None
    pending_edit: dict | None = None
    edit_stage: str | None = None
    edit_requested_by: int | None = None
    installments: list[InstallmentOut] = []
    payments: list[PaymentOut] = []
