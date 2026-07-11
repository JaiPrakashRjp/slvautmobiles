"""Business logic for sales: create + installment schedule + payments + payoff.

Role-gate mirrors vehicles/customers: super_admin → active immediately, admin →
pending_confirmation. On an admin-created sale a verification notification is
raised for the super admins.
"""
from __future__ import annotations

import calendar
from datetime import date, datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.sale_dao import SaleDAO
from app.models.enums import (
    DepositType,
    EntityStatus,
    InstallmentStatus,
    NotificationEntity,
    PaymentKind,
    SaleLifecycle,
    SaleStatus,
)
from app.models.sale import Sale
from app.models.sale_financer import SaleFinancer
from app.models.sale_installment import SaleInstallment
from app.models.sale_payment import SalePayment
from app.models.sale_payment_document import SalePaymentDocument
from app.models.vehicle import Vehicle
from app.schemas.sale import SaleCreate
from app.services.notification_service import NotificationService


def initial_status(actor_role: str) -> EntityStatus:
    return (
        EntityStatus.active
        if actor_role == "super_admin"
        else EntityStatus.pending_confirmation
    )


def _add_months(d: date, months: int) -> date:
    """Add whole months to a date, clamping the day to the target month length."""
    month_index = d.month - 1 + months
    year = d.year + month_index // 12
    month = month_index % 12 + 1
    day = min(d.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


class SaleService:
    @staticmethod
    def list(db: Session, *, status=None, customer_id=None, vehicle_id=None) -> list[Sale]:
        return SaleDAO.list(db, status=status, customer_id=customer_id, vehicle_id=vehicle_id)

    @staticmethod
    def get(db: Session, sale_id: int) -> Sale:
        sale = SaleDAO.get(db, sale_id)
        if sale is None:
            raise HTTPException(status_code=404, detail="Sale not found")
        return sale

    @staticmethod
    def create(db: Session, data: SaleCreate, *, actor_role: str, created_by: int) -> Sale:
        module_id = SaleDAO.module_id_by_code(db, data.module_code)
        if module_id is None:
            raise HTTPException(status_code=400, detail=f"Unknown module '{data.module_code}'")

        # Total = sum of the price breakdown.
        total = round(
            float(data.vehicle_amount)
            + float(data.additional_fitting)
            + float(data.dl_charges)
            + float(data.document_charges)
            + float(data.other_expenses),
            2,
        )
        if total <= 0:
            raise HTTPException(
                status_code=400, detail="Total amount must be greater than 0"
            )

        down = round(float(data.amount_received), 2)
        if down < 0 or down > total:
            raise HTTPException(
                status_code=400, detail="Down payment cannot exceed the total amount"
            )

        # Full cash when the down payment covers the whole total; else down payment.
        is_full_cash = abs(down - total) < 0.01
        deposit_type = (
            DepositType.full_cash if is_full_cash else DepositType.down_payment
        )
        remaining = 0.0 if is_full_cash else round(float(data.remaining_amount), 2)
        # HP (loan) amount is honoured only when a super admin creates the sale.
        hp_amount = (
            float(data.hp_amount)
            if (data.hp_amount is not None and actor_role == "super_admin")
            else None
        )

        sale = Sale(
            module_id=module_id,
            vehicle_id=data.vehicle_id,
            customer_id=data.customer_id,
            deposit_type=deposit_type,
            sale_price=total,
            sale_date=data.sale_date,
            amount_received=down,
            remaining_amount=remaining,
            vehicle_amount=data.vehicle_amount,
            additional_fitting=data.additional_fitting,
            dl_charges=data.dl_charges,
            document_charges=data.document_charges,
            other_expenses=data.other_expenses,
            hp_amount=hp_amount,
            customer_whatsapp=data.customer_whatsapp,
            sale_status=SaleLifecycle.active,
            status=data.status or initial_status(actor_role),
            created_by=created_by,
        )
        SaleDAO.add(db, sale)  # flush → sale.id
        sale.invoice_no = f"INV-AUTO-{sale.id:04d}"

        # the sale's own financer (separate master from vehicle financers)
        if data.financer_id is not None:
            if db.get(SaleFinancer, data.financer_id) is None:
                raise HTTPException(status_code=400, detail="Unknown sale financer")
            sale.financer_id = data.financer_id

        # NOTE: installment schedule is intentionally not built here yet — the
        # monthly/EMI flow is being revisited alongside WhatsApp reminders.

        # mark the vehicle sold + assigned; clear any prior seizure flag (a
        # re-sold vehicle is no longer "seized" — the history stays on the old sale).
        vehicle = db.get(Vehicle, data.vehicle_id)
        if vehicle is not None:
            vehicle.sale_status = SaleStatus.sold
            vehicle.assigned_to_customer_id = data.customer_id
            vehicle.is_seized = False

        if actor_role != "super_admin":
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.sale,
                entity_id=sale.id,
                title="New sale needs approval",
                message=f"Sale {sale.invoice_no} created by an admin awaits verification.",
            )

        db.commit()
        return SaleService.get(db, sale.id)

    @staticmethod
    def _maybe_close(db: Session, sale: Sale) -> None:
        if all(i.status == InstallmentStatus.paid for i in sale.installments) and sale.installments:
            sale.sale_status = SaleLifecycle.closed
            sale.closed_at = datetime.now(timezone.utc)
            sale.remaining_amount = 0

    @staticmethod
    def mark_paid(db: Session, installment_id: int, *, recorded_by: int) -> Sale:
        inst = SaleDAO.get_installment(db, installment_id)
        if inst is None:
            raise HTTPException(status_code=404, detail="Installment not found")
        sale_check = SaleService.get(db, inst.sale_id)
        if sale_check.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Sale is not active — awaiting super admin approval")
        if inst.status != InstallmentStatus.paid:
            inst.status = InstallmentStatus.paid
            inst.paid_date = date.today()
            SaleDAO.add_payment(
                db,
                SalePayment(
                    sale_id=inst.sale_id,
                    installment_id=inst.id,
                    amount=inst.amount,
                    kind=PaymentKind.installment,
                    recorded_by=recorded_by,
                ),
            )
            sale = SaleService.get(db, inst.sale_id)
            sale.remaining_amount = round(
                float(sale.remaining_amount) - float(inst.amount), 2
            )
            SaleService._maybe_close(db, sale)
        db.commit()
        return SaleService.get(db, inst.sale_id)

    @staticmethod
    def pay_off(db: Session, sale_id: int, *, recorded_by: int) -> Sale:
        sale = SaleService.get(db, sale_id)
        if sale.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Sale is not active — awaiting super admin approval")
        unpaid = [i for i in sale.installments if i.status != InstallmentStatus.paid]
        total = round(sum(float(i.amount) for i in unpaid), 2)
        today = date.today()
        for i in unpaid:
            i.status = InstallmentStatus.paid
            i.paid_date = today
        if total > 0 or sale.sale_status != SaleLifecycle.closed:
            # append via the relationship so the already-loaded collection (and
            # thus the response) stays in sync, not just the DB.
            sale.payments.append(
                SalePayment(
                    sale_id=sale.id,
                    installment_id=None,
                    amount=total,
                    kind=PaymentKind.early_payoff,
                    recorded_by=recorded_by,
                )
            )
        sale.remaining_amount = 0
        sale.sale_status = SaleLifecycle.closed
        sale.closed_at = datetime.now(timezone.utc)
        db.commit()
        return SaleService.get(db, sale_id)

    @staticmethod
    def confirm(db: Session, sale_id: int, by_user_id: int) -> Sale:
        sale = SaleService.get(db, sale_id)
        sale.status = EntityStatus.active
        sale.confirmed_by = by_user_id
        sale.confirmed_at = datetime.now(timezone.utc)
        sale.rejection_reason = None
        db.commit()
        return SaleService.get(db, sale_id)

    @staticmethod
    def reject(db: Session, sale_id: int, reason: str, by_user_id: int) -> Sale:
        sale = SaleService.get(db, sale_id)
        sale.status = EntityStatus.rejected
        sale.confirmed_by = by_user_id
        sale.confirmed_at = datetime.now(timezone.utc)
        sale.rejection_reason = reason
        db.commit()
        return SaleService.get(db, sale_id)

    # A sale can only be reversed ("unsold") within this window of being created.
    UNSELL_WINDOW = timedelta(hours=2)

    @staticmethod
    def cancel(db: Session, sale_id: int, reason: str, by_user_id: int) -> "Sale":
        sale = SaleService.get(db, sale_id)
        # Enforce the 2-hour unsell window (applies to everyone, incl. super admin).
        # created_at is stored as naive UTC, so treat it as UTC when comparing.
        created = sale.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) - created > SaleService.UNSELL_WINDOW:
            raise HTTPException(
                status_code=403,
                detail="This sale can no longer be unsold — the 2-hour window has passed.",
            )
        sale.sale_status = SaleLifecycle.cancelled
        sale.unsell_reason = reason
        # Reset vehicle back to not-sold and unassign the customer.
        vehicle = db.get(Vehicle, sale.vehicle_id)
        if vehicle is not None:
            vehicle.sale_status = SaleStatus.not_sold
            vehicle.assigned_to_customer_id = None
        db.commit()
        return SaleService.get(db, sale_id)

    @staticmethod
    def seize(db: Session, sale_id: int, reason: str, by_user_id: int) -> "Sale":
        """Repossess the vehicle from a defaulting customer. Unlike unsell there
        is no time limit. The sale row is kept as history (status -> seized); the
        vehicle is freed (not_sold + is_seized flag) so it can be re-sold."""
        sale = SaleService.get(db, sale_id)
        if sale.sale_status != SaleLifecycle.active:
            raise HTTPException(
                status_code=400,
                detail="Only an active sale can be seized.",
            )
        sale.sale_status = SaleLifecycle.seized
        sale.seized_at = datetime.now(timezone.utc)
        sale.seized_by = by_user_id
        sale.seize_reason = reason
        # Free the vehicle for re-sale, but flag it as currently seized. The
        # seized sale row (with its customer + payments) remains the history.
        vehicle = db.get(Vehicle, sale.vehicle_id)
        if vehicle is not None:
            vehicle.sale_status = SaleStatus.not_sold
            vehicle.assigned_to_customer_id = None
            vehicle.is_seized = True
        db.commit()
        return SaleService.get(db, sale_id)

    @staticmethod
    def delete(db: Session, sale_id: int) -> None:
        sale = SaleService.get(db, sale_id)
        SaleDAO.delete(db, sale)
        db.commit()

    @staticmethod
    def reminders_for_sale(db: Session, sale_id: int):
        SaleService.get(db, sale_id)  # 404 guard
        return SaleDAO.reminders_for_sale(db, sale_id)

    # ── Reminders / collections flow ────────────────────────────────────────
    @staticmethod
    def add_reminder(db: Session, sale_id: int, *, due_date, amount, created_by) -> Sale:
        """Admin/super-admin schedules a collection reminder (date + amount)."""
        sale = SaleService.get(db, sale_id)
        if sale.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Sale is not active")
        if float(amount) <= 0:
            raise HTTPException(status_code=400, detail="Amount must be greater than 0")
        next_month = max((i.month_number for i in sale.installments), default=0) + 1
        db.add(
            SaleInstallment(
                sale_id=sale.id,
                module_id=sale.module_id,
                month_number=next_month,
                due_date=due_date,
                amount=amount,
                status=InstallmentStatus.pending,
                created_by=created_by,
            )
        )
        db.commit()
        return SaleService.get(db, sale_id)

    @staticmethod
    def take_call(db: Session, installment_id: int, *, user_id: int) -> Sale:
        """Claim a reminder to handle the call — locks it to this user."""
        inst = SaleDAO.get_installment(db, installment_id)
        if inst is None:
            raise HTTPException(status_code=404, detail="Reminder not found")
        if inst.status == InstallmentStatus.paid:
            raise HTTPException(status_code=400, detail="Already paid")
        # the call only opens on/after the reminder's due date
        if inst.due_date > date.today():
            raise HTTPException(
                status_code=400, detail="Reminder is not due yet"
            )
        if (
            inst.status == InstallmentStatus.in_progress
            and inst.taken_by is not None
            and inst.taken_by != user_id
        ):
            raise HTTPException(
                status_code=409, detail="Another admin is handling this call"
            )
        inst.status = InstallmentStatus.in_progress
        inst.taken_by = user_id
        inst.taken_at = datetime.now(timezone.utc)
        db.commit()
        return SaleService.get(db, inst.sale_id)

    @staticmethod
    def cancel_reminder(
        db: Session, installment_id: int, reason: str, *, user_id: int
    ) -> Sale:
        """Call made but no payment — defer. Balance stays the same."""
        inst = SaleDAO.get_installment(db, installment_id)
        if inst is None:
            raise HTTPException(status_code=404, detail="Reminder not found")
        if inst.status == InstallmentStatus.paid:
            raise HTTPException(status_code=400, detail="Already paid")
        inst.status = InstallmentStatus.cancelled
        inst.cancel_reason = reason
        db.commit()
        return SaleService.get(db, inst.sale_id)

    @staticmethod
    def _apply_paid(
        db: Session,
        inst: SaleInstallment,
        sale: Sale,
        amount,
        paid_on: date | None = None,
    ) -> None:
        inst.status = InstallmentStatus.paid
        inst.paid_date = paid_on or date.today()
        sale.remaining_amount = round(float(sale.remaining_amount) - float(amount), 2)
        if sale.remaining_amount <= 0:
            sale.remaining_amount = 0
            sale.sale_status = SaleLifecycle.closed
            sale.closed_at = datetime.now(timezone.utc)

    @staticmethod
    def submit_payment(
        db: Session,
        installment_id: int,
        *,
        amount,
        actor_role: str,
        recorded_by: int,
        paid_on: date | None = None,
        screenshot: dict | None = None,
    ) -> Sale:
        """Record an installment payment. Super-admin → applied immediately;
        admin → pending_confirmation (super admin approves/declines)."""
        inst = SaleDAO.get_installment(db, installment_id)
        if inst is None:
            raise HTTPException(status_code=404, detail="Reminder not found")
        sale = SaleService.get(db, inst.sale_id)
        if sale.status != EntityStatus.active:
            raise HTTPException(status_code=403, detail="Sale is not active")
        if inst.status == InstallmentStatus.paid:
            raise HTTPException(status_code=400, detail="Already paid")

        is_super = actor_role == "super_admin"
        payment = SalePayment(
            sale_id=sale.id,
            installment_id=inst.id,
            amount=amount,
            kind=PaymentKind.installment,
            recorded_by=recorded_by,
            status=EntityStatus.active if is_super else EntityStatus.pending_confirmation,
        )
        # The user-entered payment date (when it was actually paid) is stored on
        # the payment so it survives the pending→approval path; defaults to now.
        if paid_on is not None:
            payment.paid_at = datetime(paid_on.year, paid_on.month, paid_on.day)
        if is_super:
            payment.confirmed_by = recorded_by
            payment.confirmed_at = datetime.now(timezone.utc)
        SaleDAO.add_payment(db, payment)  # flush → payment.id

        if screenshot is not None:
            db.add(
                SalePaymentDocument(
                    payment_id=payment.id,
                    file_name=screenshot["file_name"],
                    mime_type=screenshot["mime_type"],
                    size_bytes=screenshot.get("size_bytes"),
                    content=screenshot["content"],
                    uploaded_by=recorded_by,
                )
            )

        if is_super:
            SaleService._apply_paid(db, inst, sale, amount, paid_on=paid_on)
        else:
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.sale,
                entity_id=sale.id,
                title="Installment payment needs approval",
                message=f"A ₹{float(amount):,.0f} payment for {sale.invoice_no} awaits verification.",
            )
        db.commit()
        return SaleService.get(db, inst.sale_id)

    @staticmethod
    def approve_payment(db: Session, payment_id: int, *, by_user_id: int) -> Sale:
        payment = db.get(SalePayment, payment_id)
        if payment is None:
            raise HTTPException(status_code=404, detail="Payment not found")
        if payment.status != EntityStatus.active:
            payment.status = EntityStatus.active
            payment.confirmed_by = by_user_id
            payment.confirmed_at = datetime.now(timezone.utc)
            payment.rejection_reason = None
            sale = SaleService.get(db, payment.sale_id)
            inst = (
                SaleDAO.get_installment(db, payment.installment_id)
                if payment.installment_id
                else None
            )
            if inst is not None and inst.status != InstallmentStatus.paid:
                SaleService._apply_paid(
                    db,
                    inst,
                    sale,
                    payment.amount,
                    paid_on=payment.paid_at.date() if payment.paid_at else None,
                )
            db.commit()
        return SaleService.get(db, payment.sale_id)

    @staticmethod
    def decline_payment(
        db: Session, payment_id: int, reason: str, *, by_user_id: int
    ) -> Sale:
        payment = db.get(SalePayment, payment_id)
        if payment is None:
            raise HTTPException(status_code=404, detail="Payment not found")
        payment.status = EntityStatus.rejected
        payment.confirmed_by = by_user_id
        payment.confirmed_at = datetime.now(timezone.utc)
        payment.rejection_reason = reason
        # Balance unchanged. Free the reminder up for a retry.
        inst = (
            SaleDAO.get_installment(db, payment.installment_id)
            if payment.installment_id
            else None
        )
        if inst is not None and inst.status != InstallmentStatus.paid:
            inst.status = InstallmentStatus.pending
            inst.taken_by = None
            inst.taken_at = None
        db.commit()
        return SaleService.get(db, payment.sale_id)

    @staticmethod
    def payment_document(db: Session, doc_id: int) -> SalePaymentDocument:
        doc = db.get(SalePaymentDocument, doc_id)
        if doc is None:
            raise HTTPException(status_code=404, detail="Screenshot not found")
        return doc
