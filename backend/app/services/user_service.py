"""Business logic for users + roles + module assignment."""
from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.role_dao import RoleDAO
from app.dao.user_dao import UserDAO
from app.models.enums import AccountStatus, EntityStatus
from app.models.user import User
from app.schemas.user import UserCreate, UserOut, UserUpdate
from app.services.auth_service import hash_password


def serialize(user: User) -> UserOut:
    """Flatten a User ORM object (with role + modules loaded) into UserOut."""
    return UserOut(
        id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        phone=user.phone,
        role=user.role.name,
        role_label=user.role.label,
        account_status=user.account_status,
        status=user.status,
        created_by=user.created_by,
        created_at=user.created_at,
        module_codes=[um.module.code for um in user.modules],
    )


class UserService:
    @staticmethod
    def list(db: Session) -> list[UserOut]:
        return [serialize(u) for u in UserDAO.list(db)]

    @staticmethod
    def get(db: Session, user_id: int) -> User:
        user = UserDAO.get(db, user_id)
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        return user

    @staticmethod
    def get_out(db: Session, user_id: int) -> UserOut:
        return serialize(UserService.get(db, user_id))

    @staticmethod
    def roles(db: Session):
        return RoleDAO.list(db)

    @staticmethod
    def _role_id(db: Session, role_name: str) -> int:
        role = RoleDAO.by_name(db, role_name)
        if role is None:
            raise HTTPException(status_code=400, detail=f"Unknown role '{role_name}'")
        return role.id

    @staticmethod
    def _set_modules(db: Session, user_id: int, codes: list[str], assigned_by: int | None) -> None:
        UserDAO.clear_modules(db, user_id)
        for code in dict.fromkeys(codes):  # dedupe, keep order
            module_id = UserDAO.module_id_by_code(db, code)
            if module_id is None:
                raise HTTPException(status_code=400, detail=f"Unknown module '{code}'")
            UserDAO.add_module(db, user_id, module_id, assigned_by)

    @staticmethod
    def create(db: Session, data: UserCreate, *, created_by: int) -> UserOut:
        if UserDAO.by_email(db, data.email.strip().lower()) is not None:
            raise HTTPException(status_code=409, detail="A user with this email already exists")
        user = User(
            first_name=data.first_name,
            last_name=data.last_name,
            email=data.email.strip().lower(),
            phone=data.phone,
            role_id=UserService._role_id(db, data.role),
            password_hash=hash_password(data.password),
            account_status=AccountStatus.active,
            status=EntityStatus.active,  # super admin creates verified users
            created_by=created_by,
        )
        UserDAO.add(db, user)
        UserService._set_modules(db, user.id, data.module_codes, created_by)
        db.commit()
        return UserService.get_out(db, user.id)

    @staticmethod
    def update(db: Session, user_id: int, data: UserUpdate) -> UserOut:
        user = UserService.get(db, user_id)
        fields = data.model_dump(exclude_unset=True, exclude={"password", "role"})
        if data.password:
            fields["password_hash"] = hash_password(data.password)
        if data.role:
            fields["role_id"] = UserService._role_id(db, data.role)
        if "email" in fields and fields["email"]:
            fields["email"] = fields["email"].strip().lower()
        UserDAO.update(db, user, fields)
        db.commit()
        return UserService.get_out(db, user_id)

    @staticmethod
    def set_modules(db: Session, user_id: int, codes: list[str], by_user_id: int) -> UserOut:
        UserService.get(db, user_id)  # 404 guard
        UserService._set_modules(db, user_id, codes, by_user_id)
        db.commit()
        return UserService.get_out(db, user_id)

    @staticmethod
    def set_account_status(db: Session, user_id: int, status: AccountStatus) -> UserOut:
        user = UserService.get(db, user_id)
        user.account_status = status
        db.commit()
        return UserService.get_out(db, user_id)

    @staticmethod
    def delete(db: Session, user_id: int) -> None:
        user = UserService.get(db, user_id)
        UserDAO.delete(db, user)
        db.commit()
