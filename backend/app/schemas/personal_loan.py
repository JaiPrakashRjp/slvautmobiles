"""Pydantic schemas for the personal-loans module."""
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.models.enums import InstallmentStatus


class PersonalLoanFinancerCreate(BaseModel):
    name: str


class PersonalLoanFinancerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class PersonalLoanBase(BaseModel):
    vehicle_number: str
    financer_id: int | None = None
    loan_amount: Decimal
    emi_amount: Decimal
    tenure_months: int
    loan_date: date
    phone: str | None = None
    remarks: str | None = None


class PersonalLoanCreate(PersonalLoanBase):
    pass


class PersonalLoanEmiOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sequence_number: int
    due_date: date
    amount: Decimal
    status: InstallmentStatus
    paid_date: date | None = None


class PersonalLoanOut(PersonalLoanBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    first_due_date: date
    loan_status: str
    financer_name: str | None = None
    created_by: int
    created_at: datetime
    emis: list[PersonalLoanEmiOut] = []
