"""Split vehicles.rc_permit into two columns: rc + permit.

Revision ID: 0008
Revises: 0007
"""
import sqlalchemy as sa
from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "vehicles",
        sa.Column("rc", sa.Boolean, nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "vehicles",
        sa.Column("permit", sa.Boolean, nullable=False, server_default=sa.false()),
    )
    # carry the old combined flag over into both new columns
    op.execute("UPDATE vehicles SET rc = rc_permit, permit = rc_permit")
    op.drop_column("vehicles", "rc_permit")


def downgrade() -> None:
    op.add_column(
        "vehicles",
        sa.Column(
            "rc_permit", sa.Boolean, nullable=False, server_default=sa.false()
        ),
    )
    op.execute("UPDATE vehicles SET rc_permit = (rc OR permit)")
    op.drop_column("vehicles", "permit")
    op.drop_column("vehicles", "rc")
