"""FastAPI router for device (FCM) token registration.

The app registers its push token here after login so the backend can reach it
even when the app is closed. The user is taken from the Bearer token.
"""
from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.dao.device_token_dao import DeviceTokenDAO
from app.db import get_db
from app.models.user import User
from app.schemas.device import DeviceTokenIn
from app.security import get_current_user

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register", status_code=204)
def register_device(
    payload: DeviceTokenIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    DeviceTokenDAO.upsert(
        db, token=payload.token, user_id=current_user.id, platform=payload.platform
    )
    return Response(status_code=204)


@router.post("/unregister", status_code=204)
def unregister_device(
    payload: DeviceTokenIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Called on sign-out so a shared phone stops receiving the old user's pushes."""
    DeviceTokenDAO.delete_by_token(db, payload.token)
    return Response(status_code=204)
