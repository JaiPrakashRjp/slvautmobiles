"""Loan + personal-loan EMI reminder job.

Run by cron at 9:00 AM IST (= 03:30 UTC on the server):

    30 3 * * * cd /opt/slv/backend && /opt/slv/venv/bin/python -m app.jobs.run_loan_reminders >> /var/log/slv-loan-reminders.log 2>&1

Sends:
  - Loan module EMI reminders (day-before / due-day / day-after window) by
    WhatsApp to each customer, plus a staff notification the day after.
  - Personal-loan EMI reminders (monthly, on the due date) by WhatsApp to the
    one fixed office number (PERSONAL_LOAN_REMINDER_PHONE).

Idempotent — safe to run more than once a day.
"""
from datetime import datetime, timezone

from app.db import SessionLocal
from app.services.loan_reminder_service import LoanReminderService
from app.services.personal_loan_reminder_service import PersonalLoanReminderService


def main() -> None:
    db = SessionLocal()
    try:
        loans = LoanReminderService.run(db)
        ploans = PersonalLoanReminderService.run(db)
        stamp = datetime.now(timezone.utc).isoformat()
        print(
            f"[{stamp}] loan reminders: {len(loans)} loan + {len(ploans)} "
            f"personal-loan WhatsApp reminder(s) dispatched."
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()
