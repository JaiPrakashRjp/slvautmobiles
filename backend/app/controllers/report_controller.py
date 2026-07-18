"""Reports — the daily reminder / collection list for a chosen date.

Visible to any signed-in staff (admin + super admin).
"""
from datetime import date as date_type

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.customer import Customer
from app.models.enums import EntityStatus, SaleLifecycle
from app.models.sale import Sale
from app.models.sale_installment import SaleInstallment
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas.report import DailyReminderRow
from app.security import get_current_user

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/daily-reminders", response_model=list[DailyReminderRow])
def daily_reminders(
    on: date_type = Query(..., description="Report date (installments due this day)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """All installments due on `on`, across every approved (non-cancelled,
    non-seized) sale, with the customer, vehicle and current status."""
    stmt = (
        select(SaleInstallment, Sale, Customer, Vehicle)
        .join(Sale, SaleInstallment.sale_id == Sale.id)
        .join(Customer, Sale.customer_id == Customer.id)
        .join(Vehicle, Sale.vehicle_id == Vehicle.id)
        .where(SaleInstallment.due_date == on)
        .where(Sale.status == EntityStatus.active)
        .where(
            Sale.sale_status.notin_(
                [SaleLifecycle.cancelled, SaleLifecycle.seized]
            )
        )
        .order_by(SaleInstallment.status, Customer.first_name)
    )
    rows = db.execute(stmt).all()

    # Resolve taker names in one query.
    taker_ids = {inst.taken_by for inst, *_ in rows if inst.taken_by}
    names: dict[int, str] = {}
    if taker_ids:
        for u in db.execute(select(User).where(User.id.in_(taker_ids))).scalars():
            names[u.id] = f"{u.first_name} {u.last_name}".strip()

    return [
        DailyReminderRow(
            installment_id=inst.id,
            sale_id=sale.id,
            customer_name=f"{cust.first_name} {cust.last_name}".strip(),
            customer_phone=cust.phone,
            vehicle_reg=veh.reg_no,
            amount=float(inst.amount),
            due_date=inst.due_date,
            status=inst.status,
            taken_by_name=names.get(inst.taken_by),
            paid_date=inst.paid_date,
        )
        for inst, sale, cust, veh in rows
    ]
