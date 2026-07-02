"""Lightweight global-search result."""
from pydantic import BaseModel


class SearchResult(BaseModel):
    kind: str  # 'customer' | 'vehicle'
    id: int
    label: str
    subtitle: str = ""
    module: str = "auto_sale"
