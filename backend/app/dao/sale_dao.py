"""Data Access Object for sales / installments / payments / reminder logs."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.module import Module
from app.models.reminder_log import ReminderLog
from app.models.sale import Sale
from app.models.sale_installment import SaleInstallment
from app.models.sale_payment import SalePayment
from app.models.sale_payment_document import SalePaymentDocument  # noqa: F401


class SaleDAO:
    @staticmethod
    def module_id_by_code(db: Session, code: str) -> int | None:
        return db.scalar(select(Module.id).where(Module.code == code))

    @staticmethod
    def _with_relations(stmt):
        return stmt.options(
            selectinload(Sale.installments),
            selectinload(Sale.payments).selectinload(SalePayment.documents),
            selectinload(Sale.financer),
        )

    @staticmethod
    def list(db: Session, *, status=None, customer_id=None, vehicle_id=None) -> list[Sale]:
        stmt = SaleDAO._with_relations(select(Sale))
        if status is not None:
            stmt = stmt.where(Sale.status == status)
        if customer_id is not None:
            stmt = stmt.where(Sale.customer_id == customer_id)
        if vehicle_id is not None:
            stmt = stmt.where(Sale.vehicle_id == vehicle_id)
        return list(db.scalars(stmt.order_by(Sale.created_at.desc())).all())

    @staticmethod
    def get(db: Session, sale_id: int) -> Sale | None:
        return db.scalar(SaleDAO._with_relations(select(Sale)).where(Sale.id == sale_id))

    @staticmethod
    def add(db: Session, sale: Sale) -> Sale:
        db.add(sale)
        db.flush()
        return sale

    @staticmethod
    def delete(db: Session, sale: Sale) -> None:
        db.delete(sale)

    @staticmethod
    def get_installment(db: Session, installment_id: int) -> SaleInstallment | None:
        return db.get(SaleInstallment, installment_id)

    @staticmethod
    def add_payment(db: Session, payment: SalePayment) -> SalePayment:
        db.add(payment)
        db.flush()
        return payment

    # ── reminders ──────────────────────────────────────────────────────────────
    @staticmethod
    def active_sales_with_unpaid(db: Session) -> list[Sale]:
        from app.models.enums import InstallmentStatus, SaleLifecycle

        stmt = (
            SaleDAO._with_relations(select(Sale))
            .where(Sale.sale_status == SaleLifecycle.active)
            .where(
                Sale.installments.any(SaleInstallment.status != InstallmentStatus.paid)
            )
        )
        return list(db.scalars(stmt).all())

    @staticmethod
    def reminders_for_sale(db: Session, sale_id: int) -> list[ReminderLog]:
        stmt = (
            select(ReminderLog)
            .where(ReminderLog.sale_id == sale_id)
            .order_by(ReminderLog.created_at.desc())
        )
        return list(db.scalars(stmt).all())

    @staticmethod
    def find_reminder(
        db: Session, *, installment_id, recipient_type, due_date, recipient_phone
    ) -> ReminderLog | None:
        return db.scalar(
            select(ReminderLog).where(
                ReminderLog.installment_id == installment_id,
                ReminderLog.recipient_type == recipient_type,
                ReminderLog.due_date == due_date,
                ReminderLog.recipient_phone == recipient_phone,
            )
        )

    @staticmethod
    def add_reminder(db: Session, log: ReminderLog) -> ReminderLog:
        db.add(log)
        db.flush()
        return log
