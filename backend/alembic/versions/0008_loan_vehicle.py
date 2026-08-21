"""Loan-module vehicle support: vehicles.fc flag + vehicle photo doc type.

The loan vehicle carries Insurance / FC / Permit "available" toggles. `insurance`
and `permit` already exist as boolean flags on vehicles; this adds the matching
`fc` flag. It also adds a `photo` value to the vehicle_doc_type enum so a photo of
the vehicle can be stored (same vehicle_documents table, tagged module = loan).

Revision ID: 0008
Revises: 0007
"""
from __future__ import annotations

from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "vehicles",
        sa.Column("fc", sa.Boolean, nullable=False, server_default="false"),
    )
    # ALTER TYPE ... ADD VALUE cannot run inside a transaction block on older
    # PostgreSQL, so step outside Alembic's transaction. IF NOT EXISTS keeps it
    # idempotent / re-runnable.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE vehicle_doc_type ADD VALUE IF NOT EXISTS 'photo'")


def downgrade() -> None:
    op.drop_column("vehicles", "fc")
    # PostgreSQL cannot drop an enum value without rebuilding the type; the extra
    # 'photo' value is harmless to leave in place.
