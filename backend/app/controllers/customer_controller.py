"""FastAPI router for the customers module (controller layer)."""
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import Branch, EntityStatus, KycDocType
from app.schemas.customer import (
    CustomerCreate,
    CustomerOut,
    CustomerUpdate,
    DocumentOut,
)
from app.services.customer_service import CustomerService

router = APIRouter(prefix="/customers", tags=["customers"])


@router.get("", response_model=list[CustomerOut])
def list_customers(
    db: Session = Depends(get_db),
    status: EntityStatus | None = None,
    branch: Branch | None = None,
):
    return CustomerService.list(db, status=status, branch=branch)


@router.get("/{customer_id}", response_model=CustomerOut)
def get_customer(customer_id: int, db: Session = Depends(get_db)):
    return CustomerService.get(db, customer_id)


@router.post("", response_model=CustomerOut, status_code=201)
def create_customer(
    payload: CustomerCreate,
    created_by: int = Query(..., description="id of the user creating this"),
    actor_role: str = Query("admin", description="super_admin | admin"),
    db: Session = Depends(get_db),
):
    return CustomerService.create(db, payload, actor_role=actor_role, created_by=created_by)


@router.patch("/{customer_id}", response_model=CustomerOut)
def update_customer(
    customer_id: int,
    payload: CustomerUpdate,
    db: Session = Depends(get_db),
):
    return CustomerService.update(db, customer_id, payload)


@router.post("/{customer_id}/confirm", response_model=CustomerOut)
def confirm_customer(
    customer_id: int,
    by_user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return CustomerService.confirm(db, customer_id, by_user_id)


@router.post("/{customer_id}/reject", response_model=CustomerOut)
def reject_customer(
    customer_id: int,
    reason: str = Query(..., min_length=1),
    by_user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return CustomerService.reject(db, customer_id, reason, by_user_id)


@router.delete("/{customer_id}", status_code=204)
def delete_customer(customer_id: int, db: Session = Depends(get_db)):
    CustomerService.delete(db, customer_id)
    return Response(status_code=204)


# ── Documents ────────────────────────────────────────────────────────────────
@router.post("/{customer_id}/documents", response_model=DocumentOut, status_code=201)
async def upload_document(
    customer_id: int,
    doc_type: KycDocType = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
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
        headers={"Content-Disposition": f'inline; filename="{doc.file_name}"'},
    )


@router.delete("/documents/{doc_id}", status_code=204)
def delete_document(doc_id: int, db: Session = Depends(get_db)):
    CustomerService.delete_document(db, doc_id)
    return Response(status_code=204)
