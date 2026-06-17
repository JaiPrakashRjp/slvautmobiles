"""Data Access Object for roles — pure persistence."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.role import Role


class RoleDAO:
    @staticmethod
    def list(db: Session) -> list[Role]:
        return list(db.scalars(select(Role).order_by(Role.id)).all())

    @staticmethod
    def by_name(db: Session, name: str) -> Role | None:
        return db.scalar(select(Role).where(Role.name == name))

    @staticmethod
    def get(db: Session, role_id: int) -> Role | None:
        return db.get(Role, role_id)
