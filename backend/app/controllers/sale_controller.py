"""FastAPI router for sales, installments, payments, and per-sale reminders.

The acting user (id + role) comes from the Bearer token via get_current_user,
not from client params. Approvals (confirm/reject/cancel) require the Super
Admin; recording payments only needs an authenticated user.
"""
from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import EntityStatus
from app.models.user import User
from app.schemas.sale import ReminderLogOut, SaleCreate, SaleOut
from app.security import get_current_user, require_super_admin
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
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return SaleService.create(
        db, payload, actor_role=current_user.role.name, created_by=current_user.id
    )


@router.post("/installments/{installment_id}/pay", response_model=SaleOut)
def mark_installment_paid(
    installment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return SaleService.mark_paid(db, installment_id, recorded_by=current_user.id)


@router.post("/{sale_id}/payoff", response_model=SaleOut)
def pay_off(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return SaleService.pay_off(db, sale_id, recorded_by=current_user.id)


@router.post("/{sale_id}/confirm", response_model=SaleOut)
def confirm_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return SaleService.confirm(db, sale_id, current_user.id)


@router.post("/{sale_id}/reject", response_model=SaleOut)
def reject_sale(
    sale_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return SaleService.reject(db, sale_id, reason, current_user.id)


@router.post("/{sale_id}/cancel", response_model=SaleOut)
def cancel_sale(
    sale_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return SaleService.cancel(db, sale_id, reason, current_user.id)


@router.delete("/{sale_id}", status_code=204)
def delete_sale(
    sale_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    SaleService.delete(db, sale_id)
    return Response(status_code=204)


@router.get("/{sale_id}/reminders", response_model=list[ReminderLogOut])
def sale_reminders(sale_id: int, db: Session = Depends(get_db)):
    return SaleService.reminders_for_sale(db, sale_id)
