"""DAO for device (FCM) tokens — pure DB access, no business rules."""
from __future__ import annotations

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.device_token import DeviceToken


class DeviceTokenDAO:
    @staticmethod
    def upsert(db: Session, *, token: str, user_id: int, platform: str | None) -> DeviceToken:
        """Register a token, or re-point an existing one to the current user."""
        row = db.scalar(select(DeviceToken).where(DeviceToken.token == token))
        if row is None:
            row = DeviceToken(token=token, user_id=user_id, platform=platform)
            db.add(row)
        else:
            row.user_id = user_id
            if platform:
                row.platform = platform
        db.commit()
        return row

    @staticmethod
    def tokens_for_users(db: Session, user_ids: list[int]) -> list[str]:
        if not user_ids:
            return []
        rows = db.scalars(
            select(DeviceToken.token).where(DeviceToken.user_id.in_(user_ids))
        ).all()
        return list(rows)

    @staticmethod
    def delete_by_token(db: Session, token: str) -> None:
        db.execute(delete(DeviceToken).where(DeviceToken.token == token))
        db.commit()
