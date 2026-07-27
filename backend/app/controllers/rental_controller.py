"""FastAPI router for rentals, rent-collection reminders, and payments.

The acting user (id + role) comes from the Bearer token. Approvals (confirm /
reject / seize-approve / edit-approve) require the Super Admin.
"""
from datetime import date

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import EntityStatus
from app.models.user import User
from app.schemas.rental import RentalCreate, RentalEdit, RentalOut, ReminderCreate
from app.security import get_current_user, require_super_admin
from app.services.rental_service import RentalService

router = APIRouter(prefix="/rentals", tags=["rentals"])


@router.get("", response_model=list[RentalOut])
def list_rentals(
    db: Session = Depends(get_db),
    status: EntityStatus | None = None,
    customer_id: int | None = None,
    vehicle_id: int | None = None,
    module: str | None = Query(None, description="module code (rental)"),
):
    return RentalService.list(
        db, status=status, customer_id=customer_id, vehicle_id=vehicle_id, module=module
    )


@router.get("/{rental_id}", response_model=RentalOut)
def get_rental(rental_id: int, db: Session = Depends(get_db)):
    return RentalService.get(db, rental_id)


@router.post("", response_model=RentalOut, status_code=201)
def create_rental(
    payload: RentalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.create(
        db, payload, actor_role=current_user.role.name, created_by=current_user.id
    )


# ── Edit ─────────────────────────────────────────────────────────────────────
@router.post("/{rental_id}/edit", response_model=RentalOut)
def edit_rental(
    rental_id: int,
    payload: RentalEdit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.edit(
        db, rental_id, payload,
        actor_role=current_user.role.name, by_user_id=current_user.id,
    )


@router.post("/{rental_id}/edit/approve", response_model=RentalOut)
def approve_edit(
    rental_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.approve_edit(db, rental_id, by_user_id=current_user.id)


@router.post("/{rental_id}/edit/reject", response_model=RentalOut)
def reject_edit(
    rental_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.reject_edit(db, rental_id, reason, by_user_id=current_user.id)


# ── Reminders / collections ──────────────────────────────────────────────────
@router.post("/{rental_id}/reminders", response_model=RentalOut, status_code=201)
def add_reminder(
    rental_id: int,
    payload: ReminderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.add_reminder(
        db, rental_id, due_date=payload.due_date, amount=payload.amount,
        created_by=current_user.id,
    )


@router.post("/installments/{installment_id}/take", response_model=RentalOut)
def take_call(
    installment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.take_call(db, installment_id, user_id=current_user.id)


@router.post("/installments/{installment_id}/cancel", response_model=RentalOut)
def cancel_reminder(
    installment_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.cancel_reminder(db, installment_id, reason, user_id=current_user.id)


async def _read_shot(screenshot: UploadFile | None) -> dict | None:
    if screenshot is None:
        return None
    content = await screenshot.read()
    if not content:
        return None
    return {
        "file_name": screenshot.filename or "screenshot",
        "mime_type": screenshot.content_type or "application/octet-stream",
        "size_bytes": len(content),
        "content": content,
    }


@router.post("/installments/{installment_id}/pay", response_model=RentalOut)
async def submit_installment_payment(
    installment_id: int,
    amount: float = Form(...),
    paid_on: date | None = Form(None),
    screenshot: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.submit_payment(
        db, installment_id, amount=amount, actor_role=current_user.role.name,
        recorded_by=current_user.id, paid_on=paid_on, screenshot=await _read_shot(screenshot),
    )


@router.post("/{rental_id}/pay", response_model=RentalOut)
async def submit_manual_payment(
    rental_id: int,
    amount: float = Form(...),
    paid_on: date | None = Form(None),
    screenshot: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.submit_manual_payment(
        db, rental_id, amount=amount, actor_role=current_user.role.name,
        recorded_by=current_user.id, paid_on=paid_on, screenshot=await _read_shot(screenshot),
    )


@router.post("/payments/{payment_id}/approve", response_model=RentalOut)
def approve_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.approve_payment(db, payment_id, by_user_id=current_user.id)


@router.post("/payments/{payment_id}/decline", response_model=RentalOut)
def decline_payment(
    payment_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.decline_payment(db, payment_id, reason, by_user_id=current_user.id)


@router.get("/payments/documents/{doc_id}")
def payment_screenshot(doc_id: int, db: Session = Depends(get_db)):
    doc = RentalService.payment_document(db, doc_id)
    return Response(
        content=doc.content,
        media_type=doc.mime_type,
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )


# ── Completion / approval / seize ─────────────────────────────────────────────
@router.post("/{rental_id}/complete", response_model=RentalOut)
def complete_rental(
    rental_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.complete(db, rental_id, by_user_id=current_user.id)


@router.post("/{rental_id}/confirm", response_model=RentalOut)
def confirm_rental(
    rental_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.confirm(db, rental_id, current_user.id)


@router.post("/{rental_id}/reject", response_model=RentalOut)
def reject_rental(
    rental_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.reject(db, rental_id, reason, current_user.id)


@router.post("/{rental_id}/seize", response_model=RentalOut)
def seize_rental(
    rental_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return RentalService.seize(db, rental_id, reason, current_user.id, current_user.role.name)


@router.post("/{rental_id}/seize/approve", response_model=RentalOut)
def approve_seize(
    rental_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.approve_seize(db, rental_id, by_user_id=current_user.id)


@router.post("/{rental_id}/seize/reject", response_model=RentalOut)
def reject_seize(
    rental_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return RentalService.reject_seize(db, rental_id, reason, by_user_id=current_user.id)


@router.delete("/{rental_id}", status_code=204)
def delete_rental(
    rental_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    RentalService.delete(db, rental_id)
    return Response(status_code=204)
