"""FastAPI router for the loans module.

Acting user (id + role) comes from the Bearer token; approvals require the
Super Admin. Loans persist to the loans / loan_emis / loan_payments tables.
Every read/write is also scoped to the caller's data silo (get_silo_user_ids)
so one super_admin's data is never visible to, or editable by, another.
"""
from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import EntityStatus
from app.models.user import User
from app.schemas.loan import LoanCreate, LoanEdit, LoanOut
from app.security import get_current_user, get_silo_user_ids, require_super_admin
from app.services.loan_reminder_service import LoanReminderService
from app.services.loan_service import LoanService

router = APIRouter(prefix="/loans", tags=["loans"])


@router.get("", response_model=list[LoanOut])
def list_loans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    module: str | None = Query(None, description="module code (loan)"),
    status: EntityStatus | None = None,
    customer_id: int | None = None,
):
    return LoanService.list(
        db, module=module, status=status, customer_id=customer_id,
        silo_ids=get_silo_user_ids(db, current_user),
    )


@router.get("/{loan_id}", response_model=LoanOut)
def get_loan(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return LoanService.get(db, loan_id, get_silo_user_ids(db, current_user))


@router.post("", response_model=LoanOut, status_code=201)
def create_loan(
    payload: LoanCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return LoanService.create(
        db, payload, actor_role=current_user.role.name, created_by=current_user.id
    )


@router.post("/{loan_id}/edit", response_model=LoanOut)
def edit_loan(
    loan_id: int,
    payload: LoanEdit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Full edit within the 2-hour grace window; rebuilds the EMI schedule and
    discards any recorded payments (the client warns first)."""
    return LoanService.edit(
        db, loan_id, payload, actor_role=current_user.role.name, actor_id=current_user.id,
        silo_ids=get_silo_user_ids(db, current_user),
    )


@router.post("/{loan_id}/confirm", response_model=LoanOut)
def confirm_loan(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return LoanService.confirm(
        db, loan_id, current_user.id, get_silo_user_ids(db, current_user)
    )


@router.post("/{loan_id}/reject", response_model=LoanOut)
def reject_loan(
    loan_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return LoanService.reject(
        db, loan_id, reason, current_user.id, get_silo_user_ids(db, current_user)
    )


@router.post("/{loan_id}/seize", response_model=LoanOut)
def request_seize(
    loan_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return LoanService.request_seize(
        db, loan_id, reason,
        actor_role=current_user.role.name, actor_id=current_user.id,
        silo_ids=get_silo_user_ids(db, current_user),
    )


@router.post("/{loan_id}/seize/confirm", response_model=LoanOut)
def confirm_seize(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return LoanService.confirm_seize(
        db, loan_id, current_user.id, get_silo_user_ids(db, current_user)
    )


@router.post("/{loan_id}/seize/cancel", response_model=LoanOut)
def cancel_seize(
    loan_id: int,
    remarks: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return LoanService.cancel_seize(
        db, loan_id, remarks, current_user.id, get_silo_user_ids(db, current_user)
    )


@router.delete("/{loan_id}", status_code=204)
def delete_loan(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    LoanService.delete(db, loan_id, get_silo_user_ids(db, current_user))
    return Response(status_code=204)


# ── Payments ─────────────────────────────────────────────────────────────────
@router.post("/{loan_id}/emis/{emi_id}/pay", response_model=LoanOut)
async def record_emi_payment(
    loan_id: int,
    emi_id: int,
    amount: Decimal = Form(...),
    penalty: Decimal = Form(0),
    received_date: date | None = Form(None),
    remarks: str | None = Form(None),
    file: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    silo_ids = get_silo_user_ids(db, current_user)
    payment = LoanService.record_payment(
        db,
        loan_id,
        emi_id,
        amount=amount,
        penalty=penalty,
        received_date=received_date,
        remarks=remarks,
        recorded_by=current_user.id,
        silo_ids=silo_ids,
    )
    if file is not None:
        content = await file.read()
        if content:
            LoanService.add_payment_document(
                db, payment.id, file.filename, file.content_type, content,
                current_user.id,
            )
    return LoanService.get(db, loan_id, silo_ids)


@router.get("/payment-documents/{doc_id}")
def download_payment_document(
    doc_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    doc = LoanService.get_payment_document(db, doc_id, get_silo_user_ids(db, current_user))
    return Response(
        content=doc.content,
        media_type=doc.mime_type,
        headers={
            "Content-Disposition": f'inline; filename="{doc.file_name}"',
            "Cache-Control": "public, max-age=31536000, immutable",
        },
    )


@router.delete("/payment-documents/{doc_id}", status_code=204)
def delete_payment_document(
    doc_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    LoanService.delete_payment_document(db, doc_id, get_silo_user_ids(db, current_user))
    return Response(status_code=204)


@router.post("/reminders/run")
def run_loan_reminders(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    created = LoanReminderService.run(db)
    return {"dispatched": len(created)}
