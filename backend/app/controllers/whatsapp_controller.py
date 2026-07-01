"""WhatsApp test endpoint — verify the Meta token/number before the full pipeline.

Sends the default pre-approved `hello_world` template to a test recipient
(which must be registered in the Meta dashboard while using a test number).
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.enums import ReminderChannel, ReminderRecipient, ReminderStatus
from app.models.reminder_log import ReminderLog
from app.models.user import User
from app.security import get_current_user
from app.services.whatsapp_service import WhatsAppService

router = APIRouter(prefix="/whatsapp", tags=["whatsapp"])


class TestSend(BaseModel):
    to: str  # recipient number, e.g. 919876543210 (country code, no +)
    template: str = "hello_world"
    lang: str = "en_US"


@router.post("/test")
def test_send(
    payload: TestSend,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ok, message_id, error = WhatsAppService.send_template(
        payload.to, payload.template, lang=payload.lang
    )
    # Log every attempt (sent + failed) to reminder_logs — auditable in the DB.
    db.add(
        ReminderLog(
            sale_id=None,
            installment_id=None,
            recipient_type=ReminderRecipient.customer,
            recipient_phone=payload.to,
            channel=ReminderChannel.whatsapp,
            message=f"[test] template={payload.template}",
            due_date=None,
            sent_at=datetime.now(timezone.utc) if ok else None,
            status=ReminderStatus.sent if ok else ReminderStatus.failed,
            provider_message_id=message_id,
            error=error,
        )
    )
    db.commit()
    return {"ok": ok, "message_id": message_id, "error": error}
