"""App version endpoint — installed apps poll this to prompt for updates.

Public (no auth) so the login/splash screen can check before sign-in.
"""
from fastapi import APIRouter
from pydantic import BaseModel

from app import app_release

router = APIRouter(tags=["app"])


class AppVersion(BaseModel):
    latest_version: str
    download_path: str
    notes: str = ""
    mandatory: bool = False


@router.get("/app-version", response_model=AppVersion)
def app_version():
    return AppVersion(
        latest_version=app_release.LATEST_VERSION,
        download_path=app_release.DOWNLOAD_PATH,
        notes=app_release.NOTES,
        mandatory=app_release.MANDATORY,
    )
