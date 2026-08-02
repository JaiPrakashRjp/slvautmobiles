"""Rental rent-collection reminder job — runs at 7 AM IST.

Separate from the 8 AM sale reminders (rent reads very differently and nudges
daily). Cron on the server:

    30 1 * * * cd /opt/slv-dev/backend && /opt/slv-dev/venv/bin/python -m app.jobs.run_rental_reminders >> /var/log/slv-rental-reminders.log 2>&1

(30 1 UTC = 07:00 IST.) Reminds renters with an unpaid rent period every day
until they pay; every WhatsApp attempt (sent + failed) is logged to reminder_logs.
Idempotent per day — safe to run more than once.
"""
from datetime import datetime, timezone

from app.db import SessionLocal
from app.services.rental_reminder_service import RentalReminderService


def main() -> None:
    db = SessionLocal()
    try:
        created = RentalReminderService.run(db)
        stamp = datetime.now(timezone.utc).isoformat()
        print(
            f"[{stamp}] rental reminders: {len(created)} WhatsApp reminder(s) dispatched."
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()
