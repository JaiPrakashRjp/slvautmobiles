"""Data Access Object for loans — persistence only, no business rules."""
from __future__ import annotations

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.models.loan import Loan
from app.models.loan_emi import LoanEmi
from app.models.loan_payment import LoanPayment
from app.models.loan_payment_document import LoanPaymentDocument
from app.models.module import Module
from app.models.reminder_log import ReminderLog


class LoanDAO:
    @staticmethod
    def module_id_by_code(db: Session, code: str) -> int | None:
        return db.scalar(select(Module.id).where(Module.code == code))

    @staticmethod
    def _with_relations(stmt):
        return stmt.options(
            selectinload(Loan.emis),
            selectinload(Loan.payments).selectinload(LoanPayment.documents),
        )

    @staticmethod
    def list(
        db: Session,
        *,
        module: str | None = None,
        status=None,
        customer_id: int | None = None,
    ) -> list[Loan]:
        stmt = LoanDAO._with_relations(select(Loan))
        if module is not None:
            stmt = stmt.where(
                Loan.module_id
                == select(Module.id).where(Module.code == module).scalar_subquery()
            )
        if status is not None:
            stmt = stmt.where(Loan.status == status)
        if customer_id is not None:
            stmt = stmt.where(Loan.customer_id == customer_id)
        stmt = stmt.order_by(Loan.created_at.desc())
        return list(db.scalars(stmt).all())

    @staticmethod
    def get(db: Session, loan_id: int) -> Loan | None:
        stmt = LoanDAO._with_relations(select(Loan)).where(Loan.id == loan_id)
        return db.scalar(stmt)

    @staticmethod
    def add(db: Session, loan: Loan) -> Loan:
        db.add(loan)
        db.flush()
        return loan

    @staticmethod
    def get_emi(db: Session, emi_id: int) -> LoanEmi | None:
        return db.get(LoanEmi, emi_id)

    @staticmethod
    def add_payment(db: Session, payment: LoanPayment) -> LoanPayment:
        db.add(payment)
        db.flush()
        return payment

    @staticmethod
    def get_payment_document(db: Session, doc_id: int) -> LoanPaymentDocument | None:
        return db.get(LoanPaymentDocument, doc_id)

    # ── reminders ───────────────────────────────────────────────────────────────
    @staticmethod
    def active_loans_with_unpaid(db: Session) -> list[Loan]:
        from app.models.enums import InstallmentStatus

        stmt = (
            LoanDAO._with_relations(select(Loan))
            .where(Loan.loan_status.in_(["active", "overdue"]))
            .where(Loan.emis.any(LoanEmi.status != InstallmentStatus.paid))
        )
        return list(db.scalars(stmt).all())

    @staticmethod
    def find_reminder_on_date(
        db: Session, *, emi_id: int, recipient_phone: str, on_date: date
    ) -> ReminderLog | None:
        return db.scalar(
            select(ReminderLog).where(
                ReminderLog.emi_id == emi_id,
                ReminderLog.recipient_phone == recipient_phone,
                func.date(ReminderLog.created_at) == on_date,
            )
        )

    @staticmethod
    def add_reminder(db: Session, log: ReminderLog) -> ReminderLog:
        db.add(log)
        db.flush()
        return log
