"""Rental old (carried-forward) balance — display-only reference + date.

Records a pre-existing balance the renter already owed when onboarding a
(usually backdated) rental. Reference only: no reminder, no collection.

Revision ID: 0026
Revises: 0025
"""
import sqlalchemy as sa
from alembic import op

revision = "0026"
down_revision = "0025"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("rentals", sa.Column("old_balance", sa.Numeric(12, 2), nullable=True))
    op.add_column("rentals", sa.Column("old_balance_date", sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column("rentals", "old_balance_date")
    op.drop_column("rentals", "old_balance")
