"""Add vehicles.insurance boolean flag (alongside rc + permit).

Revision ID: 0009
Revises: 0008
"""
import sqlalchemy as sa
from alembic import op

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "vehicles",
        sa.Column(
            "insurance", sa.Boolean, nullable=False, server_default=sa.false()
        ),
    )


def downgrade() -> None:
    op.drop_column("vehicles", "insurance")
