"""Add loan-module assurity document types to the kyc_doc_type enum.

The loan customer captures a richer assurity (guarantor) document set than the
single ID proof used by Auto Sale: Aadhaar, PAN, two free "Other" slots and a
photo. These are new values on the EXISTING kyc_doc_type enum — no new table;
the same customer_documents table stores them (tagged module = loan).

Revision ID: 0027
Revises: 0026
"""
from __future__ import annotations

from typing import Union

from alembic import op

revision: str = "0027"
down_revision: Union[str, None] = "0026"
branch_labels = None
depends_on = None

_NEW_VALUES = (
    "assurity_aadhaar",
    "assurity_pan",
    "assurity_photo",
    "assurity_other_1",
    "assurity_other_2",
)


def upgrade() -> None:
    # ALTER TYPE ... ADD VALUE cannot run inside a transaction block on older
    # PostgreSQL, so step outside Alembic's transaction for these statements.
    # IF NOT EXISTS keeps the migration idempotent / re-runnable.
    with op.get_context().autocommit_block():
        for value in _NEW_VALUES:
            op.execute(f"ALTER TYPE kyc_doc_type ADD VALUE IF NOT EXISTS '{value}'")


def downgrade() -> None:
    # PostgreSQL cannot drop a value from an enum type without rebuilding it.
    # These additive values are harmless to leave in place, so downgrade is a
    # no-op (matches how enum extensions are handled elsewhere).
    pass
