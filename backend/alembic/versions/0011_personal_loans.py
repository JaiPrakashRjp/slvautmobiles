"""Personal-loans module: own financer master, loans, monthly EMIs.

A simple no-interest personal loan (vehicle number, own-master financer, loan &
EMI amount, tenure, loan date, reminder phone). EMIs are a flat monthly schedule
marked paid one at a time. Adds personal_loan_id / personal_loan_emi_id to
reminder_logs so the monthly WhatsApp reminders reuse that table.

Revision ID: 0011
Revises: 0010
"""
from __future__ import annotations

from typing import Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0011"
down_revision: Union[str, None] = "0010"
branch_labels = None
depends_on = None


def _enum(name: str):
    return postgresql.ENUM(name=name, create_type=False)


def upgrade() -> None:
    op.create_table(
        "personal_loan_financers",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("name", sa.Text, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "personal_loans",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("vehicle_number", sa.Text, nullable=False),
        sa.Column(
            "financer_id",
            sa.BigInteger,
            sa.ForeignKey("personal_loan_financers.id", ondelete="SET NULL"),
        ),
        sa.Column("loan_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("emi_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("tenure_months", sa.Integer, nullable=False),
        sa.Column("loan_date", sa.Date, nullable=False),
        sa.Column("first_due_date", sa.Date, nullable=False),
        sa.Column("phone", sa.Text),
        sa.Column("loan_status", sa.Text, nullable=False, server_default="active"),
        sa.Column("closed_at", sa.DateTime(timezone=False)),
        sa.Column("remarks", sa.Text),
        sa.Column("created_by", sa.BigInteger, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "personal_loan_emis",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("personal_loan_id", sa.BigInteger, sa.ForeignKey("personal_loans.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sequence_number", sa.Integer, nullable=False),
        sa.Column("due_date", sa.Date, nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("status", _enum("installment_status"), nullable=False, server_default="pending"),
        sa.Column("paid_date", sa.Date),
        sa.Column("created_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("personal_loan_id", "sequence_number", name="personal_loan_emis_unique"),
    )

    op.add_column(
        "reminder_logs",
        sa.Column("personal_loan_id", sa.BigInteger, sa.ForeignKey("personal_loans.id", ondelete="CASCADE")),
    )
    op.add_column(
        "reminder_logs",
        sa.Column("personal_loan_emi_id", sa.BigInteger, sa.ForeignKey("personal_loan_emis.id", ondelete="SET NULL")),
    )


def downgrade() -> None:
    op.drop_column("reminder_logs", "personal_loan_emi_id")
    op.drop_column("reminder_logs", "personal_loan_id")
    op.drop_table("personal_loan_emis")
    op.drop_table("personal_loans")
    op.drop_table("personal_loan_financers")
