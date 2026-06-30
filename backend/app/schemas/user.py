"""Pydantic request/response schemas for users, roles, and login."""
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.enums import AccountStatus, EntityStatus


class RoleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    label: str


class LoginRequest(BaseModel):
    email: str
    password: str


class UserCreate(BaseModel):
    first_name: str
    last_name: str = ""
    email: str
    phone: str
    role: str = "admin"            # role name: super_admin | admin
    password: str
    module_codes: list[str] = []   # modules to grant (from the modules table)


class UserUpdate(BaseModel):
    """All optional — only provided keys change (PATCH)."""
    first_name: str | None = None
    last_name: str | None = None
    email: str | None = None
    phone: str | None = None
    role: str | None = None
    password: str | None = None
    account_status: AccountStatus | None = None
    status: EntityStatus | None = None


class ModuleAssign(BaseModel):
    module_codes: list[str]


class UserOut(BaseModel):
    id: int
    first_name: str
    last_name: str
    email: str
    phone: str
    role: str                      # role name
    role_label: str
    account_status: AccountStatus
    status: EntityStatus
    created_by: int
    created_at: datetime
    module_codes: list[str] = []


class TokenOut(BaseModel):
    """Login response: the signed bearer token plus the user it belongs to."""
    access_token: str
    token_type: str = "bearer"
    user: UserOut
