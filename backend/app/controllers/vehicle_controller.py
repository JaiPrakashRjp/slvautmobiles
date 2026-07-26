"""FastAPI router for the vehicles module (controller layer).

The acting user (id + role) comes from the Bearer token via get_current_user,
never from client-supplied params — so the role-gate can't be spoofed. Approval
actions (confirm/reject) require the Super Admin.
"""
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import Branch, EntityStatus, SaleStatus, VehicleDocType
from app.models.user import User
from app.schemas.vehicle import DocumentOut, VehicleCreate, VehicleOut, VehicleUpdate
from app.security import get_current_user, require_super_admin
from app.services.vehicle_service import VehicleService

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


@router.get("", response_model=list[VehicleOut])
def list_vehicles(
    db: Session = Depends(get_db),
    status: EntityStatus | None = None,
    branch: Branch | None = None,
    sale_status: SaleStatus | None = None,
    module: str | None = Query(None, description="module code (auto_sale / rental)"),
    q: str | None = Query(None, description="search reg no / chassis / model"),
    limit: int | None = Query(None, ge=1, le=200),
    offset: int | None = Query(None, ge=0),
):
    return VehicleService.list(
        db,
        status=status,
        branch=branch,
        sale_status=sale_status,
        module=module,
        q=q,
        limit=limit,
        offset=offset,
    )


@router.get("/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(vehicle_id: int, db: Session = Depends(get_db)):
    return VehicleService.get(db, vehicle_id)


@router.post("", response_model=VehicleOut, status_code=201)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return VehicleService.create(
        db, payload, actor_role=current_user.role.name, created_by=current_user.id
    )


@router.patch("/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(
    vehicle_id: int,
    payload: VehicleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return VehicleService.update(db, vehicle_id, payload)


@router.post("/{vehicle_id}/confirm", response_model=VehicleOut)
def confirm_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return VehicleService.confirm(db, vehicle_id, current_user.id)


@router.post("/{vehicle_id}/reject", response_model=VehicleOut)
def reject_vehicle(
    vehicle_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return VehicleService.reject(db, vehicle_id, reason, current_user.id)


@router.delete("/{vehicle_id}", status_code=204)
def delete_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    VehicleService.delete(db, vehicle_id)
    return Response(status_code=204)


# ── Documents ────────────────────────────────────────────────────────────────
@router.post("/{vehicle_id}/documents", response_model=DocumentOut, status_code=201)
async def upload_document(
    vehicle_id: int,
    doc_type: VehicleDocType = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
        headers={
            "Content-Disposition": f'inline; filename="{doc.file_name}"',
            # A document's bytes never change, so let clients cache it forever
            # instead of re-downloading the blob on every view.
            "Cache-Control": "public, max-age=31536000, immutable",
        },
    )


@router.delete("/documents/{doc_id}", status_code=204)
def delete_document(
    doc_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    VehicleService.delete_document(db, doc_id)
    return Response(status_code=204)
