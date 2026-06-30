"""Separate financers into vehicle_financers and sale_financers.

- rename the shared `financers` table -> `vehicle_financers` (vehicle finance)
- replace the `sale_financers` LINK table with a `sale_financers` MASTER table
- add sales.financer_id -> sale_financers (one financer per sale, reusable)

Revision ID: 0011
Revises: 0010
"""
import sqlalchemy as sa
from alembic import op

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1) financers -> vehicle_financers (the vehicles.financer_id FK follows it)
    op.rename_table("financers", "vehicle_financers")

    # 2) drop the old sale<->financer link table
    op.drop_table("sale_financers")

    # 3) recreate sale_financers as its OWN master list
    op.create_table(
        "sale_financers",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("name", sa.Text, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    # 4) the sale points at its own financer
    op.add_column(
        "sales",
        sa.Column(
            "financer_id",
            sa.BigInteger,
            sa.ForeignKey("sale_financers.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("sales", "financer_id")
    op.drop_table("sale_financers")
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
            sa.ForeignKey("vehicle_financers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint("sale_id", name="sale_financers_sale_unique"),
    )
    op.rename_table("vehicle_financers", "financers")
