"""FastAPI router for sale financers. All endpoints require a signed-in user."""
from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.user import User
from app.schemas.financer import FinancerCreate, FinancerOut
from app.security import get_current_user
from app.services.sale_financer_service import SaleFinancerService

router = APIRouter(prefix="/sale-financers", tags=["sale-financers"])


@router.get("", response_model=list[FinancerOut])
def list_sale_financers(db: Session = Depends(get_db)):
    return SaleFinancerService.list(db)


@router.post("", response_model=FinancerOut, status_code=201)
def create_sale_financer(
    payload: FinancerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return SaleFinancerService.create(db, payload)


@router.delete("/{financer_id}", status_code=204)
def delete_sale_financer(
    financer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    SaleFinancerService.delete(db, financer_id)
    return Response(status_code=204)
