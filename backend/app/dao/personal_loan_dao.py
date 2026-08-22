"""Data Access Object for personal loans + their financer master."""
from __future__ import annotations

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.models.personal_loan import PersonalLoan
from app.models.personal_loan_emi import PersonalLoanEmi
from app.models.personal_loan_financer import PersonalLoanFinancer
from app.models.reminder_log import ReminderLog


class PersonalLoanDAO:
    # ── financers ────────────────────────────────────────────────────────────
    @staticmethod
    def financers(db: Session) -> list[PersonalLoanFinancer]:
        return list(
            db.scalars(
                select(PersonalLoanFinancer).order_by(PersonalLoanFinancer.name)
            ).all()
        )

    @staticmethod
    def financer(db: Session, financer_id: int) -> PersonalLoanFinancer | None:
        return db.get(PersonalLoanFinancer, financer_id)

    @staticmethod
    def add_financer(db: Session, financer: PersonalLoanFinancer) -> PersonalLoanFinancer:
        db.add(financer)
        db.flush()
        return financer

    @staticmethod
    def delete_financer(db: Session, financer: PersonalLoanFinancer) -> None:
        db.delete(financer)

    # ── loans ────────────────────────────────────────────────────────────────
    @staticmethod
    def _with_relations(stmt):
        return stmt.options(selectinload(PersonalLoan.emis))

    @staticmethod
    def loans(db: Session) -> list[PersonalLoan]:
        stmt = PersonalLoanDAO._with_relations(select(PersonalLoan)).order_by(
            PersonalLoan.created_at.desc()
        )
        return list(db.scalars(stmt).all())

    @staticmethod
    def get(db: Session, loan_id: int) -> PersonalLoan | None:
        stmt = PersonalLoanDAO._with_relations(select(PersonalLoan)).where(
            PersonalLoan.id == loan_id
        )
        return db.scalar(stmt)

    @staticmethod
    def add(db: Session, loan: PersonalLoan) -> PersonalLoan:
        db.add(loan)
        db.flush()
        return loan

    @staticmethod
    def get_emi(db: Session, emi_id: int) -> PersonalLoanEmi | None:
        return db.get(PersonalLoanEmi, emi_id)

    # ── reminders ────────────────────────────────────────────────────────────
    @staticmethod
    def active_loans_with_unpaid(db: Session) -> list[PersonalLoan]:
        from app.models.enums import InstallmentStatus

        stmt = (
            PersonalLoanDAO._with_relations(select(PersonalLoan))
            .where(PersonalLoan.loan_status == "active")
            .where(PersonalLoan.emis.any(PersonalLoanEmi.status != InstallmentStatus.paid))
        )
        return list(db.scalars(stmt).all())

    @staticmethod
    def find_reminder_on_date(
        db: Session, *, personal_loan_emi_id: int, recipient_phone: str, on_date: date
    ) -> ReminderLog | None:
        return db.scalar(
            select(ReminderLog).where(
                ReminderLog.personal_loan_emi_id == personal_loan_emi_id,
                ReminderLog.recipient_phone == recipient_phone,
                func.date(ReminderLog.created_at) == on_date,
            )
        )

    @staticmethod
    def add_reminder(db: Session, log: ReminderLog) -> ReminderLog:
        db.add(log)
        db.flush()
        return log
