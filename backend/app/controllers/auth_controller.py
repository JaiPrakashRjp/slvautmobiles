"""FastAPI router for authentication (email + password login)."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.user import LoginRequest, TokenOut, UserOut
from app.security import get_current_user
from app.services.auth_service import AuthService, create_access_token
from app.services.user_service import serialize

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenOut)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = AuthService.login(db, payload.email, payload.password)
    return TokenOut(access_token=create_access_token(user), user=serialize(user))


@router.get("/me", response_model=UserOut)
def me(current_user=Depends(get_current_user)):
    """Return the signed-in user — lets the app validate a stored token on launch."""
    return serialize(current_user)
