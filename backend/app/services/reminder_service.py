"""Reminder engine.

`run()` scans active sales' unpaid installments and, at T-3 / due-day / overdue,
records one reminder_log per recipient (the customer + every super admin),
idempotently (keyed on installment + recipient + due_date + phone). Each new row
is marked sent with a sent_at timestamp.

NOTE: actual WhatsApp delivery is deferred (needs a provider). The frontend opens
wa.me deep links from these rows; the row's sent_at is the dispatch time.
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from sqlalchemy.orm import Session

from app.dao.sale_dao import SaleDAO
from app.dao.user_dao import UserDAO
from app.models.customer import Customer
from app.models.enums import (
    InstallmentStatus,
    ReminderChannel,
    ReminderRecipient,
    ReminderStatus,
)
from app.models.reminder_log import ReminderLog

# Days-before-due (and overdue) on which a reminder fires.
FIRE_OFFSETS = (3, 0)


def _money(value) -> str:
    return f"₹{float(value):,.0f}"


def _message(name: str, month: int, amount, due: date, days: int) -> str:
    if days < 0:
        return (
            f"Reminder: installment month {month} of {_money(amount)} was due on "
            f"{due.isoformat()} ({-days} day(s) overdue). — SLV Auto Consultant"
        )
    when = "today" if days == 0 else f"in {days} day(s)"
    return (
        f"Namaste {name}, installment month {month} of {_money(amount)} is due "
        f"{when} ({due.isoformat()}). — SLV Auto Consultant"
    )


class ReminderService:
    @staticmethod
    def run(db: Session, now: datetime | None = None) -> list[ReminderLog]:
        now = now or datetime.now(timezone.utc)
        today = now.date()
        super_admins = UserDAO.super_admins(db)
        created: list[ReminderLog] = []

        for sale in SaleDAO.active_sales_with_unpaid(db):
            customer = db.get(Customer, sale.customer_id)
            cust_name = customer.first_name if customer else "Customer"
            cust_phone = sale.customer_whatsapp or (customer.phone if customer else "")

            for inst in sale.installments:
                if inst.status == InstallmentStatus.paid:
                    continue
                days = (inst.due_date - today).days
                if not (days in FIRE_OFFSETS or days < 0):
                    continue

                msg = _message(cust_name, inst.month_number, inst.amount, inst.due_date, days)
                # recipients: customer + each super admin
                targets = [(ReminderRecipient.customer, cust_phone)]
                targets += [(ReminderRecipient.super_admin, sa.phone) for sa in super_admins]

                for recipient_type, phone in targets:
                    if not phone:
                        continue
                    existing = SaleDAO.find_reminder(
                        db,
                        installment_id=inst.id,
                        recipient_type=recipient_type,
                        due_date=inst.due_date,
                        recipient_phone=phone,
                    )
                    if existing is not None:
                        continue
                    log = ReminderLog(
                        sale_id=sale.id,
                        installment_id=inst.id,
                        recipient_type=recipient_type,
                        recipient_phone=phone,
                        channel=ReminderChannel.whatsapp,
                        message=msg,
                        due_date=inst.due_date,
                        sent_at=now,
                        status=ReminderStatus.sent,
                    )
                    SaleDAO.add_reminder(db, log)
                    created.append(log)

        db.commit()
        return created
