"""Lightweight global-search result."""
from pydantic import BaseModel


class SearchVehicle(BaseModel):
    """A vehicle a customer bought — nested under a customer search result."""
    id: int
    label: str          # reg no / model
    subtitle: str = ""  # model · sale status


class SearchResult(BaseModel):
    kind: str  # 'customer' | 'vehicle'
    id: int
    label: str
    subtitle: str = ""
    module: str = "auto_sale"
    # For customer results: every vehicle sold to them (can be more than one).
    vehicles: list[SearchVehicle] = []
