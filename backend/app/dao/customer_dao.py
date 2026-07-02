"""Data Access Object for customers — pure persistence, no business rules."""
from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.models.customer import Customer
from app.models.customer_document import CustomerDocument
from app.models.module import Module


class CustomerDAO:
    @staticmethod
    def module_id_by_code(db: Session, code: str) -> int | None:
        return db.scalar(select(Module.id).where(Module.code == code))

    @staticmethod
    def list(
        db: Session,
        *,
        status=None,
        branch=None,
        q: str | None = None,
        limit: int | None = None,
        offset: int | None = None,
    ) -> list[Customer]:
        stmt = select(Customer).options(selectinload(Customer.documents))
        if status is not None:
            stmt = stmt.where(Customer.status == status)
        if branch is not None:
            stmt = stmt.where(Customer.branch == branch)
        if q:
            like = f"%{q.strip()}%"
            stmt = stmt.where(
                or_(
                    Customer.first_name.ilike(like),
                    Customer.last_name.ilike(like),
                    Customer.phone.ilike(like),
                )
            )
        stmt = stmt.order_by(Customer.created_at.desc())
        if offset:
            stmt = stmt.offset(offset)
        if limit:
            stmt = stmt.limit(limit)
        return list(db.scalars(stmt).all())

    @staticmethod
    def get(db: Session, customer_id: int) -> Customer | None:
        stmt = (
            select(Customer)
            .options(selectinload(Customer.documents))
            .where(Customer.id == customer_id)
        )
        return db.scalar(stmt)

    @staticmethod
    def add(db: Session, customer: Customer) -> Customer:
        db.add(customer)
        db.flush()
        return customer

    @staticmethod
    def update(db: Session, customer: Customer, fields: dict) -> Customer:
        for key, value in fields.items():
            setattr(customer, key, value)
        db.flush()
        return customer

    @staticmethod
    def delete(db: Session, customer: Customer) -> None:
        db.delete(customer)

    @staticmethod
    def document_by_type(db: Session, customer_id: int, doc_type) -> CustomerDocument | None:
        return db.scalar(
            select(CustomerDocument).where(
                CustomerDocument.customer_id == customer_id,
                CustomerDocument.doc_type == doc_type,
            )
        )

    @staticmethod
    def get_document(db: Session, doc_id: int) -> CustomerDocument | None:
        return db.get(CustomerDocument, doc_id)

    @staticmethod
    def delete_document(db: Session, doc: CustomerDocument) -> None:
        db.delete(doc)
