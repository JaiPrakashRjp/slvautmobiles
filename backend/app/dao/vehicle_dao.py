"""Data Access Object for vehicles — pure persistence, no business rules."""
from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.models.module import Module
from app.models.vehicle import Vehicle
from app.models.vehicle_document import VehicleDocument


class VehicleDAO:
    @staticmethod
    def module_id_by_code(db: Session, code: str) -> int | None:
        return db.scalar(select(Module.id).where(Module.code == code))

    @staticmethod
    def list(
        db: Session,
        *,
        status=None,
        branch=None,
        sale_status=None,
        q: str | None = None,
        limit: int | None = None,
        offset: int | None = None,
    ) -> list[Vehicle]:
        stmt = select(Vehicle).options(selectinload(Vehicle.documents))
        if status is not None:
            stmt = stmt.where(Vehicle.status == status)
        if branch is not None:
            stmt = stmt.where(Vehicle.branch == branch)
        if sale_status is not None:
            stmt = stmt.where(Vehicle.sale_status == sale_status)
        if q:
            like = f"%{q.strip()}%"
            stmt = stmt.where(
                or_(
                    Vehicle.reg_no.ilike(like),
                    Vehicle.chassis_no.ilike(like),
                    Vehicle.model.ilike(like),
                )
            )
        stmt = stmt.order_by(Vehicle.created_at.desc())
        if offset:
            stmt = stmt.offset(offset)
        if limit:
            stmt = stmt.limit(limit)
        return list(db.scalars(stmt).all())

    @staticmethod
    def get(db: Session, vehicle_id: int) -> Vehicle | None:
        stmt = (
            select(Vehicle)
            .options(selectinload(Vehicle.documents))
            .where(Vehicle.id == vehicle_id)
        )
        return db.scalar(stmt)

    @staticmethod
    def add(db: Session, vehicle: Vehicle) -> Vehicle:
        db.add(vehicle)
        db.flush()
        return vehicle

    @staticmethod
    def update(db: Session, vehicle: Vehicle, fields: dict) -> Vehicle:
        for key, value in fields.items():
            setattr(vehicle, key, value)
        db.flush()
        return vehicle

    @staticmethod
    def delete(db: Session, vehicle: Vehicle) -> None:
        db.delete(vehicle)

    @staticmethod
    def document_by_type(db: Session, vehicle_id: int, doc_type) -> VehicleDocument | None:
        return db.scalar(
            select(VehicleDocument).where(
                VehicleDocument.vehicle_id == vehicle_id,
                VehicleDocument.doc_type == doc_type,
            )
        )

    @staticmethod
    def add_document(db: Session, doc: VehicleDocument) -> VehicleDocument:
        db.add(doc)
        db.flush()
        return doc

    @staticmethod
    def get_document(db: Session, doc_id: int) -> VehicleDocument | None:
        return db.get(VehicleDocument, doc_id)

    @staticmethod
    def delete_document(db: Session, doc: VehicleDocument) -> None:
        db.delete(doc)
