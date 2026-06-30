"""FastAPI router for user management (super admin creates/assigns admins).

All mutations require the Super Admin (require_super_admin); the acting user id
comes from the Bearer token, not a client param. List/get reads stay open
(consistent with the other modules' read endpoints).
"""
from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import AccountStatus
from app.models.user import User
from app.schemas.user import ModuleAssign, RoleOut, UserCreate, UserOut, UserUpdate
from app.security import require_super_admin
from app.services.user_service import UserService

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/roles", response_model=list[RoleOut])
def list_roles(db: Session = Depends(get_db)):
    return UserService.roles(db)


@router.get("", response_model=list[UserOut])
def list_users(db: Session = Depends(get_db)):
    return UserService.list(db)


@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: int, db: Session = Depends(get_db)):
    return UserService.get_out(db, user_id)


@router.post("", response_model=UserOut, status_code=201)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return UserService.create(db, payload, created_by=current_user.id)


@router.patch("/{user_id}", response_model=UserOut)
def update_user(
    user_id: int,
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return UserService.update(db, user_id, payload)


@router.put("/{user_id}/modules", response_model=UserOut)
def set_modules(
    user_id: int,
    payload: ModuleAssign,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return UserService.set_modules(db, user_id, payload.module_codes, current_user.id)


@router.post("/{user_id}/suspend", response_model=UserOut)
def suspend_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return UserService.set_account_status(db, user_id, AccountStatus.suspended)


@router.post("/{user_id}/activate", response_model=UserOut)
def activate_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return UserService.set_account_status(db, user_id, AccountStatus.active)


@router.delete("/{user_id}", status_code=204)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    UserService.delete(db, user_id)
    return Response(status_code=204)
