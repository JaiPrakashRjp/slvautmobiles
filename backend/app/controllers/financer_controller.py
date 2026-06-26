"""FastAPI router for the financers module."""
from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.financer import FinancerCreate, FinancerOut
from app.services.financer_service import FinancerService

router = APIRouter(prefix="/financers", tags=["financers"])


@router.get("", response_model=list[FinancerOut])
def list_financers(db: Session = Depends(get_db)):
    return FinancerService.list(db)


@router.post("", response_model=FinancerOut, status_code=201)
def create_financer(payload: FinancerCreate, db: Session = Depends(get_db)):
    return FinancerService.create(db, payload)


@router.delete("/{financer_id}", status_code=204)
def delete_financer(financer_id: int, db: Session = Depends(get_db)):
    FinancerService.delete(db, financer_id)
    return Response(status_code=204)
