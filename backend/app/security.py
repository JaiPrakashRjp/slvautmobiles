"""Auth dependencies: resolve the signed-in user from the Bearer token.

These replace the old trust-the-client query params (`actor_role`, `created_by`,
`by_user_id`). The role and user id now come from a signed JWT the server issued
at login, so a caller can no longer claim to be a super admin.
"""
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import AccountStatus, EntityStatus
from app.models.user import User
from app.services.auth_service import decode_token

# auto_error=True → missing/blank Authorization header yields a 403 automatically.
_bearer = HTTPBearer(auto_error=True)


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    """Decode the Bearer token and load the active user it refers to."""
    try:
        payload = decode_token(creds.credentials)
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired session")

    sub = payload.get("sub")
    user = db.get(User, int(sub)) if sub is not None else None
    if user is None:
        raise HTTPException(status_code=401, detail="Session user no longer exists")
    if user.account_status == AccountStatus.suspended:
        raise HTTPException(status_code=403, detail="This account is suspended")
    if user.status != EntityStatus.active:
        raise HTTPException(status_code=403, detail="This account is not yet verified")
    return user


def require_super_admin(user: User = Depends(get_current_user)) -> User:
    """Guard for actions only the Super Admin may take (approvals, user admin)."""
    if user.role.name != "super_admin":
        raise HTTPException(status_code=403, detail="Super admin only")
    return user
