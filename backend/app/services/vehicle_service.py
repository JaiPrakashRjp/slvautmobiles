"""Business logic for vehicles, including the role-gate rule.

Role-gate: a Super Admin's action takes effect immediately (status=active);
an Admin's action is held pending_confirmation until a Super Admin confirms or
rejects it. Mirrors the Flutter Gate helper.
"""
from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.vehicle_dao import VehicleDAO
from app.models.enums import EntityStatus, NotificationEntity
from app.models.vehicle import Vehicle
from app.models.vehicle_document import VehicleDocument
from app.schemas.vehicle import VehicleCreate, VehicleUpdate


def initial_status(actor_role: str) -> EntityStatus:
    return (
        EntityStatus.active
        if actor_role == "super_admin"
        else EntityStatus.pending_confirmation
    )


class VehicleService:
    @staticmethod
    def list(
        db: Session,
        *,
        status=None,
        branch=None,
        sale_status=None,
        q=None,
        limit=None,
        offset=None,
    ) -> list[Vehicle]:
        return VehicleDAO.list(
            db,
            status=status,
            branch=branch,
            sale_status=sale_status,
            q=q,
            limit=limit,
            offset=offset,
        )

    @staticmethod
    def get(db: Session, vehicle_id: int) -> Vehicle:
        vehicle = VehicleDAO.get(db, vehicle_id)
        if vehicle is None:
            raise HTTPException(status_code=404, detail="Vehicle not found")
        return vehicle

    @staticmethod
    def create(
        db: Session, data: VehicleCreate, *, actor_role: str, created_by: int
    ) -> Vehicle:
        module_id = VehicleDAO.module_id_by_code(db, data.module_code)
        if module_id is None:
            raise HTTPException(status_code=400, detail=f"Unknown module '{data.module_code}'")

        status = data.status or initial_status(actor_role)
        fields = data.model_dump(exclude={"module_code", "status"})
        vehicle = Vehicle(
            **fields,
            module_id=module_id,
            status=status,
            created_by=created_by,
        )
        VehicleDAO.add(db, vehicle)
        if actor_role != "super_admin":
            # local import avoids a circular import (notification_service → user_dao)
            from app.services.notification_service import NotificationService

            NotificationService.create_verification(
                db,
                entity_type=NotificationEntity.vehicle,
                entity_id=vehicle.id,
                title="New vehicle needs approval",
                message="Vehicle created by an admin awaits verification.",
            )
        db.commit()
        return VehicleDAO.get(db, vehicle.id)

    @staticmethod
    def update(db: Session, vehicle_id: int, data: VehicleUpdate) -> Vehicle:
        vehicle = VehicleService.get(db, vehicle_id)
        fields = data.model_dump(exclude_unset=True)
        VehicleDAO.update(db, vehicle, fields)
        db.commit()
        return VehicleDAO.get(db, vehicle_id)

    @staticmethod
    def confirm(db: Session, vehicle_id: int, by_user_id: int) -> Vehicle:
        vehicle = VehicleService.get(db, vehicle_id)
        vehicle.status = EntityStatus.active
        vehicle.confirmed_by = by_user_id
        vehicle.confirmed_at = datetime.now(timezone.utc)
        vehicle.rejection_reason = None
        db.commit()
        return VehicleDAO.get(db, vehicle_id)

    @staticmethod
    def reject(
        db: Session, vehicle_id: int, reason: str, by_user_id: int
    ) -> Vehicle:
        vehicle = VehicleService.get(db, vehicle_id)
        vehicle.status = EntityStatus.rejected
        vehicle.confirmed_by = by_user_id
        vehicle.confirmed_at = datetime.now(timezone.utc)
        vehicle.rejection_reason = reason
        db.commit()
        return VehicleDAO.get(db, vehicle_id)

    @staticmethod
    def delete(db: Session, vehicle_id: int) -> None:
        vehicle = VehicleService.get(db, vehicle_id)
        VehicleDAO.delete(db, vehicle)
        db.commit()

    @staticmethod
    def add_document(
        db: Session,
        vehicle_id: int,
        doc_type,
        file_name: str,
        mime_type: str,
        content: bytes,
    ) -> VehicleDocument:
        """Upsert by (vehicle_id, doc_type): replaces the file if one of that
        type already exists, else inserts a new one."""
        vehicle = VehicleService.get(db, vehicle_id)
        doc = VehicleDAO.document_by_type(db, vehicle.id, doc_type)
        if doc is None:
            doc = VehicleDocument(
                vehicle_id=vehicle.id,
                module_id=vehicle.module_id,
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
    def get_document(db: Session, doc_id: int) -> VehicleDocument:
        doc = VehicleDAO.get_document(db, doc_id)
        if doc is None:
            raise HTTPException(status_code=404, detail="Document not found")
        return doc

    @staticmethod
    def delete_document(db: Session, doc_id: int) -> None:
        doc = VehicleService.get_document(db, doc_id)
        VehicleDAO.delete_document(db, doc)
        db.commit()
