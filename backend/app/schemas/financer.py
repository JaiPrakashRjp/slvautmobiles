"""Pydantic schemas for the financers module."""
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class FinancerCreate(BaseModel):
    name: str


class FinancerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    created_at: datetime
