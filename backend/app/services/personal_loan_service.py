"""Business logic for personal loans (simple monthly EMI, mark-paid)."""
import calendar
from datetime import date, datetime, timezone

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.personal_loan_dao import PersonalLoanDAO
from app.models.enums import InstallmentStatus
from app.models.personal_loan import PersonalLoan
from app.models.personal_loan_emi import PersonalLoanEmi
from app.models.personal_loan_financer import PersonalLoanFinancer
from app.schemas.personal_loan import PersonalLoanCreate, PersonalLoanFinancerCreate


def _add_months(d: date, n: int) -> date:
    m = d.month - 1 + n
    y = d.year + m // 12
    m = m % 12 + 1
    last = calendar.monthrange(y, m)[1]
    return date(y, m, min(d.day, last))


class PersonalLoanService:
    # ── financers (own master for this module) ───────────────────────────────
    @staticmethod
    def financers(db: Session) -> list[PersonalLoanFinancer]:
        return PersonalLoanDAO.financers(db)

    @staticmethod
    def create_financer(
        db: Session, data: PersonalLoanFinancerCreate
    ) -> PersonalLoanFinancer:
        financer = PersonalLoanFinancer(name=data.name.strip())
        PersonalLoanDAO.add_financer(db, financer)
        db.commit()
        return PersonalLoanDAO.financer(db, financer.id)

    @staticmethod
    def delete_financer(db: Session, financer_id: int) -> None:
        financer = PersonalLoanDAO.financer(db, financer_id)
        if financer is None:
            raise HTTPException(status_code=404, detail="Financer not found")
        PersonalLoanDAO.delete_financer(db, financer)
        db.commit()

    # ── loans ────────────────────────────────────────────────────────────────
    @staticmethod
    def list(db: Session) -> list[PersonalLoan]:
        return PersonalLoanDAO.loans(db)

    @staticmethod
    def get(db: Session, loan_id: int) -> PersonalLoan:
        loan = PersonalLoanDAO.get(db, loan_id)
        if loan is None:
            raise HTTPException(status_code=404, detail="Personal loan not found")
        return loan

    @staticmethod
    def create(db: Session, data: PersonalLoanCreate, *, created_by: int) -> PersonalLoan:
        if data.tenure_months <= 0:
            raise HTTPException(status_code=400, detail="Tenure must be at least 1 month")
        first_due = _add_months(data.loan_date, 1)
        loan = PersonalLoan(
            vehicle_number=data.vehicle_number.strip(),
            financer_id=data.financer_id,
            loan_amount=data.loan_amount,
            emi_amount=data.emi_amount,
            tenure_months=data.tenure_months,
            loan_date=data.loan_date,
            first_due_date=first_due,
            phone=(data.phone or "").strip() or None,
            loan_status="active",
            remarks=data.remarks,
            created_by=created_by,
        )
        for i in range(data.tenure_months):
            loan.emis.append(
                PersonalLoanEmi(
                    sequence_number=i + 1,
                    due_date=_add_months(data.loan_date, i + 1),
                    amount=data.emi_amount,
                    status=InstallmentStatus.pending,
                )
            )
        PersonalLoanDAO.add(db, loan)
        db.commit()
        return PersonalLoanDAO.get(db, loan.id)

    @staticmethod
    def mark_emi_paid(db: Session, loan_id: int, emi_id: int) -> PersonalLoan:
        loan = PersonalLoanService.get(db, loan_id)
        emi = PersonalLoanDAO.get_emi(db, emi_id)
        if emi is None or emi.personal_loan_id != loan.id:
            raise HTTPException(status_code=404, detail="EMI not found")
        emi.status = InstallmentStatus.paid
        emi.paid_date = date.today()
        if all(e.status == InstallmentStatus.paid for e in loan.emis):
            loan.loan_status = "closed"
            loan.closed_at = datetime.now(timezone.utc)
        db.commit()
        return PersonalLoanDAO.get(db, loan_id)

    @staticmethod
    def delete(db: Session, loan_id: int) -> None:
        loan = PersonalLoanService.get(db, loan_id)
        db.delete(loan)
        db.commit()
