"""Daily reminder job — WhatsApp customers + notify staff for installments due.

Run by cron at 8 AM IST (= 02:30 UTC on the server):

    30 2 * * * cd /opt/slv-dev/backend && /opt/slv-dev/venv/bin/python -m app.jobs.run_reminders >> /var/log/slv-reminders.log 2>&1

Idempotent — safe to run more than once a day (a customer is reminded only once
per installment due date).
"""
from datetime import datetime, timezone

from app.db import SessionLocal
from app.services.reminder_service import ReminderService


def main() -> None:
    db = SessionLocal()
    try:
        created = ReminderService.run(db)
        stamp = datetime.now(timezone.utc).isoformat()
        print(f"[{stamp}] reminders: {len(created)} WhatsApp reminder(s) dispatched.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
