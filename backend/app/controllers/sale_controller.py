"""FastAPI router for sales, installments, payments, and per-sale reminders.

NOTE: auth isn't tokenised yet — `created_by` / `actor_role` / `by_user_id` /
`recorded_by` are passed explicitly (the real signed-in user) until bearer
tokens land.
"""
from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import EntityStatus
from app.schemas.sale import ReminderLogOut, SaleCreate, SaleOut
from app.services.sale_service import SaleService

router = APIRouter(prefix="/sales", tags=["sales"])


@router.get("", response_model=list[SaleOut])
def list_sales(
    db: Session = Depends(get_db),
    status: EntityStatus | None = None,
    customer_id: int | None = None,
    vehicle_id: int | None = None,
):
    return SaleService.list(db, status=status, customer_id=customer_id, vehicle_id=vehicle_id)


@router.get("/{sale_id}", response_model=SaleOut)
def get_sale(sale_id: int, db: Session = Depends(get_db)):
    return SaleService.get(db, sale_id)


@router.post("", response_model=SaleOut, status_code=201)
def create_sale(
    payload: SaleCreate,
    created_by: int = Query(...),
    actor_role: str = Query("admin", description="super_admin | admin"),
    db: Session = Depends(get_db),
):
    return SaleService.create(db, payload, actor_role=actor_role, created_by=created_by)


@router.post("/installments/{installment_id}/pay", response_model=SaleOut)
def mark_installment_paid(
    installment_id: int,
    recorded_by: int = Query(...),
    db: Session = Depends(get_db),
):
    return SaleService.mark_paid(db, installment_id, recorded_by=recorded_by)


@router.post("/{sale_id}/payoff", response_model=SaleOut)
def pay_off(sale_id: int, recorded_by: int = Query(...), db: Session = Depends(get_db)):
    return SaleService.pay_off(db, sale_id, recorded_by=recorded_by)


@router.post("/{sale_id}/confirm", response_model=SaleOut)
def confirm_sale(sale_id: int, by_user_id: int = Query(...), db: Session = Depends(get_db)):
    return SaleService.confirm(db, sale_id, by_user_id)


@router.post("/{sale_id}/reject", response_model=SaleOut)
def reject_sale(
    sale_id: int,
    reason: str = Query(..., min_length=1),
    by_user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return SaleService.reject(db, sale_id, reason, by_user_id)


@router.post("/{sale_id}/cancel", response_model=SaleOut)
def cancel_sale(
    sale_id: int,
    reason: str = Query(..., min_length=1),
    by_user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return SaleService.cancel(db, sale_id, reason, by_user_id)


@router.delete("/{sale_id}", status_code=204)
def delete_sale(sale_id: int, db: Session = Depends(get_db)):
    SaleService.delete(db, sale_id)
    return Response(status_code=204)


@router.get("/{sale_id}/reminders", response_model=list[ReminderLogOut])
def sale_reminders(sale_id: int, db: Session = Depends(get_db)):
    return SaleService.reminders_for_sale(db, sale_id)
