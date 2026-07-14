"""Sale 'sold' flag — set true when the user confirms a fully-paid sale as sold.

Drives the UI: while false the Seize button shows; once the balance is cleared
the user confirms the sale as sold (sold=true) and Seize is hidden.

Revision ID: 0019
Revises: 0018
"""
import sqlalchemy as sa
from alembic import op

revision = "0019"
down_revision = "0018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "sales",
        sa.Column("sold", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    op.drop_column("sales", "sold")
