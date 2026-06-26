"""Add remarks TEXT column to vehicles, customers, and sales tables.

Revision ID: 0005
Revises: 0004
"""
from __future__ import annotations

from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("vehicles", sa.Column("remarks", sa.Text, nullable=True))
    op.add_column("customers", sa.Column("remarks", sa.Text, nullable=True))
    op.add_column("sales", sa.Column("remarks", sa.Text, nullable=True))


def downgrade() -> None:
    op.drop_column("vehicles", "remarks")
    op.drop_column("customers", "remarks")
    op.drop_column("sales", "remarks")
