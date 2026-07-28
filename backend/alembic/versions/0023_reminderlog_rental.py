"""Let reminder_logs reference a rental (rent-collection reminders).

Adds nullable rental_id / rental_installment_id so the rental reminder job can
log every WhatsApp attempt (sent + failed) the same way the sale reminders do,
keyed on the rental installment for idempotency.

Revision ID: 0023
Revises: 0022
"""
import sqlalchemy as sa
from alembic import op

revision = "0023"
down_revision = "0022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "reminder_logs",
        sa.Column("rental_id", sa.BigInteger(), nullable=True),
    )
    op.add_column(
        "reminder_logs",
        sa.Column("rental_installment_id", sa.BigInteger(), nullable=True),
    )
    op.create_foreign_key(
        "reminder_logs_rental_id_fkey",
        "reminder_logs",
        "rentals",
        ["rental_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "reminder_logs_rental_installment_id_fkey",
        "reminder_logs",
        "rental_installments",
        ["rental_installment_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "reminder_logs_rental_installment_id_fkey", "reminder_logs", type_="foreignkey"
    )
    op.drop_constraint(
        "reminder_logs_rental_id_fkey", "reminder_logs", type_="foreignkey"
    )
    op.drop_column("reminder_logs", "rental_installment_id")
    op.drop_column("reminder_logs", "rental_id")
