"""Password hashing + email/password login + signed bearer tokens."""
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.config import settings
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


def create_access_token(user: User) -> str:
    """Sign a JWT carrying the user's id and role. The role travels in the token
    (not a client-supplied param) so the server, not the caller, decides whether
    an action is a super-admin action."""
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user.id),
        "role": user.role.name,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)).timestamp()),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALG)


def decode_token(token: str) -> dict:
    """Verify signature + expiry and return the claims. Raises jwt.PyJWTError on
    any problem (bad signature, expired, malformed)."""
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALG])


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
