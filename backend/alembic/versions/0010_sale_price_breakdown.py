"""Add sale price breakdown columns + hp_amount on sales.

Revision ID: 0010
Revises: 0009
"""
import sqlalchemy as sa
from alembic import op

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None

_MONEY = sa.Numeric(12, 2)


def upgrade() -> None:
    for col in (
        "vehicle_amount",
        "additional_fitting",
        "dl_charges",
        "document_charges",
        "other_expenses",
    ):
        op.add_column(
            "sales",
            sa.Column(col, _MONEY, nullable=False, server_default="0"),
        )
    op.add_column("sales", sa.Column("hp_amount", _MONEY, nullable=True))


def downgrade() -> None:
    for col in (
        "hp_amount",
        "other_expenses",
        "document_charges",
        "dl_charges",
        "additional_fitting",
        "vehicle_amount",
    ):
        op.drop_column("sales", col)
