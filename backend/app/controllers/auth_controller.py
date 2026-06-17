"""FastAPI router for authentication (email + password login)."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.user import LoginRequest, UserOut
from app.services.auth_service import AuthService
from app.services.user_service import serialize

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=UserOut)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = AuthService.login(db, payload.email, payload.password)
    return serialize(user)
