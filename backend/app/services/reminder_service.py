"""Reminder engine.

`run()` scans active sales' unpaid installments and, on an installment's due date
(or the first run after it, if a day was missed), it:
  1. sends the customer a WhatsApp reminder using the approved template, and
  2. notifies all staff (admins + super admins) via in-app + FCM push so they can
     call the customer and record the payment.

Every WhatsApp attempt (sent or failed) is logged to reminder_logs, idempotently
(keyed on installment + recipient + due_date + phone), so a customer is reminded
only once per due date. Meant to be run daily at 3 PM (see app/jobs/run_reminders.py).
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from sqlalchemy.orm import Session

from app.config import settings
from app.dao.sale_dao import SaleDAO
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


class ReminderService:
    @staticmethod
    def run(db: Session, now: datetime | None = None) -> list[ReminderLog]:
        now = now or datetime.now(timezone.utc)
        today = now.date()
        created: list[ReminderLog] = []

        for sale in SaleDAO.active_sales_with_unpaid(db):
            customer = db.get(Customer, sale.customer_id)
            cust_name = customer.first_name if customer else "Customer"
            cust_phone = sale.customer_whatsapp or (customer.phone if customer else "")

            for inst in sale.installments:
                if inst.status == InstallmentStatus.paid:
                    continue
                # Only on/after the due date (fires on due-day 8 AM; catches up if
                # the job missed a day). Future installments are skipped.
                if (inst.due_date - today).days > 0:
                    continue
                # Idempotent: one reminder per installment + due date + customer.
                if cust_phone and SaleDAO.find_reminder(
                    db,
                    installment_id=inst.id,
                    recipient_type=ReminderRecipient.customer,
                    due_date=inst.due_date,
                    recipient_phone=cust_phone,
                ) is not None:
                    continue

                # 1) WhatsApp the customer via the approved template.
                if cust_phone:
                    ok, msg_id, err = WhatsAppService.send_template(
                        cust_phone,
                        settings.WHATSAPP_REMINDER_TEMPLATE,
                        lang=settings.WHATSAPP_REMINDER_LANG,
                        components=[
                            {
                                "type": "body",
                                "parameters": [
                                    {"type": "text", "text": cust_name},
                                    {"type": "text", "text": _amount(inst.amount)},
                                    {"type": "text", "text": inst.due_date.strftime("%d %b %Y")},
                                ],
                            }
                        ],
                    )
                    # Log every attempt (sent + failed) — auditable in reminder_logs.
                    log = ReminderLog(
                        sale_id=sale.id,
                        installment_id=inst.id,
                        recipient_type=ReminderRecipient.customer,
                        recipient_phone=cust_phone,
                        channel=ReminderChannel.whatsapp,
                        message=(
                            f"Installment month {inst.month_number} of "
                            f"₹{_amount(inst.amount)} due {inst.due_date.isoformat()}"
                        ),
                        due_date=inst.due_date,
                        sent_at=now if ok else None,
                        status=ReminderStatus.sent if ok else ReminderStatus.failed,
                        provider_message_id=msg_id,
                        error=err,
                    )
                    SaleDAO.add_reminder(db, log)
                    created.append(log)

                # 2) Notify all staff (in-app + FCM) to take the call.
                NotificationService.create_reminder(
                    db,
                    sale_id=sale.id,
                    installment_id=inst.id,
                    title="Installment due — call the customer",
                    message=(
                        f"{cust_name}: month {inst.month_number} of "
                        f"₹{_amount(inst.amount)} due {inst.due_date.strftime('%d %b %Y')}."
                    ),
                )

        db.commit()
        return created
