"""Seize workflow: admin-approval + cancel/confirm stages with remarks.

Adds a seize lifecycle to the (already-existing) seizure fields:
  - seize_stage: NULL | 'pending' (admin requested, awaiting super-admin) |
    'seized' (active — badge shown, can cancel/confirm) | 'confirmed' (finalised).
  - confirm/cancel audit (who, when, remarks).

Revision ID: 0018
Revises: 0017
"""
import sqlalchemy as sa
from alembic import op

revision = "0018"
down_revision = "0017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("sales", sa.Column("seize_stage", sa.Text(), nullable=True))
    op.add_column("sales", sa.Column("seize_confirmed_at", sa.DateTime(), nullable=True))
    op.add_column("sales", sa.Column("seize_confirmed_by", sa.BigInteger(), nullable=True))
    op.add_column("sales", sa.Column("seize_confirm_remarks", sa.Text(), nullable=True))
    op.add_column("sales", sa.Column("seize_cancel_remarks", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("sales", "seize_cancel_remarks")
    op.drop_column("sales", "seize_confirm_remarks")
    op.drop_column("sales", "seize_confirmed_by")
    op.drop_column("sales", "seize_confirmed_at")
    op.drop_column("sales", "seize_stage")
