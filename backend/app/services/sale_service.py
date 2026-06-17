"""Business logic for sales: create + installment schedule + payments + payoff.

Role-gate mirrors vehicles/customers: super_admin → active immediately, admin →
pending_confirmation. On an admin-created sale a verification notification is
raised for the super admins.
"""
from __future__ import annotations

import calendar
from datetime import date, datetime, timezone

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
from app.models.sale_installment import SaleInstallment
from app.models.sale_payment import SalePayment
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

        is_down = data.deposit_type == DepositType.down_payment
        amount_received = data.amount_received if is_down else data.sale_price
        remaining = round(float(data.sale_price) - float(amount_received), 2) if is_down else 0.0
        if remaining < 0:
            raise HTTPException(status_code=400, detail="Advance cannot exceed the sale price")
        if is_down and (not data.monthly_amount or not data.installment_count or not data.first_due_date):
            raise HTTPException(
                status_code=400,
                detail="Down payment needs monthly_amount, installment_count and first_due_date",
            )

        sale = Sale(
            module_id=module_id,
            vehicle_id=data.vehicle_id,
            customer_id=data.customer_id,
            deposit_type=data.deposit_type,
            sale_price=data.sale_price,
            sale_date=data.sale_date,
            amount_received=amount_received,
            remaining_amount=remaining,
            monthly_amount=data.monthly_amount if is_down else None,
            installment_count=data.installment_count if is_down else None,
            first_due_date=data.first_due_date if is_down else None,
            customer_whatsapp=data.customer_whatsapp,
            sale_status=SaleLifecycle.active,
            status=data.status or initial_status(actor_role),
            created_by=created_by,
        )
        SaleDAO.add(db, sale)  # flush → sale.id
        sale.invoice_no = f"INV-AUTO-{sale.id:04d}"

        if is_down:
            for n in range(1, data.installment_count + 1):
                db.add(
                    SaleInstallment(
                        sale_id=sale.id,
                        module_id=module_id,
                        month_number=n,
                        due_date=_add_months(data.first_due_date, n - 1),
                        amount=data.monthly_amount,
                        status=InstallmentStatus.pending,
                    )
                )

        # mark the vehicle sold + assigned
        vehicle = db.get(Vehicle, data.vehicle_id)
        if vehicle is not None:
            vehicle.sale_status = SaleStatus.sold
            vehicle.assigned_to_customer_id = data.customer_id

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

    @staticmethod
    def cancel(db: Session, sale_id: int, reason: str, by_user_id: int) -> "Sale":
        sale = SaleService.get(db, sale_id)
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
    def delete(db: Session, sale_id: int) -> None:
        sale = SaleService.get(db, sale_id)
        SaleDAO.delete(db, sale)
        db.commit()

    @staticmethod
    def reminders_for_sale(db: Session, sale_id: int):
        SaleService.get(db, sale_id)  # 404 guard
        return SaleDAO.reminders_for_sale(db, sale_id)
