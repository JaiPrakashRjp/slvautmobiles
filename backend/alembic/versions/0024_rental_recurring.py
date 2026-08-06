"""Rental recurring-rent model: rental_type + period_amount.

Adds the weekly/daily rent cadence to rentals. Rent is now charged per period and
the schedule rolls forward from each payment, so total_amount is no longer required
(nullable — legacy balance model only). The rental module is dev-only (not launched
in prod), so this reshapes the schema without touching live data.

Revision ID: 0024
Revises: 0023
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0024"
down_revision = "0023"
branch_labels = None
depends_on = None

# create_type=False so add_column does NOT auto-emit CREATE TYPE; we create the
# enum explicitly with checkfirst=True (idempotent) just below.
RENTAL_TYPE = postgresql.ENUM("weekly", "daily", name="rental_type", create_type=False)


def upgrade() -> None:
    RENTAL_TYPE.create(op.get_bind(), checkfirst=True)

    op.add_column(
        "rentals",
        sa.Column("rental_type", RENTAL_TYPE, nullable=True),
    )
    op.add_column(
        "rentals",
        sa.Column("period_amount", sa.Numeric(12, 2), nullable=True),
    )
    # total_amount was NOT NULL (balance model); recurring rentals don't use it.
    op.alter_column(
        "rentals", "total_amount", existing_type=sa.Numeric(12, 2), nullable=True
    )


def downgrade() -> None:
    op.alter_column(
        "rentals", "total_amount", existing_type=sa.Numeric(12, 2), nullable=False
    )
    op.drop_column("rentals", "period_amount")
    op.drop_column("rentals", "rental_type")
    RENTAL_TYPE.drop(op.get_bind(), checkfirst=True)
