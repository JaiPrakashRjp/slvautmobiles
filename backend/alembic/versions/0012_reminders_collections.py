"""Reminders + collections: extend installments/payments, add payment proofs.

- installment_status gains 'in_progress' and 'cancelled'
- sale_installments: taken_by / taken_at (call lock), created_by, cancel_reason
- sale_payments: approval fields (status/confirmed_by/confirmed_at/rejection_reason)
- new sale_payment_documents table (the payment proof screenshot)

Revision ID: 0012
Revises: 0011
"""
import sqlalchemy as sa
from alembic import op

revision = "0012"
down_revision = "0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1) new installment statuses (safe if re-run)
    op.execute("ALTER TYPE installment_status ADD VALUE IF NOT EXISTS 'in_progress'")
    op.execute("ALTER TYPE installment_status ADD VALUE IF NOT EXISTS 'cancelled'")

    # 2) sale_installments — reminder ownership + call lock + cancel reason
    op.add_column("sale_installments", sa.Column("created_by", sa.BigInteger, nullable=True))
    op.add_column("sale_installments", sa.Column("taken_by", sa.BigInteger, nullable=True))
    op.add_column(
        "sale_installments",
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column("sale_installments", sa.Column("cancel_reason", sa.Text, nullable=True))

    # 3) sale_payments — super-admin approval gate
    op.add_column(
        "sale_payments",
        sa.Column(
            "status",
            sa.Enum(name="entity_status", create_type=False),
            nullable=False,
            server_default="active",
        ),
    )
    op.add_column("sale_payments", sa.Column("confirmed_by", sa.BigInteger, nullable=True))
    op.add_column(
        "sale_payments",
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column("sale_payments", sa.Column("rejection_reason", sa.Text, nullable=True))

    # 4) payment proof screenshots (BYTEA, like vehicle_documents)
    op.create_table(
        "sale_payment_documents",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column(
            "payment_id",
            sa.BigInteger,
            sa.ForeignKey("sale_payments.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("file_name", sa.Text, nullable=False),
        sa.Column("mime_type", sa.Text, nullable=False),
        sa.Column("size_bytes", sa.BigInteger, nullable=True),
        sa.Column("content", sa.LargeBinary, nullable=False),
        sa.Column("uploaded_by", sa.BigInteger, nullable=True),
        sa.Column(
            "uploaded_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("sale_payment_documents")
    for col in ("rejection_reason", "confirmed_at", "confirmed_by", "status"):
        op.drop_column("sale_payments", col)
    for col in ("cancel_reason", "taken_at", "taken_by", "created_by"):
        op.drop_column("sale_installments", col)
    # NOTE: enum values are not removed on downgrade (Postgres can't drop them easily).
