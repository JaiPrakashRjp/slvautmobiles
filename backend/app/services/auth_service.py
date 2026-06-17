"""Password hashing + email/password login."""
import bcrypt
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.user_dao import UserDAO
from app.models.enums import AccountStatus, EntityStatus
from app.models.user import User


def hash_password(password: str) -> str:
    pw = password.encode("utf-8")[:72]  # bcrypt caps at 72 bytes
    return bcrypt.hashpw(pw, bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(
            password.encode("utf-8")[:72], password_hash.encode("utf-8")
        )
    except ValueError:
        return False


class AuthService:
    @staticmethod
    def login(db: Session, email: str, password: str) -> User:
        user = UserDAO.by_email(db, email.strip().lower())
        if user is None or not verify_password(password, user.password_hash):
            raise HTTPException(status_code=401, detail="Wrong email or password")
        if user.account_status == AccountStatus.suspended:
            raise HTTPException(status_code=403, detail="This account is suspended")
        if user.status != EntityStatus.active:
            raise HTTPException(
                status_code=403, detail="This account is not yet verified"
            )
        return user
