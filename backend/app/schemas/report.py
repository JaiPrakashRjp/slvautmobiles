"""Schemas for reports (daily reminder / collection report)."""
from __future__ import annotations

from datetime import date

from pydantic import BaseModel

from app.models.enums import InstallmentStatus


class DailyReminderRow(BaseModel):
    installment_id: int
    sale_id: int
    customer_name: str
    customer_phone: str
    vehicle_reg: str | None = None
    amount: float
    due_date: date
    status: InstallmentStatus
    taken_by_name: str | None = None
    paid_date: date | None = None
