"""Pydantic request/response schemas for the loans module."""
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.models.enums import EntityStatus, InstallmentStatus


class LoanBase(BaseModel):
    customer_id: int
    vehicle_id: int | None = None
    principal: Decimal
    emi_amount: Decimal
    tenure_months: int
    loan_date: date
    remarks: str | None = None


class LoanCreate(LoanBase):
    module_code: str = "loan"
    status: EntityStatus | None = None  # optional override; else derived from role


class LoanEmiOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sequence_number: int
    due_date: date
    amount: Decimal
    penalty: Decimal
    amount_paid: Decimal
    received_date: date | None = None
    paid_date: date | None = None
    remarks: str | None = None
    status: InstallmentStatus


class LoanPaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    emi_id: int | None = None
    amount: Decimal
    penalty: Decimal
    received_date: date | None = None
    remarks: str | None = None
    document_ids: list[int] = []
    created_at: datetime


class LoanOut(LoanBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    module_id: int
    first_due_date: date
    loan_status: str
    status: EntityStatus
    created_by: int
    created_at: datetime
    confirmed_by: int | None = None
    confirmed_at: datetime | None = None
    rejection_reason: str | None = None
    # seizure
    seize_stage: str | None = None
    seize_reason: str | None = None
    seized_at: datetime | None = None
    emis: list[LoanEmiOut] = []
    payments: list[LoanPaymentOut] = []
