"""Rename showroom enum value aestece -> acetec (spelling fix).

Revision ID: 0015
Revises: 0014
"""
from alembic import op

revision = "0015"
down_revision = "0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # RENAME VALUE keeps existing vehicle rows valid (same value, new spelling).
    op.execute("ALTER TYPE showroom RENAME VALUE 'aestece' TO 'acetec'")


def downgrade() -> None:
    op.execute("ALTER TYPE showroom RENAME VALUE 'acetec' TO 'aestece'")
