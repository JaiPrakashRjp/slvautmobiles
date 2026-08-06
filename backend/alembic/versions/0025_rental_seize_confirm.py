"""Rental seize confirm/cancel stage (mirror the sale seize flow).

Adds the confirm/cancel metadata so a seized rental can be finalised (confirmed)
or reversed (cancelled → vehicle returns to the renter), matching auto-sale.

Revision ID: 0025
Revises: 0024
"""
import sqlalchemy as sa
from alembic import op

revision = "0025"
down_revision = "0024"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("rentals", sa.Column("seize_confirmed_at", sa.DateTime(), nullable=True))
    op.add_column("rentals", sa.Column("seize_confirmed_by", sa.BigInteger(), nullable=True))
    op.add_column("rentals", sa.Column("seize_confirm_remarks", sa.Text(), nullable=True))
    op.add_column("rentals", sa.Column("seize_cancel_remarks", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("rentals", "seize_cancel_remarks")
    op.drop_column("rentals", "seize_confirm_remarks")
    op.drop_column("rentals", "seize_confirmed_by")
    op.drop_column("rentals", "seize_confirmed_at")
