"""Pydantic schemas for sales, installments, payments, reminders."""
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.models.enums import (
    DepositType,
    EntityStatus,
    InstallmentStatus,
    PaymentKind,
    ReminderChannel,
    ReminderRecipient,
    ReminderStatus,
    SaleLifecycle,
)


class SaleCreate(BaseModel):
    module_code: str = "auto_sale"
    vehicle_id: int
    customer_id: int
    sale_date: date | None = None
    # price breakdown — total (= sale_price) is computed from these five
    vehicle_amount: float = 0
    additional_fitting: float = 0
    dl_charges: float = 0
    document_charges: float = 0
    other_expenses: float = 0
    # payment: deposit_type (full cash / down payment) is DERIVED on the server
    amount_received: float = 0  # down payment paid now
    remaining_amount: float = 0  # typed by user in the loan case
    hp_amount: float | None = None  # loan amount — honoured only for super admin
    customer_whatsapp: str | None = None
    financer_id: int | None = None  # finance company for this sale (optional)
    status: EntityStatus | None = None  # optional override; else from role
    remarks: str | None = None


class ReminderCreate(BaseModel):
    """Admin schedules a collection reminder (date + amount) on a sale."""
    due_date: date
    amount: float


class InstallmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    month_number: int
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


class ReminderLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sale_id: int
    installment_id: int | None = None
    recipient_type: ReminderRecipient
    recipient_phone: str
    channel: ReminderChannel
    message: str
    due_date: date
    sent_at: datetime | None = None
    status: ReminderStatus


class SaleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    module_id: int
    vehicle_id: int
    customer_id: int
    deposit_type: DepositType
    sale_price: float
    sale_date: date | None = None
    amount_received: float
    remaining_amount: float
    vehicle_amount: float = 0
    additional_fitting: float = 0
    dl_charges: float = 0
    document_charges: float = 0
    other_expenses: float = 0
    hp_amount: float | None = None
    monthly_amount: float | None = None
    installment_count: int | None = None
    first_due_date: date | None = None
    customer_whatsapp: str | None = None
    financer_id: int | None = None
    financer_name: str | None = None
    invoice_no: str | None = None
    sale_status: SaleLifecycle
    closed_at: datetime | None = None
    status: EntityStatus
    created_by: int
    created_at: datetime
    confirmed_by: int | None = None
    confirmed_at: datetime | None = None
    rejection_reason: str | None = None
    unsell_reason: str | None = None
    seized_at: datetime | None = None
    seized_by: int | None = None
    seize_reason: str | None = None
    seize_stage: str | None = None
    seize_confirmed_at: datetime | None = None
    seize_confirmed_by: int | None = None
    seize_confirm_remarks: str | None = None
    seize_cancel_remarks: str | None = None
    sold: bool = False
    remarks: str | None = None
    installments: list[InstallmentOut] = []
    payments: list[PaymentOut] = []
