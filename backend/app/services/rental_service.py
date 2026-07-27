"""Business logic for rentals: create + rent-collection reminders + payments +
completion + seize + edit approval. Mirrors SaleService.

Role-gate: super_admin → active immediately; admin → pending_confirmation with a
verification notification to the super admins.
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.rental_dao import RentalDAO
from app.models.enums import (
    EntityStatus,
    InstallmentStatus,
    InventoryStatus,
    NotificationEntity,
    PaymentKind,
    RentalLifecycle,
)
from app.models.rental import Rental
from app.models.rental_installment import RentalInstallment
from app.models.rental_payment import RentalPayment
from app.models.rental_payment_document import RentalPaymentDocument
from app.models.vehicle import Vehicle
from app.schemas.rental import RentalCreate, RentalEdit
from app.services.notification_service import NotificationService


def initial_status(actor_role: str) -> EntityStatus:
    return (
        EntityStatus.active
        if actor_role == "super_admin"
        else EntityStatus.pending_confirmation
    )


class RentalService:
    # ── Reads ────────────────────────────────────────────────────────────────
    @staticmethod
    def list(db: Session, *, status=None, customer_id=None, vehicle_id=None, module=None):
        return RentalDAO.list(
            db, status=status, customer_id=customer_id, vehicle_id=vehicle_id,
            module=module,
        )

    @staticmethod
    def get(db: Session, rental_id: int) -> Rental:
        rental = RentalDAO.get(db, rental_id)
        if rental is None:
            raise HTTPException(status_code=404, detail="Rental not found")
        return rental

    # ── Vehicle assignment helpers ───────────────────────────────────────────
    @staticmethod
    def _assign_vehicle(db: Session, rental: Rental) -> None:
        vehicle = db.get(Vehicle, rental.vehicle_id)
        if vehicle is not None:
            vehicle.assigned_to_customer_id = rental.customer_id
            vehicle.inventory_status = InventoryStatus.on_rent
            vehicle.is_seized = False

    @staticmethod
    def _release_vehicle(db: Session, rental: Rental, *, seized: bool = False) -> None:
        vehicle = db.get(Vehicle, rental.vehicle_id)
        if vehicle is not None:
            vehicle.assigned_to_customer_id = None
            vehicle.inventory_status = InventoryStatus.available
            vehicle.is_seized = seized

    # ── Create ───────────────────────────────────────────────────────────────
    @staticmethod
    def create(db: Session, data: RentalCreate, *, actor_role: str, created_by: int) -> Rental:
        module_id = RentalDAO.module_id_by_code(db, data.module_code)
        if module_id is None:
            raise HTTPException(status_code=400, detail=f"Unknown module '{data.module_code}'")

        # A vehicle may only have ONE live rental at a time.
        existing = [
            r
            for r in RentalDAO.list(db, vehicle_id=data.vehicle_id)
            if r.status in (EntityStatus.active, EntityStatus.pending_confirmation)
            and r.rental_status not in (RentalLifecycle.cancelled, RentalLifecycle.seized)
        ]
        if existing:
            raise HTTPException(
                status_code=409, detail="This vehicle already has an active rental."
            )

        total = round(float(data.total_amount), 2)
        if total <= 0:
            raise HTTPException(status_code=400, detail="Total amount must be greater than 0")
        advance = round(float(data.advance_amount), 2)
        if advance < 0 or advance > total:
            raise HTTPException(
                status_code=400, detail="Advance cannot exceed the total amount"
            )
        remaining = round(total - advance, 2)

        rental = Rental(
            module_id=module_id,
            vehicle_id=data.vehicle_id,
            customer_id=data.customer_id,
            total_amount=total,
            advance_amount=advance,
            remaining_amount=remaining,
            start_date=data.start_date,
            remarks=data.remarks,
            rental_status=RentalLifecycle.active,
            status=data.status or initial_status(actor_role),
            created_by=created_by,
        )
        RentalDAO.add(db, rental)  # flush → id
        rental.invoice_no = f"RENT-{rental.id:04d}"

        # Assign the vehicle only when the rental is active (super admin). An
        # admin's rental is pending, so the vehicle waits until approval.
        if rental.status == EntityStatus.active:
            RentalService._assign_vehicle(db, rental)

        if actor_role != "super_admin":
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.rental,
                entity_id=rental.id,
                title="New rental needs approval",
                message=f"Rental {rental.invoice_no} created by an admin awaits verification.",
            )
        db.commit()
        return RentalService.get(db, rental.id)

    # ── Approval (create) ────────────────────────────────────────────────────
    @staticmethod
    def confirm(db: Session, rental_id: int, by_user_id: int) -> Rental:
        rental = RentalService.get(db, rental_id)
        rental.status = EntityStatus.active
        rental.confirmed_by = by_user_id
        rental.confirmed_at = datetime.now(timezone.utc)
        rental.rejection_reason = None
        if rental.rental_status == RentalLifecycle.active:
            RentalService._assign_vehicle(db, rental)
        db.commit()
        return RentalService.get(db, rental_id)

    @staticmethod
    def reject(db: Session, rental_id: int, reason: str, by_user_id: int) -> Rental:
        rental = RentalService.get(db, rental_id)
        rental.status = EntityStatus.rejected
        rental.confirmed_by = by_user_id
        rental.confirmed_at = datetime.now(timezone.utc)
        rental.rejection_reason = reason
        RentalService._release_vehicle(db, rental)
        db.commit()
        return RentalService.get(db, rental_id)

    # ── Edit (super admin immediate; admin pending) ──────────────────────────
    @staticmethod
    def _editable(rental: Rental) -> None:
        if rental.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Only an approved rental can be edited.")
        if rental.rental_status not in (RentalLifecycle.active, RentalLifecycle.completed):
            raise HTTPException(status_code=400, detail="This rental can no longer be edited.")

    @staticmethod
    def _edit_payload(data: RentalEdit) -> dict:
        return {
            "total_amount": float(data.total_amount),
            "advance_amount": float(data.advance_amount),
            "start_date": data.start_date.isoformat() if data.start_date else None,
            "remarks": data.remarks,
        }

    @staticmethod
    def _validate_edit(payload: dict) -> tuple[float, float]:
        total = round(float(payload["total_amount"]), 2)
        if total <= 0:
            raise HTTPException(status_code=400, detail="Total amount must be greater than 0")
        advance = round(float(payload["advance_amount"]), 2)
        if advance < 0 or advance > total:
            raise HTTPException(status_code=400, detail="Advance cannot exceed the total amount")
        return total, advance

    @staticmethod
    def _apply_edit(db: Session, rental: Rental, payload: dict) -> None:
        total, advance = RentalService._validate_edit(payload)
        collected = round(
            sum(float(p.amount) for p in rental.payments if p.status == EntityStatus.active),
            2,
        )
        remaining = max(0.0, round(total - advance - collected, 2))
        rental.total_amount = total
        rental.advance_amount = advance
        rental.remaining_amount = remaining
        if payload.get("start_date"):
            rental.start_date = date.fromisoformat(payload["start_date"])
        rental.remarks = payload.get("remarks")
        if remaining <= 0:
            rental.rental_status = RentalLifecycle.completed
        elif rental.rental_status == RentalLifecycle.completed:
            rental.rental_status = RentalLifecycle.active

    @staticmethod
    def edit(db: Session, rental_id: int, data: RentalEdit, *, actor_role: str, by_user_id: int) -> Rental:
        rental = RentalService.get(db, rental_id)
        RentalService._editable(rental)
        payload = RentalService._edit_payload(data)
        RentalService._validate_edit(payload)
        if actor_role == "super_admin":
            RentalService._apply_edit(db, rental, payload)
            rental.pending_edit = None
            rental.edit_stage = None
            rental.edit_requested_by = None
        else:
            rental.pending_edit = payload
            rental.edit_stage = "pending"
            rental.edit_requested_by = by_user_id
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.rental,
                entity_id=rental.id,
                title="Rental edit needs approval",
                message=f"Edit of {rental.invoice_no} by an admin awaits verification.",
            )
        db.commit()
        return RentalService.get(db, rental_id)

    @staticmethod
    def approve_edit(db: Session, rental_id: int, *, by_user_id: int) -> Rental:
        rental = RentalService.get(db, rental_id)
        if rental.edit_stage != "pending" or not rental.pending_edit:
            raise HTTPException(status_code=400, detail="No pending edit to approve.")
        RentalService._apply_edit(db, rental, rental.pending_edit)
        rental.pending_edit = None
        rental.edit_stage = None
        rental.edit_requested_by = None
        db.commit()
        return RentalService.get(db, rental_id)

    @staticmethod
    def reject_edit(db: Session, rental_id: int, reason: str, *, by_user_id: int) -> Rental:
        rental = RentalService.get(db, rental_id)
        if rental.edit_stage != "pending":
            raise HTTPException(status_code=400, detail="No pending edit to reject.")
        rental.pending_edit = None
        rental.edit_stage = None
        rental.edit_requested_by = None
        db.commit()
        return RentalService.get(db, rental_id)

    # ── Completion ───────────────────────────────────────────────────────────
    @staticmethod
    def complete(db: Session, rental_id: int, *, by_user_id: int) -> Rental:
        """Confirm a fully-collected rental as complete. Only when balance is 0.
        Frees the vehicle back to the available pool; the rental stays as history."""
        rental = RentalService.get(db, rental_id)
        if float(rental.remaining_amount) > 0:
            raise HTTPException(status_code=400, detail="Rent still has an outstanding balance.")
        rental.rental_status = RentalLifecycle.completed
        rental.completed_at = datetime.now(timezone.utc)
        RentalService._release_vehicle(db, rental)
        db.commit()
        return RentalService.get(db, rental_id)

    # ── Seize (repossession) ─────────────────────────────────────────────────
    @staticmethod
    def _apply_seize(db: Session, rental: Rental) -> None:
        rental.rental_status = RentalLifecycle.seized
        rental.seize_stage = "seized"
        RentalService._release_vehicle(db, rental, seized=True)

    @staticmethod
    def seize(db: Session, rental_id: int, reason: str, by_user_id: int, actor_role: str) -> Rental:
        rental = RentalService.get(db, rental_id)
        if rental.rental_status != RentalLifecycle.active:
            raise HTTPException(status_code=400, detail="Only an active rental can be seized.")
        rental.seized_at = datetime.now(timezone.utc)
        rental.seized_by = by_user_id
        rental.seize_reason = reason
        if actor_role == "super_admin":
            RentalService._apply_seize(db, rental)
        else:
            rental.seize_stage = "pending"
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.rental,
                entity_id=rental.id,
                title="Rental seize needs approval",
                message=f"Seize of {rental.invoice_no} by an admin awaits verification. Reason: {reason}",
            )
        db.commit()
        return RentalService.get(db, rental_id)

    @staticmethod
    def approve_seize(db: Session, rental_id: int, *, by_user_id: int) -> Rental:
        rental = RentalService.get(db, rental_id)
        if rental.seize_stage != "pending":
            raise HTTPException(status_code=400, detail="No pending seize to approve.")
        RentalService._apply_seize(db, rental)
        db.commit()
        return RentalService.get(db, rental_id)

    @staticmethod
    def reject_seize(db: Session, rental_id: int, reason: str, *, by_user_id: int) -> Rental:
        rental = RentalService.get(db, rental_id)
        if rental.seize_stage != "pending":
            raise HTTPException(status_code=400, detail="No pending seize to reject.")
        rental.seize_stage = None
        rental.seized_at = None
        rental.seized_by = None
        rental.seize_reason = None
        db.commit()
        return RentalService.get(db, rental_id)

    # ── Reminders / collections ──────────────────────────────────────────────
    @staticmethod
    def add_reminder(db: Session, rental_id: int, *, due_date, amount, created_by) -> Rental:
        rental = RentalService.get(db, rental_id)
        if rental.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Rental is not active")
        if float(amount) <= 0:
            raise HTTPException(status_code=400, detail="Amount must be greater than 0")
        next_number = max((i.number for i in rental.installments), default=0) + 1
        db.add(
            RentalInstallment(
                rental_id=rental.id,
                module_id=rental.module_id,
                number=next_number,
                due_date=due_date,
                amount=amount,
                status=InstallmentStatus.pending,
                created_by=created_by,
            )
        )
        db.commit()
        return RentalService.get(db, rental_id)

    @staticmethod
    def take_call(db: Session, installment_id: int, *, user_id: int) -> Rental:
        inst = RentalDAO.get_installment(db, installment_id)
        if inst is None:
            raise HTTPException(status_code=404, detail="Reminder not found")
        if inst.status == InstallmentStatus.paid:
            raise HTTPException(status_code=400, detail="Already paid")
        if inst.due_date > date.today():
            raise HTTPException(status_code=400, detail="Reminder is not due yet")
        if (
            inst.status == InstallmentStatus.in_progress
            and inst.taken_by is not None
            and inst.taken_by != user_id
        ):
            raise HTTPException(status_code=409, detail="Another admin is handling this call")
        inst.status = InstallmentStatus.in_progress
        inst.taken_by = user_id
        inst.taken_at = datetime.now(timezone.utc)
        db.commit()
        return RentalService.get(db, inst.rental_id)

    @staticmethod
    def cancel_reminder(db: Session, installment_id: int, reason: str, *, user_id: int) -> Rental:
        inst = RentalDAO.get_installment(db, installment_id)
        if inst is None:
            raise HTTPException(status_code=404, detail="Reminder not found")
        if inst.status == InstallmentStatus.paid:
            raise HTTPException(status_code=400, detail="Already paid")
        inst.status = InstallmentStatus.cancelled
        inst.cancel_reason = reason
        db.commit()
        return RentalService.get(db, inst.rental_id)

    # ── Payments ─────────────────────────────────────────────────────────────
    @staticmethod
    def _reduce_balance(rental: Rental, amount) -> None:
        rental.remaining_amount = round(float(rental.remaining_amount) - float(amount), 2)
        if rental.remaining_amount <= 0:
            rental.remaining_amount = 0

    @staticmethod
    def _apply_paid(inst: RentalInstallment, rental: Rental, amount, paid_on=None) -> None:
        inst.status = InstallmentStatus.paid
        inst.paid_date = paid_on or date.today()
        RentalService._reduce_balance(rental, amount)

    @staticmethod
    def _attach_screenshot(db, payment, screenshot, recorded_by) -> None:
        if screenshot is not None:
            db.add(
                RentalPaymentDocument(
                    payment_id=payment.id,
                    file_name=screenshot["file_name"],
                    mime_type=screenshot["mime_type"],
                    size_bytes=screenshot.get("size_bytes"),
                    content=screenshot["content"],
                    uploaded_by=recorded_by,
                )
            )

    @staticmethod
    def submit_payment(db, installment_id, *, amount, actor_role, recorded_by, paid_on=None, screenshot=None) -> Rental:
        inst = RentalDAO.get_installment(db, installment_id)
        if inst is None:
            raise HTTPException(status_code=404, detail="Reminder not found")
        rental = RentalService.get(db, inst.rental_id)
        if rental.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Rental is not active")
        if inst.status == InstallmentStatus.paid:
            raise HTTPException(status_code=400, detail="Already paid")

        is_super = actor_role == "super_admin"
        payment = RentalPayment(
            rental_id=rental.id,
            installment_id=inst.id,
            amount=amount,
            kind=PaymentKind.installment,
            recorded_by=recorded_by,
            status=EntityStatus.active if is_super else EntityStatus.pending_confirmation,
        )
        if paid_on is not None:
            payment.paid_at = datetime(paid_on.year, paid_on.month, paid_on.day)
        if is_super:
            payment.confirmed_by = recorded_by
            payment.confirmed_at = datetime.now(timezone.utc)
        RentalDAO.add_payment(db, payment)  # flush → id
        RentalService._attach_screenshot(db, payment, screenshot, recorded_by)

        if is_super:
            RentalService._apply_paid(inst, rental, amount, paid_on=paid_on)
        else:
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.rental,
                entity_id=rental.id,
                title="Rent payment needs approval",
                message=f"A ₹{float(amount):,.0f} payment for {rental.invoice_no} awaits verification.",
            )
        db.commit()
        return RentalService.get(db, inst.rental_id)

    @staticmethod
    def submit_manual_payment(db, rental_id, *, amount, actor_role, recorded_by, paid_on=None, screenshot=None) -> Rental:
        rental = RentalService.get(db, rental_id)
        if rental.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Rental is not active")

        is_super = actor_role == "super_admin"
        payment = RentalPayment(
            rental_id=rental.id,
            installment_id=None,
            amount=amount,
            kind=PaymentKind.advance,
            recorded_by=recorded_by,
            status=EntityStatus.active if is_super else EntityStatus.pending_confirmation,
        )
        if paid_on is not None:
            payment.paid_at = datetime(paid_on.year, paid_on.month, paid_on.day)
        if is_super:
            payment.confirmed_by = recorded_by
            payment.confirmed_at = datetime.now(timezone.utc)
        RentalDAO.add_payment(db, payment)
        RentalService._attach_screenshot(db, payment, screenshot, recorded_by)

        if is_super:
            RentalService._reduce_balance(rental, amount)
        else:
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.rental,
                entity_id=rental.id,
                title="Manual rent payment needs approval",
                message=f"A ₹{float(amount):,.0f} manual payment for {rental.invoice_no} awaits verification.",
            )
        db.commit()
        return RentalService.get(db, rental_id)

    @staticmethod
    def approve_payment(db, payment_id, *, by_user_id) -> Rental:
        payment = db.get(RentalPayment, payment_id)
        if payment is None:
            raise HTTPException(status_code=404, detail="Payment not found")
        if payment.status != EntityStatus.active:
            payment.status = EntityStatus.active
            payment.confirmed_by = by_user_id
            payment.confirmed_at = datetime.now(timezone.utc)
            payment.rejection_reason = None
            rental = RentalService.get(db, payment.rental_id)
            inst = (
                RentalDAO.get_installment(db, payment.installment_id)
                if payment.installment_id
                else None
            )
            if inst is not None and inst.status != InstallmentStatus.paid:
                RentalService._apply_paid(
                    inst, rental, payment.amount,
                    paid_on=payment.paid_at.date() if payment.paid_at else None,
                )
            elif payment.installment_id is None:
                RentalService._reduce_balance(rental, payment.amount)
            db.commit()
        return RentalService.get(db, payment.rental_id)

    @staticmethod
    def decline_payment(db, payment_id, reason, *, by_user_id) -> Rental:
        payment = db.get(RentalPayment, payment_id)
        if payment is None:
            raise HTTPException(status_code=404, detail="Payment not found")
        payment.status = EntityStatus.rejected
        payment.confirmed_by = by_user_id
        payment.confirmed_at = datetime.now(timezone.utc)
        payment.rejection_reason = reason
        inst = (
            RentalDAO.get_installment(db, payment.installment_id)
            if payment.installment_id
            else None
        )
        if inst is not None and inst.status != InstallmentStatus.paid:
            inst.status = InstallmentStatus.pending
            inst.taken_by = None
            inst.taken_at = None
        db.commit()
        return RentalService.get(db, payment.rental_id)

    @staticmethod
    def payment_document(db, doc_id) -> RentalPaymentDocument:
        doc = db.get(RentalPaymentDocument, doc_id)
        if doc is None:
            raise HTTPException(status_code=404, detail="Screenshot not found")
        return doc

    @staticmethod
    def delete(db: Session, rental_id: int) -> None:
        rental = RentalService.get(db, rental_id)
        RentalService._release_vehicle(db, rental)
        RentalDAO.delete(db, rental)
        db.commit()
