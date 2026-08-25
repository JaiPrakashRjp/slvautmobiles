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
run at 8 PM IST (see app/jobs/run_rental_reminders.py) — separate from the 8 AM
sale reminders.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.config import settings
from app.dao.rental_dao import RentalDAO
from app.models.customer import Customer
from app.models.enums import (
    InstallmentStatus,
    ReminderChannel,
    ReminderRecipient,
    ReminderStatus,
    RentalType,
)
from app.models.reminder_log import ReminderLog
from app.services.notification_service import NotificationService
from app.services.rental_service import RentalService
from app.services.whatsapp_service import WhatsAppService


def _amount(value) -> str:
    return f"{float(value):,.0f}"


class RentalReminderService:
    @staticmethod
    def run(db: Session, now: datetime | None = None) -> list[ReminderLog]:
        now = now or datetime.now(timezone.utc)
        today = now.date()
        created: list[ReminderLog] = []

        # Weekly rentals materialize their newly-due weeks first — even ones whose
        # every existing week is paid (a fresh week may now be due), which the
        # unpaid-only query below would otherwise skip.
        for rental in RentalDAO.active_weekly_rentals(db):
            RentalService._ensure_weekly_installments(db, rental, today)
        db.flush()

        for rental in RentalDAO.active_rentals_with_unpaid(db):
            customer = db.get(Customer, rental.customer_id)
            cust_name = customer.first_name if customer else "Customer"
            cust_phone = customer.phone if customer else ""

            if rental.rental_type == RentalType.weekly:
                RentalReminderService._remind_weekly(
                    db, rental, cust_name, cust_phone, today, now, created
                )
            else:
                RentalReminderService._remind_daily(
                    db, rental, cust_name, cust_phone, today, now, created
                )

        db.commit()
        return created

    @staticmethod
    def _remind_daily(db, rental, cust_name, cust_phone, today, now, created) -> None:
        """Daily & legacy recurring rent: nudge EVERY DAY until paid, once per day
        per rent period. Unchanged behaviour."""
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

    @staticmethod
    def _remind_weekly(db, rental, cust_name, cust_phone, today, now, created) -> None:
        """Weekly rent: ONE reminder every ~7 days that LISTS all unpaid weeks
        (oldest first) in a single template. WhatsApp forbids line breaks in a
        variable, so the weeks are joined with "; " into one variable. Capped at
        MAX_ROWS (10) itemised weeks. Paid weeks drop out of the list; when nothing
        is owed, nothing sends."""
        unpaid = sorted(
            (
                i
                for i in rental.installments
                if i.status != InstallmentStatus.paid and (i.due_date - today).days <= 0
            ),
            key=lambda i: i.due_date,
        )
        if not unpaid:
            return
        # Weekly cadence: at most one customer reminder per rental per 7 days.
        if cust_phone and RentalDAO.recent_rental_customer_reminder(
            db,
            rental_id=rental.id,
            recipient_phone=cust_phone,
            since=today - timedelta(days=6),
        ):
            return

        rows = unpaid[: settings.WHATSAPP_RENTAL_WEEKLY_MAX_ROWS]
        oldest = rows[0]
        total = sum(float(i.amount) for i in rows)

        # 1) WhatsApp the renter — pick the template matching the unpaid-week count
        #    (rent_overdue_3 for 3 weeks) so each week shows on its own line.
        #    Params: name, then amount+date per week (oldest first).
        if cust_phone:
            params = [{"type": "text", "text": cust_name}]
            for i in rows:
                params.append({"type": "text", "text": _amount(i.amount)})
                params.append({"type": "text", "text": i.due_date.strftime("%d %b %Y")})
            template = (
                f"{settings.WHATSAPP_RENTAL_WEEKLY_REMINDER_TEMPLATE_PREFIX}{len(rows)}"
            )
            ok, msg_id, err = WhatsAppService.send_template(
                cust_phone,
                template,
                lang=settings.WHATSAPP_RENTAL_WEEKLY_REMINDER_LANG,
                components=[{"type": "body", "parameters": params}],
            )
            log = ReminderLog(
                rental_id=rental.id,
                rental_installment_id=oldest.id,
                recipient_type=ReminderRecipient.customer,
                recipient_phone=cust_phone,
                channel=ReminderChannel.whatsapp,
                message=(
                    f"Weekly rent overdue: {len(rows)} week(s), "
                    f"₹{_amount(total)} pending (oldest {oldest.due_date.isoformat()})"
                ),
                due_date=oldest.due_date,
                sent_at=now if ok else None,
                status=ReminderStatus.sent if ok else ReminderStatus.failed,
                provider_message_id=msg_id,
                error=err,
            )
            RentalDAO.add_reminder(db, log)
            created.append(log)

        # 2) Notify all staff once (in-app + FCM) to collect the arrears.
        NotificationService.create_rental_reminder(
            db,
            rental_id=rental.id,
            installment_id=oldest.id,
            title="Weekly rent overdue — call the renter",
            message=(
                f"{cust_name}: {len(rows)} week(s) overdue, ₹{_amount(total)} pending "
                f"(oldest {oldest.due_date.strftime('%d %b %Y')})."
            ),
        )
