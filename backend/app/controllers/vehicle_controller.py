"""FastAPI router for the vehicles module (controller layer).

NOTE: auth isn't wired yet, so actor_role / created_by / by_user_id are passed
explicitly for now. They'll come from the authenticated user once the users
module + auth land.
"""
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import Branch, EntityStatus, VehicleDocType
from app.schemas.vehicle import DocumentOut, VehicleCreate, VehicleOut, VehicleUpdate
from app.services.vehicle_service import VehicleService

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


@router.get("", response_model=list[VehicleOut])
def list_vehicles(
    db: Session = Depends(get_db),
    status: EntityStatus | None = None,
    branch: Branch | None = None,
):
    return VehicleService.list(db, status=status, branch=branch)


@router.get("/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(vehicle_id: int, db: Session = Depends(get_db)):
    return VehicleService.get(db, vehicle_id)


@router.post("", response_model=VehicleOut, status_code=201)
def create_vehicle(
    payload: VehicleCreate,
    created_by: int = Query(..., description="id of the user creating this"),
    actor_role: str = Query("admin", description="super_admin | admin"),
    db: Session = Depends(get_db),
):
    return VehicleService.create(db, payload, actor_role=actor_role, created_by=created_by)


@router.patch("/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(
    vehicle_id: int,
    payload: VehicleUpdate,
    db: Session = Depends(get_db),
):
    return VehicleService.update(db, vehicle_id, payload)


@router.post("/{vehicle_id}/confirm", response_model=VehicleOut)
def confirm_vehicle(
    vehicle_id: int,
    by_user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return VehicleService.confirm(db, vehicle_id, by_user_id)


@router.post("/{vehicle_id}/reject", response_model=VehicleOut)
def reject_vehicle(
    vehicle_id: int,
    reason: str = Query(..., min_length=1),
    by_user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return VehicleService.reject(db, vehicle_id, reason, by_user_id)


@router.delete("/{vehicle_id}", status_code=204)
def delete_vehicle(vehicle_id: int, db: Session = Depends(get_db)):
    VehicleService.delete(db, vehicle_id)
    return Response(status_code=204)


# ── Documents ────────────────────────────────────────────────────────────────
@router.post("/{vehicle_id}/documents", response_model=DocumentOut, status_code=201)
async def upload_document(
    vehicle_id: int,
    doc_type: VehicleDocType = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    content = await file.read()
    return VehicleService.add_document(
        db, vehicle_id, doc_type, file.filename, file.content_type, content
    )


@router.get("/documents/{doc_id}")
def download_document(doc_id: int, db: Session = Depends(get_db)):
    doc = VehicleService.get_document(db, doc_id)
    return Response(
        content=doc.content,
        media_type=doc.mime_type,
        headers={"Content-Disposition": f'inline; filename="{doc.file_name}"'},
    )


@router.delete("/documents/{doc_id}", status_code=204)
def delete_document(doc_id: int, db: Session = Depends(get_db)):
    VehicleService.delete_document(db, doc_id)
    return Response(status_code=204)
