"""In-app notification logic (verification alerts to super admins)."""
from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.device_token_dao import DeviceTokenDAO
from app.dao.notification_dao import NotificationDAO
from app.dao.user_dao import UserDAO
from app.models.enums import NotificationEntity, NotificationType
from app.models.notification import Notification
from app.services.fcm_service import FcmService


class NotificationService:
    @staticmethod
    def list_for_user(db: Session, user_id: int, *, unread_only: bool = False):
        return NotificationDAO.list_for_user(db, user_id, unread_only=unread_only)

    @staticmethod
    def mark_read(db: Session, notification_id: int):
        n = NotificationDAO.get(db, notification_id)
        if n is None:
            raise HTTPException(status_code=404, detail="Notification not found")
        n.is_read = True
        db.commit()
        return n

    @staticmethod
    def create_verification(
        db: Session,
        *,
        entity_type: NotificationEntity,
        entity_id: int,
        title: str,
        message: str = "",
    ) -> None:
        """Notify every super admin that an admin-created record needs approval.

        Adds rows in the current transaction (the caller commits). Also fires an
        FCM push to the super admins' devices so it reaches them even when the
        app is closed (best-effort; a push failure never breaks the caller).
        """
        super_admin_ids = [sa.id for sa in UserDAO.super_admins(db)]
        for sa_id in super_admin_ids:
            NotificationDAO.add(
                db,
                Notification(
                    recipient_user_id=sa_id,
                    type=NotificationType.verification_request,
                    title=title,
                    message=message,
                    entity_type=entity_type,
                    entity_id=entity_id,
                ),
            )

        # Push to their phones (tokens registered earlier, in their own commit).
        tokens = DeviceTokenDAO.tokens_for_users(db, super_admin_ids)
        FcmService.send(
            tokens,
            title=title,
            body=message or "Tap to review",
            data={
                "type": "verification",
                "entity_type": entity_type.value,
                "entity_id": entity_id,
            },
        )
