"""Loan EMI reminder engine.

For every unpaid EMI of an active loan, `run()` reminds the customer on THREE
days around the due date — the day before, the due date, and the day after —
by WhatsApp, and on the day AFTER it also raises an in-app + push notification
to staff so they follow up. Each day's reminder is logged once (idempotent per
calendar day). Meant to run daily at 8 AM (see app/jobs/run_reminders.py).
"""
from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy.orm import Session

from app.config import settings
from app.dao.loan_dao import LoanDAO
from app.models.customer import Customer
from app.models.enums import (
    InstallmentStatus,
    ReminderChannel,
    ReminderRecipient,
    ReminderStatus,
)
from app.models.reminder_log import ReminderLog
from app.services.notification_service import NotificationService
from app.services.whatsapp_service import WhatsAppService


def _amount(value) -> str:
    return f"{float(value):,.0f}"


class LoanReminderService:
    # Reminder window relative to the due date: day before (+1), on (0), after (-1).
    WINDOW = (1, 0, -1)

    @staticmethod
    def run(db: Session, now: datetime | None = None) -> list[ReminderLog]:
        now = now or datetime.now(timezone.utc)
        today = now.date()
        created: list[ReminderLog] = []

        for loan in LoanDAO.active_loans_with_unpaid(db):
            customer = db.get(Customer, loan.customer_id)
            cust_name = customer.first_name if customer else "Customer"
            cust_phone = customer.phone if customer else ""

            for emi in loan.emis:
                if emi.status == InstallmentStatus.paid:
                    continue
                days = (emi.due_date - today).days
                if days not in LoanReminderService.WINDOW:
                    continue

                due_amount = (
                    Decimal(emi.amount) + Decimal(emi.penalty) - Decimal(emi.amount_paid)
                )
                if due_amount <= 0:
                    continue

                # 1) WhatsApp the customer — once per calendar day per EMI.
                already = cust_phone and LoanDAO.find_reminder_on_date(
                    db, emi_id=emi.id, recipient_phone=cust_phone, on_date=today
                )
                if cust_phone and already is None:
                    ok, msg_id, err = WhatsAppService.send_template(
                        cust_phone,
                        settings.WHATSAPP_LOAN_REMINDER_TEMPLATE,
                        lang=settings.WHATSAPP_LOAN_REMINDER_LANG,
                        components=[
                            {
                                "type": "body",
                                "parameters": [
                                    {"type": "text", "text": cust_name},
                                    {"type": "text", "text": _amount(due_amount)},
                                    {
                                        "type": "text",
                                        "text": emi.due_date.strftime("%d %b %Y"),
                                    },
                                ],
                            }
                        ],
                    )
                    log = ReminderLog(
                        loan_id=loan.id,
                        emi_id=emi.id,
                        recipient_type=ReminderRecipient.customer,
                        recipient_phone=cust_phone,
                        channel=ReminderChannel.whatsapp,
                        message=(
                            f"EMI {emi.sequence_number} of ₹{_amount(due_amount)} "
                            f"due {emi.due_date.isoformat()}"
                        ),
                        due_date=emi.due_date,
                        sent_at=now if ok else None,
                        status=ReminderStatus.sent if ok else ReminderStatus.failed,
                        provider_message_id=msg_id,
                        error=err,
                    )
                    LoanDAO.add_reminder(db, log)
                    created.append(log)

                # 2) On the day AFTER the due date, notify staff in-app + push.
                if days == -1:
                    NotificationService.create_loan_reminder(
                        db,
                        loan_id=loan.id,
                        emi_id=emi.id,
                        title="Loan EMI overdue — call the customer",
                        message=(
                            f"{cust_name}: EMI {emi.sequence_number} of "
                            f"₹{_amount(due_amount)} was due "
                            f"{emi.due_date.strftime('%d %b %Y')}."
                        ),
                    )

        db.commit()
        return created
