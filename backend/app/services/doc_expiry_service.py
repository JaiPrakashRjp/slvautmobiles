"""Vehicle document expiry alerts.

`run()` notifies staff about any vehicle whose Insurance / FC / Permit date is
TODAY. Meant to run once a day (alongside the reminder job) — so each document
fires exactly one alert on its expiry day. Renewing (editing the date) moves it
forward and the alert won't repeat.
"""
from __future__ import annotations

from datetime import date

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.vehicle import Vehicle
from app.services.notification_service import NotificationService


class DocExpiryService:
    @staticmethod
    def run(db: Session) -> int:
        """Fire a staff notification for every vehicle document expiring today.
        Returns the number of alerts created."""
        today = date.today()
        vehicles = db.scalars(
            select(Vehicle).where(
                or_(
                    Vehicle.insurance_date == today,
                    Vehicle.fc_date == today,
                    Vehicle.permit_date == today,
                )
            )
        ).all()

        count = 0
        for v in vehicles:
            ident = v.reg_no or v.chassis_no or f"Vehicle #{v.id}"
            for label, d in (
                ("Insurance", v.insurance_date),
                ("FC", v.fc_date),
                ("Permit", v.permit_date),
            ):
                if d == today:
                    NotificationService.create_doc_expiry(
                        db,
                        vehicle_id=v.id,
                        title=f"{label} expiring today",
                        message=(
                            f"{label} for {ident} expires today. "
                            f"Renew it and update the date."
                        ),
                    )
                    count += 1
        db.commit()
        return count
