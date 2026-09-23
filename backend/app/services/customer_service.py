"""Business logic for customers — same role-gate rule as vehicles."""
from __future__ import annotations  # a `list` staticmethod below shadows builtin list otherwise

from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.customer_dao import CustomerDAO
from app.models.customer import Customer
from app.models.customer_document import CustomerDocument
from app.models.enums import EntityStatus, NotificationEntity
from app.schemas.customer import CustomerCreate, CustomerUpdate
from app.services.notification_service import NotificationService
from app.services.vehicle_service import initial_status


class CustomerService:
    @staticmethod
    def list(
        db: Session,
        *,
        status=None,
        branch=None,
        module=None,
        q=None,
        limit=None,
        offset=None,
        silo_ids: list[int] | None = None,
    ) -> list[Customer]:
        return CustomerDAO.list(
            db, status=status, branch=branch, module=module, q=q,
            limit=limit, offset=offset, created_by_in=silo_ids,
        )

    @staticmethod
    def get(db: Session, customer_id: int, silo_ids: list[int] | None = None) -> Customer:
        customer = CustomerDAO.get(db, customer_id)
        if customer is None:
            raise HTTPException(status_code=404, detail="Customer not found")
        if silo_ids is not None and customer.created_by not in silo_ids:
            raise HTTPException(status_code=404, detail="Customer not found")
        return customer

    @staticmethod
    def create(
        db: Session, data: CustomerCreate, *, actor_role: str, created_by: int
    ) -> Customer:
        module_id = CustomerDAO.module_id_by_code(db, data.module_code)
        if module_id is None:
            raise HTTPException(status_code=400, detail=f"Unknown module '{data.module_code}'")

        status = data.status or initial_status(actor_role)
        fields = data.model_dump(exclude={"module_code", "status"})
        customer = Customer(
            **fields,
            module_id=module_id,
            status=status,
            created_by=created_by,
        )
        CustomerDAO.add(db, customer)
        if actor_role != "super_admin":
            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.customer,
                entity_id=customer.id,
                creator_id=created_by,
                title="New customer needs approval",
                message=f"Customer '{customer.first_name}' created by an admin awaits verification.",
            )
        db.commit()
        return CustomerDAO.get(db, customer.id)

    @staticmethod
    def update(
        db: Session, customer_id: int, data: CustomerUpdate, silo_ids: list[int] | None = None
    ) -> Customer:
        customer = CustomerService.get(db, customer_id, silo_ids)
        fields = data.model_dump(exclude_unset=True)
        CustomerDAO.update(db, customer, fields)
        db.commit()
        return CustomerDAO.get(db, customer_id)

    @staticmethod
    def confirm(
        db: Session, customer_id: int, by_user_id: int, silo_ids: list[int] | None = None
    ) -> Customer:
        customer = CustomerService.get(db, customer_id, silo_ids)
        customer.status = EntityStatus.active
        customer.confirmed_by = by_user_id
        customer.confirmed_at = datetime.now(timezone.utc)
        customer.rejection_reason = None
        db.commit()
        return CustomerDAO.get(db, customer_id)

    @staticmethod
    def reject(
        db: Session, customer_id: int, reason: str, by_user_id: int, silo_ids: list[int] | None = None
    ) -> Customer:
        customer = CustomerService.get(db, customer_id, silo_ids)
        customer.status = EntityStatus.rejected
        customer.confirmed_by = by_user_id
        customer.confirmed_at = datetime.now(timezone.utc)
        customer.rejection_reason = reason
        db.commit()
        return CustomerDAO.get(db, customer_id)

    @staticmethod
    def delete(db: Session, customer_id: int, silo_ids: list[int] | None = None) -> None:
        customer = CustomerService.get(db, customer_id, silo_ids)
        CustomerDAO.delete(db, customer)
        db.commit()

    @staticmethod
    def add_document(
        db: Session,
        customer_id: int,
        doc_type,
        file_name: str,
        mime_type: str,
        content: bytes,
        silo_ids: list[int] | None = None,
    ) -> CustomerDocument:
        """Upsert by (customer_id, doc_type): replaces or inserts."""
        customer = CustomerService.get(db, customer_id, silo_ids)
        doc = CustomerDAO.document_by_type(db, customer.id, doc_type)
        if doc is None:
            doc = CustomerDocument(
                customer_id=customer.id,
                module_id=customer.module_id,
                doc_type=doc_type,
            )
            db.add(doc)
        doc.file_name = file_name
        doc.mime_type = mime_type or "application/octet-stream"
        doc.size_bytes = len(content)
        doc.content = content
        db.commit()
        db.refresh(doc)
        return doc

    @staticmethod
    def get_document(db: Session, doc_id: int, silo_ids: list[int] | None = None) -> CustomerDocument:
        doc = CustomerDAO.get_document(db, doc_id)
        if doc is None:
            raise HTTPException(status_code=404, detail="Document not found")
        if silo_ids is not None:
            CustomerService.get(db, doc.customer_id, silo_ids)  # 404s if out of silo
        return doc

    @staticmethod
    def delete_document(db: Session, doc_id: int, silo_ids: list[int] | None = None) -> None:
        doc = CustomerService.get_document(db, doc_id, silo_ids)
        CustomerDAO.delete_document(db, doc)
        db.commit()
