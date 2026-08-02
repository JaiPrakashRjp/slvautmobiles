"""Rental rent-collection reminder engine (recurring rent).

`run()` scans approved, active rentals' unpaid rent periods and, on/after a
period's due date, it:
  1. sends the renter a WhatsApp reminder using the RENTAL template (distinct
     from the sale/installment template — rent reads very differently), and
  2. notifies all staff (admins + super admins) via in-app + FCM so they can
     call the renter and collect the rent.

Recurring rent reminds the renter EVERY DAY until they pay (the period rolls
forward from each payment). Every WhatsApp attempt (sent or failed) is logged to
reminder_logs, idempotently PER DAY (keyed on rent installment + phone + today),
so the job is safe to run more than once a day but still nudges daily. Meant to
run at 7 AM IST (see app/jobs/run_rental_reminders.py) — separate from the 8 AM
sale reminders.
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from sqlalchemy.orm import Session

from app.config import settings
from app.dao.rental_dao import RentalDAO
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


class RentalReminderService:
    @staticmethod
    def run(db: Session, now: datetime | None = None) -> list[ReminderLog]:
        now = now or datetime.now(timezone.utc)
        today = now.date()
        created: list[ReminderLog] = []

        for rental in RentalDAO.active_rentals_with_unpaid(db):
            customer = db.get(Customer, rental.customer_id)
            cust_name = customer.first_name if customer else "Customer"
            cust_phone = customer.phone if customer else ""

            for inst in rental.installments:
                if inst.status == InstallmentStatus.paid:
                    continue
                # Only on/after the due date. Future periods are skipped.
                if (inst.due_date - today).days > 0:
                    continue
                # Fire EVERY DAY until paid, but only once per day (safe to run the
                # job more than once). Idempotent per rent installment + renter + today.
                if cust_phone and RentalDAO.find_reminder_on_date(
                    db,
                    rental_installment_id=inst.id,
                    recipient_phone=cust_phone,
                    on_date=today,
                ) is not None:
                    continue

                # 1) WhatsApp the renter via the rental-specific template.
                if cust_phone:
                    ok, msg_id, err = WhatsAppService.send_template(
                        cust_phone,
                        settings.WHATSAPP_RENTAL_REMINDER_TEMPLATE,
                        lang=settings.WHATSAPP_RENTAL_REMINDER_LANG,
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
                        rental_id=rental.id,
                        rental_installment_id=inst.id,
                        recipient_type=ReminderRecipient.customer,
                        recipient_phone=cust_phone,
                        channel=ReminderChannel.whatsapp,
                        message=(
                            f"Rent reminder #{inst.number} of "
                            f"₹{_amount(inst.amount)} due {inst.due_date.isoformat()}"
                        ),
                        due_date=inst.due_date,
                        sent_at=now if ok else None,
                        status=ReminderStatus.sent if ok else ReminderStatus.failed,
                        provider_message_id=msg_id,
                        error=err,
                    )
                    RentalDAO.add_reminder(db, log)
                    created.append(log)

                # 2) Notify all staff (in-app + FCM) to collect the rent.
                NotificationService.create_rental_reminder(
                    db,
                    rental_id=rental.id,
                    installment_id=inst.id,
                    title="Rent due — call the renter",
                    message=(
                        f"{cust_name}: rent #{inst.number} of "
                        f"₹{_amount(inst.amount)} due {inst.due_date.strftime('%d %b %Y')}."
                    ),
                )

        db.commit()
        return created
