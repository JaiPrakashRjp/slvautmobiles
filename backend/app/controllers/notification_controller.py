"""FastAPI router for in-app notifications + the manual reminder runner."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.notification import NotificationOut
from app.schemas.sale import ReminderLogOut
from app.services.notification_service import NotificationService
from app.services.reminder_service import ReminderService

router = APIRouter(tags=["notifications"])


@router.get("/notifications", response_model=list[NotificationOut])
def list_notifications(
    user_id: int = Query(...),
    unread_only: bool = False,
    db: Session = Depends(get_db),
):
    return NotificationService.list_for_user(db, user_id, unread_only=unread_only)


@router.post("/notifications/{notification_id}/read", response_model=NotificationOut)
def mark_read(notification_id: int, db: Session = Depends(get_db)):
    return NotificationService.mark_read(db, notification_id)


@router.post("/reminders/run", response_model=list[ReminderLogOut])
def run_reminders(db: Session = Depends(get_db)):
    """Compute + record due installment reminders (customer + super admins)."""
    return ReminderService.run(db)
