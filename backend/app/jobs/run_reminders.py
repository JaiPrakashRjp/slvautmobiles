"""Daily reminder job — WhatsApp customers + notify staff for installments due.

Run by cron at 8:00 AM IST (= 02:30 UTC on the server):

    30 2 * * * cd /opt/slv-dev/backend && /opt/slv-dev/venv/bin/python -m app.jobs.run_reminders >> /var/log/slv-reminders.log 2>&1

Idempotent — safe to run more than once a day (a customer is reminded only once
per installment due date).
"""
from datetime import datetime, timezone

from app.db import SessionLocal
from app.services.doc_expiry_service import DocExpiryService
from app.services.reminder_service import ReminderService


def main() -> None:
    db = SessionLocal()
    try:
        created = ReminderService.run(db)
        # Loan + personal-loan EMI reminders run separately at 9 AM IST
        # (run_loan_reminders). Rental rent reminders run at 5 PM IST.
        expiries = DocExpiryService.run(db)
        stamp = datetime.now(timezone.utc).isoformat()
        print(
            f"[{stamp}] reminders: {len(created)} sale WhatsApp reminder(s) "
            f"dispatched; {expiries} document-expiry alert(s)."
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()
