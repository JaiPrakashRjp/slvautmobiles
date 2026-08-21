"""Loan module persistence: loans, loan_emis, loan_payments + payment proofs.

A no-interest loan (booked against a customer + vehicle) with a fixed EMI per
month for `tenure_months`; late months accrue a penalty entered on the payment.
Adds loan_id / emi_id to reminder_logs so EMI reminders reuse that table, and a
`loan` value to the notification_entity enum.

Revision ID: 0009
Revises: 0008
"""
from __future__ import annotations

from typing import Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels = None
depends_on = None


def _enum(name: str):
    return postgresql.ENUM(name=name, create_type=False)


def upgrade() -> None:
    op.create_table(
        "loans",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("customer_id", sa.BigInteger, sa.ForeignKey("customers.id"), nullable=False),
        sa.Column(
            "vehicle_id",
            sa.BigInteger,
            sa.ForeignKey("vehicles.id", ondelete="SET NULL"),
        ),
        sa.Column("principal", sa.Numeric(12, 2), nullable=False),
        sa.Column("emi_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("tenure_months", sa.Integer, nullable=False),
        sa.Column("loan_date", sa.Date, nullable=False),
        sa.Column("first_due_date", sa.Date, nullable=False),
        sa.Column("loan_status", sa.Text, nullable=False, server_default="active"),
        sa.Column("closed_at", sa.DateTime(timezone=False)),
        sa.Column(
            "status", _enum("entity_status"), nullable=False,
            server_default="pending_confirmation",
        ),
        sa.Column("created_by", sa.BigInteger, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
        sa.Column("confirmed_by", sa.BigInteger),
        sa.Column("confirmed_at", sa.DateTime(timezone=False)),
        sa.Column("rejection_reason", sa.Text),
        sa.Column("remarks", sa.Text),
    )

    op.create_table(
        "loan_emis",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("loan_id", sa.BigInteger, sa.ForeignKey("loans.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("sequence_number", sa.Integer, nullable=False),
        sa.Column("due_date", sa.Date, nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("penalty", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("amount_paid", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("received_date", sa.Date),
        sa.Column("paid_date", sa.Date),
        sa.Column("remarks", sa.Text),
        sa.Column(
            "status", _enum("installment_status"), nullable=False,
            server_default="pending",
        ),
        sa.Column("created_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("loan_id", "sequence_number", name="loan_emis_unique"),
    )

    op.create_table(
        "loan_payments",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("loan_id", sa.BigInteger, sa.ForeignKey("loans.id", ondelete="CASCADE"), nullable=False),
        sa.Column("emi_id", sa.BigInteger, sa.ForeignKey("loan_emis.id", ondelete="SET NULL")),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("penalty", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("received_date", sa.Date),
        sa.Column("remarks", sa.Text),
        sa.Column("recorded_by", sa.BigInteger, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "loan_payment_documents",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("payment_id", sa.BigInteger, sa.ForeignKey("loan_payments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("file_name", sa.Text, nullable=False),
        sa.Column("mime_type", sa.Text, nullable=False),
        sa.Column("size_bytes", sa.BigInteger),
        sa.Column("content", sa.LargeBinary, nullable=False),
        sa.Column("uploaded_by", sa.BigInteger),
        sa.Column("uploaded_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
    )

    # Loan EMI reminders reuse the reminder_logs table.
    op.add_column(
        "reminder_logs",
        sa.Column("loan_id", sa.BigInteger, sa.ForeignKey("loans.id", ondelete="CASCADE")),
    )
    op.add_column(
        "reminder_logs",
        sa.Column("emi_id", sa.BigInteger, sa.ForeignKey("loan_emis.id", ondelete="SET NULL")),
    )

    # notification_entity needs a 'loan' value (ALTER TYPE outside the txn block).
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE notification_entity ADD VALUE IF NOT EXISTS 'loan'")


def downgrade() -> None:
    op.drop_column("reminder_logs", "emi_id")
    op.drop_column("reminder_logs", "loan_id")
    op.drop_table("loan_payment_documents")
    op.drop_table("loan_payments")
    op.drop_table("loan_emis")
    op.drop_table("loans")
    # The extra notification_entity enum value is harmless and left in place.
