"""FastAPI router for in-app notifications + the manual reminder runner.

A user only ever sees their own notifications: the id comes from the Bearer
token, not a query param.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.user import User
from app.schemas.notification import NotificationOut
from app.schemas.sale import ReminderLogOut
from app.security import get_current_user, require_super_admin
from app.services.notification_service import NotificationService
from app.services.reminder_service import ReminderService

router = APIRouter(tags=["notifications"])


@router.get("/notifications", response_model=list[NotificationOut])
def list_notifications(
    unread_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return NotificationService.list_for_user(db, current_user.id, unread_only=unread_only)


@router.post("/notifications/{notification_id}/read", response_model=NotificationOut)
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return NotificationService.mark_read(db, notification_id)


@router.post("/reminders/run", response_model=list[ReminderLogOut])
def run_reminders(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    """Compute + record due installment reminders (customer + super admins)."""
    return ReminderService.run(db)
