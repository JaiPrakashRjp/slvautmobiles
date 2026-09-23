"""FastAPI router for the personal-loans module (+ its own financer master).

Every loan read/write is scoped to the caller's data silo (get_silo_user_ids)
so one super_admin's data is never visible to, or editable by, another. The
financer master is shared reference data (no created_by column) and stays
unscoped, same as vehicle/sale financers.
"""
from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.user import User
from app.schemas.personal_loan import (
    PersonalLoanCreate,
    PersonalLoanFinancerCreate,
    PersonalLoanFinancerOut,
    PersonalLoanOut,
)
from app.security import get_current_user, get_silo_user_ids, require_super_admin
from app.services.personal_loan_reminder_service import PersonalLoanReminderService
from app.services.personal_loan_service import PersonalLoanService

router = APIRouter(prefix="/personal-loans", tags=["personal-loans"])


# ── Financers (personal-loan-scoped master) ───────────────────────────────────
@router.get("/financers", response_model=list[PersonalLoanFinancerOut])
def list_financers(db: Session = Depends(get_db)):
    return PersonalLoanService.financers(db)


@router.post("/financers", response_model=PersonalLoanFinancerOut, status_code=201)
def create_financer(
    payload: PersonalLoanFinancerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return PersonalLoanService.create_financer(db, payload)


@router.delete("/financers/{financer_id}", status_code=204)
def delete_financer(
    financer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    PersonalLoanService.delete_financer(db, financer_id)
    return Response(status_code=204)


# ── Loans ─────────────────────────────────────────────────────────────────────
@router.get("", response_model=list[PersonalLoanOut])
def list_loans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return PersonalLoanService.list(db, silo_ids=get_silo_user_ids(db, current_user))


@router.get("/{loan_id}", response_model=PersonalLoanOut)
def get_loan(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return PersonalLoanService.get(db, loan_id, get_silo_user_ids(db, current_user))


@router.post("", response_model=PersonalLoanOut, status_code=201)
def create_loan(
    payload: PersonalLoanCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return PersonalLoanService.create(db, payload, created_by=current_user.id)


@router.post("/{loan_id}/emis/{emi_id}/pay", response_model=PersonalLoanOut)
def mark_emi_paid(
    loan_id: int,
    emi_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return PersonalLoanService.mark_emi_paid(
        db, loan_id, emi_id, get_silo_user_ids(db, current_user)
    )


@router.delete("/{loan_id}", status_code=204)
def delete_loan(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    PersonalLoanService.delete(db, loan_id, get_silo_user_ids(db, current_user))
    return Response(status_code=204)


@router.post("/reminders/run")
def run_personal_loan_reminders(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    created = PersonalLoanReminderService.run(db)
    return {"dispatched": len(created)}
