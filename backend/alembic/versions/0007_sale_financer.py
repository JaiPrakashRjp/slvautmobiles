"""Add sale_financers link table (one financer per sale).

Revision ID: 0007
Revises: 0006
"""
import sqlalchemy as sa
from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sale_financers",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column(
            "sale_id",
            sa.BigInteger,
            sa.ForeignKey("sales.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "financer_id",
            sa.BigInteger,
            sa.ForeignKey("financers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        # one financer per sale
        sa.UniqueConstraint("sale_id", name="sale_financers_sale_unique"),
    )


def downgrade() -> None:
    op.drop_table("sale_financers")
