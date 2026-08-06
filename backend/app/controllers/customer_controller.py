"""FastAPI router for the customers module (controller layer).

Acting user (id + role) comes from the Bearer token, not client params;
approvals require the Super Admin.
"""
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import Branch, EntityStatus, KycDocType
from app.models.user import User
from app.schemas.customer import (
    CustomerCreate,
    CustomerOut,
    CustomerUpdate,
    DocumentOut,
)
from app.security import get_current_user, require_super_admin
from app.services.customer_service import CustomerService

router = APIRouter(prefix="/customers", tags=["customers"])


@router.get("", response_model=list[CustomerOut])
def list_customers(
    db: Session = Depends(get_db),
    status: EntityStatus | None = None,
    branch: Branch | None = None,
    module: str | None = Query(None, description="module code (auto_sale / rental)"),
    q: str | None = Query(None, description="search name / phone"),
    limit: int | None = Query(None, ge=1, le=200),
    offset: int | None = Query(None, ge=0),
):
    return CustomerService.list(
        db, status=status, branch=branch, module=module, q=q,
        limit=limit, offset=offset,
    )


@router.get("/{customer_id}", response_model=CustomerOut)
def get_customer(customer_id: int, db: Session = Depends(get_db)):
    return CustomerService.get(db, customer_id)


@router.post("", response_model=CustomerOut, status_code=201)
def create_customer(
    payload: CustomerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return CustomerService.create(
        db, payload, actor_role=current_user.role.name, created_by=current_user.id
    )


@router.patch("/{customer_id}", response_model=CustomerOut)
def update_customer(
    customer_id: int,
    payload: CustomerUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return CustomerService.update(db, customer_id, payload)


@router.post("/{customer_id}/confirm", response_model=CustomerOut)
def confirm_customer(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return CustomerService.confirm(db, customer_id, current_user.id)


@router.post("/{customer_id}/reject", response_model=CustomerOut)
def reject_customer(
    customer_id: int,
    reason: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_super_admin),
):
    return CustomerService.reject(db, customer_id, reason, current_user.id)


@router.delete("/{customer_id}", status_code=204)
def delete_customer(
    customer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    CustomerService.delete(db, customer_id)
    return Response(status_code=204)


# ── Documents ────────────────────────────────────────────────────────────────
@router.post("/{customer_id}/documents", response_model=DocumentOut, status_code=201)
async def upload_document(
    customer_id: int,
    doc_type: KycDocType = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    content = await file.read()
    return CustomerService.add_document(
        db, customer_id, doc_type, file.filename, file.content_type, content
    )


@router.get("/documents/{doc_id}")
def download_document(doc_id: int, db: Session = Depends(get_db)):
    doc = CustomerService.get_document(db, doc_id)
    return Response(
        content=doc.content,
        media_type=doc.mime_type,
        headers={
            "Content-Disposition": f'inline; filename="{doc.file_name}"',
            "Cache-Control": "public, max-age=31536000, immutable",
        },
    )


@router.delete("/documents/{doc_id}", status_code=204)
def delete_document(
    doc_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    CustomerService.delete_document(db, doc_id)
    return Response(status_code=204)
