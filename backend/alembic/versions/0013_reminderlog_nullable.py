"""Allow reminder_logs.sale_id / due_date to be null (standalone/test sends).

Revision ID: 0013
Revises: 0012
"""
import sqlalchemy as sa
from alembic import op

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("reminder_logs", "sale_id", existing_type=sa.BigInteger, nullable=True)
    op.alter_column("reminder_logs", "due_date", existing_type=sa.Date, nullable=True)


def downgrade() -> None:
    op.alter_column("reminder_logs", "sale_id", existing_type=sa.BigInteger, nullable=False)
    op.alter_column("reminder_logs", "due_date", existing_type=sa.Date, nullable=False)
