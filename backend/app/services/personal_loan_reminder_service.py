"""Personal-loan EMI reminder engine.

For each unpaid EMI of an active personal loan, on/after its monthly due date it
sends a WhatsApp reminder to the loan's phone with the vehicle number and the EMI
amount. Logged once per calendar day per EMI (idempotent). Runs daily at 8 AM
(see app/jobs/run_reminders.py).
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.config import settings
from app.dao.personal_loan_dao import PersonalLoanDAO
from app.models.enums import (
    InstallmentStatus,
    ReminderChannel,
    ReminderRecipient,
    ReminderStatus,
)
from app.models.reminder_log import ReminderLog
from app.services.whatsapp_service import WhatsAppService


def _amount(value) -> str:
    return f"{float(value):,.0f}"


class PersonalLoanReminderService:
    @staticmethod
    def run(db: Session, now: datetime | None = None) -> list[ReminderLog]:
        now = now or datetime.now(timezone.utc)
        today = now.date()
        created: list[ReminderLog] = []

        # All personal-loan reminders go to one fixed number (the office/owner).
        phone = (settings.PERSONAL_LOAN_REMINDER_PHONE or "").strip()
        if not phone:
            return created

        for loan in PersonalLoanDAO.active_loans_with_unpaid(db):
            for emi in loan.emis:
                if emi.status == InstallmentStatus.paid:
                    continue
                # On or after the monthly due date (catches up if a day missed).
                if (emi.due_date - today).days > 0:
                    continue
                # Idempotent — one reminder per EMI per calendar day.
                if PersonalLoanDAO.find_reminder_on_date(
                    db, personal_loan_emi_id=emi.id, recipient_phone=phone,
                    on_date=today,
                ) is not None:
                    continue

                ok, msg_id, err = WhatsAppService.send_template(
                    phone,
                    settings.WHATSAPP_PERSONAL_LOAN_REMINDER_TEMPLATE,
                    lang=settings.WHATSAPP_PERSONAL_LOAN_REMINDER_LANG,
                    components=[
                        {
                            "type": "body",
                            "parameters": [
                                {"type": "text", "text": loan.vehicle_number},
                                {"type": "text", "text": _amount(emi.amount)},
                                {
                                    "type": "text",
                                    "text": emi.due_date.strftime("%d %b %Y"),
                                },
                            ],
                        }
                    ],
                )
                log = ReminderLog(
                    personal_loan_id=loan.id,
                    personal_loan_emi_id=emi.id,
                    recipient_type=ReminderRecipient.customer,
                    recipient_phone=phone,
                    channel=ReminderChannel.whatsapp,
                    message=(
                        f"Vehicle {loan.vehicle_number}: EMI {emi.sequence_number} "
                        f"of Rs.{_amount(emi.amount)} due {emi.due_date.isoformat()}"
                    ),
                    due_date=emi.due_date,
                    sent_at=now if ok else None,
                    status=ReminderStatus.sent if ok else ReminderStatus.failed,
                    provider_message_id=msg_id,
                    error=err,
                )
                PersonalLoanDAO.add_reminder(db, log)
                created.append(log)

        db.commit()
        return created
