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


def silo_member_ids(db: Session, owner_id: int) -> list[int]:
    """All user ids in a super_admin's data silo: themself plus every admin
    they created. Each super_admin has their own fully separate pool of
    business data; an admin shares their creating super admin's silo.
    """
    from app.models.role import Role  # local import avoids a circular import

    admin_ids = [
        u.id
        for u in db.query(User)
        .join(Role, User.role_id == Role.id)
        .filter(User.created_by == owner_id, Role.name == "admin")
        .all()
    ]
    return [owner_id, *admin_ids]


def get_silo_user_ids(db: Session, user: User) -> list[int]:
    """Data-isolation silo for this signed-in user (controllers already have
    the User object from the JWT via get_current_user, so this skips a
    redundant lookup). Used to filter created_by on every business-data query
    so one super_admin's data is never visible to another.
    """
    owner_id = user.id if user.role.name == "super_admin" else user.created_by
    return silo_member_ids(db, owner_id)


def silo_ids_for_creator(db: Session, creator_id: int) -> list[int]:
    """Data-isolation silo that a given entity's `created_by` id belongs to —
    for background jobs (reminder crons) that only have the entity, not a
    live signed-in User.
    """
    creator = db.get(User, creator_id)
    owner_id = (
        creator_id
        if creator is None or creator.role.name == "super_admin"
        else creator.created_by
    )
    return silo_member_ids(db, owner_id)
