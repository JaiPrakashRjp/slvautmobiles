"""Data Access Object for in-app notifications."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.notification import Notification


class NotificationDAO:
    @staticmethod
    def list_for_user(db: Session, user_id: int, *, unread_only: bool = False) -> list[Notification]:
        stmt = select(Notification).where(Notification.recipient_user_id == user_id)
        if unread_only:
            stmt = stmt.where(Notification.is_read.is_(False))
        return list(db.scalars(stmt.order_by(Notification.created_at.desc())).all())

    @staticmethod
    def get(db: Session, notification_id: int) -> Notification | None:
        return db.get(Notification, notification_id)

    @staticmethod
    def add(db: Session, notification: Notification) -> Notification:
        db.add(notification)
        db.flush()
        return notification
