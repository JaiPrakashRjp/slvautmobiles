"""Business logic for loans — no interest, typed EMI, penalty on late months.

Role-gate mirrors the rest of the app: a Super Admin's loan is active at once;
an Admin's loan waits pending_confirmation until a Super Admin approves it.
"""
import calendar
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.loan_dao import LoanDAO
from app.models.enums import EntityStatus, InstallmentStatus, NotificationEntity
from app.models.loan import Loan
from app.models.loan_emi import LoanEmi
from app.models.loan_payment import LoanPayment
from app.models.loan_payment_document import LoanPaymentDocument
from app.schemas.loan import LoanCreate, LoanEdit
from app.services.notification_service import NotificationService
from app.services.vehicle_service import initial_status

# How long after booking a loan stays editable. After this the schedule is
# locked and the client hides the Edit button (the server enforces it too).
EDIT_WINDOW = timedelta(hours=5)


def _add_months(d: date, n: int) -> date:
    """Date n months after d, clamping the day to the target month's length."""
    m = d.month - 1 + n
    y = d.year + m // 12
    m = m % 12 + 1
    last = calendar.monthrange(y, m)[1]
    return date(y, m, min(d.day, last))


class LoanService:
    @staticmethod
    def list(db: Session, *, module=None, status=None, customer_id=None) -> list[Loan]:
        return LoanDAO.list(db, module=module, status=status, customer_id=customer_id)

    @staticmethod
    def get(db: Session, loan_id: int) -> Loan:
        loan = LoanDAO.get(db, loan_id)
        if loan is None:
            raise HTTPException(status_code=404, detail="Loan not found")
        return loan

    @staticmethod
    def create(
        db: Session, data: LoanCreate, *, actor_role: str, created_by: int
    ) -> Loan:
        module_id = LoanDAO.module_id_by_code(db, data.module_code)
        if module_id is None:
            raise HTTPException(status_code=400, detail=f"Unknown module '{data.module_code}'")
        if data.tenure_months <= 0:
            raise HTTPException(status_code=400, detail="Tenure must be at least 1 month")

        status = data.status or initial_status(actor_role)
        first_due = _add_months(data.loan_date, 1)
        loan = Loan(
            module_id=module_id,
            customer_id=data.customer_id,
            vehicle_id=data.vehicle_id,
            principal=data.principal,
            emi_amount=data.emi_amount,
            tenure_months=data.tenure_months,
            loan_date=data.loan_date,
            first_due_date=first_due,
            loan_status="active",
            status=status,
            created_by=created_by,
            remarks=data.remarks,
        )
        # Build the flat, no-interest EMI schedule: one row per month.
        for i in range(data.tenure_months):
            loan.emis.append(
                LoanEmi(
                    module_id=module_id,
                    sequence_number=i + 1,
                    due_date=_add_months(data.loan_date, i + 1),
                    amount=data.emi_amount,
                    status=InstallmentStatus.pending,
                )
            )
        LoanDAO.add(db, loan)

        if actor_role != "super_admin":
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.loan,
                entity_id=loan.id,
                title="New loan needs approval",
                message="A loan created by an admin awaits verification.",
            )
        db.commit()
        return LoanDAO.get(db, loan.id)

    @staticmethod
    def _created_at_utc(loan: Loan) -> datetime:
        """loan.created_at as an aware UTC datetime (the column is naive)."""
        c = loan.created_at
        return c.replace(tzinfo=timezone.utc) if c.tzinfo is None else c

    @staticmethod
    def is_editable(loan: Loan, now: datetime | None = None) -> bool:
        """True while the loan is still within its post-booking edit window."""
        now = now or datetime.now(timezone.utc)
        return now - LoanService._created_at_utc(loan) <= EDIT_WINDOW

    @staticmethod
    def edit(
        db: Session, loan_id: int, data: LoanEdit, *, actor_role: str, actor_id: int
    ) -> Loan:
        """Replace a loan's details within the 5-hour grace window and REBUILD its
        EMI schedule from scratch. Any EMIs/payments already recorded are wiped —
        the client shows a warning first. Rejected once the window has passed."""
        loan = LoanService.get(db, loan_id)
        if not LoanService.is_editable(loan):
            raise HTTPException(
                status_code=403,
                detail="This loan can no longer be edited (the 5-hour window has passed).",
            )
        if loan.loan_status == "seized" or loan.seize_stage in ("pending", "seized"):
            raise HTTPException(
                status_code=400, detail="A seized loan cannot be edited."
            )
        if data.tenure_months <= 0:
            raise HTTPException(status_code=400, detail="Tenure must be at least 1 month")

        # Wipe the old schedule + every recorded payment (cascades to documents).
        loan.payments.clear()
        loan.emis.clear()
        db.flush()

        # Apply the new details.
        loan.customer_id = data.customer_id
        loan.vehicle_id = data.vehicle_id
        loan.principal = data.principal
        loan.emi_amount = data.emi_amount
        loan.tenure_months = data.tenure_months
        loan.loan_date = data.loan_date
        loan.first_due_date = _add_months(data.loan_date, 1)
        loan.remarks = data.remarks
        loan.loan_status = "active"
        loan.closed_at = None
        loan.updated_at = datetime.now(timezone.utc)

        # Rebuild the flat, no-interest EMI schedule.
        for i in range(data.tenure_months):
            loan.emis.append(
                LoanEmi(
                    module_id=loan.module_id,
                    sequence_number=i + 1,
                    due_date=_add_months(data.loan_date, i + 1),
                    amount=data.emi_amount,
                    status=InstallmentStatus.pending,
                )
            )
        db.commit()
        return LoanDAO.get(db, loan.id)

    @staticmethod
    def confirm(db: Session, loan_id: int, by_user_id: int) -> Loan:
        loan = LoanService.get(db, loan_id)
        loan.status = EntityStatus.active
        loan.confirmed_by = by_user_id
        loan.confirmed_at = datetime.now(timezone.utc)
        loan.rejection_reason = None
        db.commit()
        return LoanDAO.get(db, loan_id)

    @staticmethod
    def reject(db: Session, loan_id: int, reason: str, by_user_id: int) -> Loan:
        loan = LoanService.get(db, loan_id)
        loan.status = EntityStatus.rejected
        loan.loan_status = "rejected"
        loan.confirmed_by = by_user_id
        loan.confirmed_at = datetime.now(timezone.utc)
        loan.rejection_reason = reason
        db.commit()
        return LoanDAO.get(db, loan_id)

    @staticmethod
    def delete(db: Session, loan_id: int) -> None:
        loan = LoanService.get(db, loan_id)
        db.delete(loan)
        db.commit()

    # ── seizure (repossession) ───────────────────────────────────────────────
    @staticmethod
    def request_seize(
        db: Session, loan_id: int, reason: str, *, actor_role: str, actor_id: int
    ) -> Loan:
        loan = LoanService.get(db, loan_id)
        if loan.loan_status in ("closed", "seized"):
            raise HTTPException(status_code=400, detail="Loan already closed or seized")
        loan.seize_reason = reason
        loan.seized_by = actor_id
        loan.seized_at = datetime.now(timezone.utc)
        if actor_role == "super_admin":
            # Super admin seizes at once.
            loan.seize_stage = "seized"
            loan.seize_confirmed_by = actor_id
            loan.seize_confirmed_at = datetime.now(timezone.utc)
            loan.loan_status = "seized"
        else:
            loan.seize_stage = "pending"
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.loan,
                entity_id=loan.id,
                title="Loan seize needs approval",
                message=f"An admin requested to seize a loan vehicle. Reason: {reason}",
            )
        db.commit()
        return LoanDAO.get(db, loan_id)

    @staticmethod
    def confirm_seize(db: Session, loan_id: int, by_user_id: int) -> Loan:
        loan = LoanService.get(db, loan_id)
        loan.seize_stage = "seized"
        loan.seize_confirmed_by = by_user_id
        loan.seize_confirmed_at = datetime.now(timezone.utc)
        loan.loan_status = "seized"
        db.commit()
        return LoanDAO.get(db, loan_id)

    @staticmethod
    def cancel_seize(
        db: Session, loan_id: int, remarks: str | None, by_user_id: int
    ) -> Loan:
        loan = LoanService.get(db, loan_id)
        loan.seize_stage = None
        loan.seize_cancel_remarks = remarks
        loan.seize_confirmed_by = by_user_id
        loan.seize_confirmed_at = datetime.now(timezone.utc)
        # Vehicle goes back to the customer — the loan continues.
        LoanService._recompute_status(loan, date.today())
        db.commit()
        return LoanDAO.get(db, loan_id)

    # ── payments ────────────────────────────────────────────────────────────────
    @staticmethod
    def record_payment(
        db: Session,
        loan_id: int,
        emi_id: int,
        *,
        amount: Decimal,
        penalty: Decimal,
        received_date: date | None,
        remarks: str | None,
        recorded_by: int,
    ) -> LoanPayment:
        loan = LoanService.get(db, loan_id)
        emi = LoanDAO.get_emi(db, emi_id)
        if emi is None or emi.loan_id != loan.id:
            raise HTTPException(status_code=404, detail="EMI not found")

        received = received_date or date.today()
        emi.penalty = penalty or Decimal(0)
        total_due = Decimal(emi.amount) + Decimal(emi.penalty)
        new_paid = Decimal(emi.amount_paid) + Decimal(amount or 0)
        emi.amount_paid = min(new_paid, total_due)
        emi.received_date = received
        if remarks:
            emi.remarks = remarks

        if Decimal(emi.amount_paid) >= total_due:
            emi.status = InstallmentStatus.paid
            emi.paid_date = received
        elif emi.due_date < received:
            emi.status = InstallmentStatus.overdue
        else:
            emi.status = InstallmentStatus.pending

        payment = LoanPayment(
            loan_id=loan.id,
            emi_id=emi.id,
            amount=amount or 0,
            penalty=penalty or 0,
            received_date=received,
            remarks=remarks,
            recorded_by=recorded_by,
        )
        LoanDAO.add_payment(db, payment)

        LoanService._recompute_status(loan, received)
        db.commit()
        db.refresh(payment)
        return payment

    @staticmethod
    def _recompute_status(loan: Loan, today: date) -> None:
        if all(e.status == InstallmentStatus.paid for e in loan.emis):
            loan.loan_status = "closed"
            loan.closed_at = datetime.now(timezone.utc)
        elif any(
            e.status != InstallmentStatus.paid and e.due_date < today for e in loan.emis
        ):
            loan.loan_status = "overdue"
        else:
            loan.loan_status = "active"

    @staticmethod
    def add_payment_document(
        db: Session,
        payment_id: int,
        file_name: str,
        mime_type: str,
        content: bytes,
        uploaded_by: int | None,
    ) -> LoanPaymentDocument:
        doc = LoanPaymentDocument(
            payment_id=payment_id,
            file_name=file_name,
            mime_type=mime_type or "application/octet-stream",
            size_bytes=len(content),
            content=content,
            uploaded_by=uploaded_by,
        )
        db.add(doc)
        db.commit()
        db.refresh(doc)
        return doc

    @staticmethod
    def get_payment_document(db: Session, doc_id: int) -> LoanPaymentDocument:
        doc = LoanDAO.get_payment_document(db, doc_id)
        if doc is None:
            raise HTTPException(status_code=404, detail="Document not found")
        return doc

    @staticmethod
    def delete_payment_document(db: Session, doc_id: int) -> None:
        doc = LoanService.get_payment_document(db, doc_id)
        db.delete(doc)
        db.commit()
