"""Unsell approval: an admin's unsell is held pending until a super admin approves.

Adds:
  - unsell_stage: NULL | 'pending' (admin requested, awaiting super admin).
  - unsell_requested_by: the admin who requested it (for display).

Revision ID: 0020
Revises: 0019
"""
import sqlalchemy as sa
from alembic import op

revision = "0020"
down_revision = "0019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("sales", sa.Column("unsell_stage", sa.Text(), nullable=True))
    op.add_column(
        "sales", sa.Column("unsell_requested_by", sa.BigInteger(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("sales", "unsell_requested_by")
    op.drop_column("sales", "unsell_stage")
