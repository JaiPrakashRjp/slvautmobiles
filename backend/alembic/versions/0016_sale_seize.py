"""Vehicle seizure (repossession): seized sale state + seize fields + is_seized flag.

Revision ID: 0016
Revises: 0015
"""
import sqlalchemy as sa
from alembic import op

revision = "0016"
down_revision = "0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Add the new 'seized' value to the sale_lifecycle enum. ALTER TYPE ... ADD
    #    VALUE cannot run inside a transaction block, so use an autocommit block.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE sale_lifecycle ADD VALUE IF NOT EXISTS 'seized'")

    # 2. Seizure audit fields on the (frozen) sale row — this is the history.
    op.add_column("sales", sa.Column("seized_at", sa.DateTime(), nullable=True))
    op.add_column("sales", sa.Column("seized_by", sa.BigInteger(), nullable=True))
    op.add_column("sales", sa.Column("seize_reason", sa.Text(), nullable=True))

    # 3. Current-state flag on the vehicle (true while seized, reset on re-sale).
    op.add_column(
        "vehicles",
        sa.Column(
            "is_seized", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
    )


def downgrade() -> None:
    op.drop_column("vehicles", "is_seized")
    op.drop_column("sales", "seize_reason")
    op.drop_column("sales", "seized_by")
    op.drop_column("sales", "seized_at")
    # Note: Postgres cannot easily DROP an enum value, so 'seized' is left on the
    # sale_lifecycle type. It is harmless if unused.
