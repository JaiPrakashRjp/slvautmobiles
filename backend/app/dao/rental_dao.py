"""Data Access Object for rentals / rent installments / rent payments."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.module import Module
from app.models.rental import Rental
from app.models.rental_installment import RentalInstallment
from app.models.rental_payment import RentalPayment
from app.models.rental_payment_document import RentalPaymentDocument  # noqa: F401


class RentalDAO:
    @staticmethod
    def module_id_by_code(db: Session, code: str) -> int | None:
        return db.scalar(select(Module.id).where(Module.code == code))

    @staticmethod
    def _with_relations(stmt):
        return stmt.options(
            selectinload(Rental.installments),
            selectinload(Rental.payments).selectinload(RentalPayment.documents),
        )

    @staticmethod
    def list(
        db: Session, *, status=None, customer_id=None, vehicle_id=None, module=None
    ) -> list[Rental]:
        stmt = RentalDAO._with_relations(select(Rental))
        if module is not None:
            stmt = stmt.where(
                Rental.module_id
                == select(Module.id).where(Module.code == module).scalar_subquery()
            )
        if status is not None:
            stmt = stmt.where(Rental.status == status)
        if customer_id is not None:
            stmt = stmt.where(Rental.customer_id == customer_id)
        if vehicle_id is not None:
            stmt = stmt.where(Rental.vehicle_id == vehicle_id)
        return list(db.scalars(stmt.order_by(Rental.created_at.desc())).all())

    @staticmethod
    def get(db: Session, rental_id: int) -> Rental | None:
        return db.scalar(
            RentalDAO._with_relations(select(Rental)).where(Rental.id == rental_id)
        )

    @staticmethod
    def add(db: Session, rental: Rental) -> Rental:
        db.add(rental)
        db.flush()
        return rental

    @staticmethod
    def delete(db: Session, rental: Rental) -> None:
        db.delete(rental)

    @staticmethod
    def get_installment(db: Session, installment_id: int) -> RentalInstallment | None:
        return db.get(RentalInstallment, installment_id)

    @staticmethod
    def add_payment(db: Session, payment: RentalPayment) -> RentalPayment:
        db.add(payment)
        db.flush()
        return payment
