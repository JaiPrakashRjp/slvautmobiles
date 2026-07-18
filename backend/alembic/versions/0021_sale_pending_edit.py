"""Sale edit approval: an admin's edit is held pending until a super admin approves.

A super admin's edit applies immediately; an admin's edit is stashed in
`pending_edit` (the live sale keeps its current values) and a verification
notification goes to the super admins to approve or reject.

Adds:
  - pending_edit: JSONB — the proposed field values, applied on approval.
  - edit_stage: NULL | 'pending' (admin requested, awaiting super admin).
  - edit_requested_by: the admin who requested the edit (for display).

Revision ID: 0021
Revises: 0020
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0021"
down_revision = "0020"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "sales", sa.Column("pending_edit", postgresql.JSONB(), nullable=True)
    )
    op.add_column("sales", sa.Column("edit_stage", sa.Text(), nullable=True))
    op.add_column(
        "sales", sa.Column("edit_requested_by", sa.BigInteger(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("sales", "edit_requested_by")
    op.drop_column("sales", "edit_stage")
    op.drop_column("sales", "pending_edit")
