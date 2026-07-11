"""Data Access Object for users + module assignment — pure persistence."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.module import Module
from app.models.user import User
from app.models.user_module import UserModule


class UserDAO:
    @staticmethod
    def _with_relations(stmt):
        return stmt.options(
            selectinload(User.role),
            selectinload(User.modules).selectinload(UserModule.module),
        )

    @staticmethod
    def list(db: Session) -> list[User]:
        stmt = UserDAO._with_relations(select(User)).order_by(User.created_at.desc())
        return list(db.scalars(stmt).all())

    @staticmethod
    def get(db: Session, user_id: int) -> User | None:
        return db.scalar(UserDAO._with_relations(select(User)).where(User.id == user_id))

    @staticmethod
    def by_email(db: Session, email: str) -> User | None:
        return db.scalar(
            UserDAO._with_relations(select(User)).where(User.email == email)
        )

    @staticmethod
    def super_admins(db: Session) -> list[User]:
        """Active super-admin users (used for verification notifications + reminders)."""
        from app.models.role import Role

        stmt = (
            UserDAO._with_relations(select(User))
            .join(Role, User.role_id == Role.id)
            .where(Role.name == "super_admin")
        )
        return list(db.scalars(stmt).all())

    @staticmethod
    def active_staff(db: Session) -> list[User]:
        """All active staff (admins + super admins) — reminder push recipients."""
        from app.models.enums import AccountStatus, EntityStatus

        stmt = UserDAO._with_relations(select(User)).where(
            User.status == EntityStatus.active,
            User.account_status == AccountStatus.active,
        )
        return list(db.scalars(stmt).all())

    @staticmethod
    def add(db: Session, user: User) -> User:
        db.add(user)
        db.flush()
        return user

    @staticmethod
    def update(db: Session, user: User, fields: dict) -> User:
        for key, value in fields.items():
            setattr(user, key, value)
        db.flush()
        return user

    @staticmethod
    def delete(db: Session, user: User) -> None:
        db.delete(user)

    @staticmethod
    def module_id_by_code(db: Session, code: str) -> int | None:
        return db.scalar(select(Module.id).where(Module.code == code))

    @staticmethod
    def clear_modules(db: Session, user_id: int) -> None:
        for um in db.scalars(select(UserModule).where(UserModule.user_id == user_id)).all():
            db.delete(um)
        db.flush()

    @staticmethod
    def add_module(db: Session, user_id: int, module_id: int, assigned_by: int | None) -> None:
        db.add(UserModule(user_id=user_id, module_id=module_id, assigned_by=assigned_by))
        db.flush()
