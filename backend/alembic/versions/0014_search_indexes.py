"""Indexes for fast search + list loading (trigram for ILIKE, btree for filters).

Revision ID: 0014
Revises: 0013
"""
from alembic import op

revision = "0014"
down_revision = "0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # pg_trgm powers fast ILIKE '%term%' search (trusted extension; DB owner can create)
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # ── trigram GIN indexes (search) ─────────────────────────────────────────
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_vehicles_reg_no_trgm "
        "ON vehicles USING gin (reg_no gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_vehicles_chassis_trgm "
        "ON vehicles USING gin (chassis_no gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_customers_phone_trgm "
        "ON customers USING gin (phone gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_customers_name_trgm "
        "ON customers USING gin ((first_name || ' ' || last_name) gin_trgm_ops)"
    )

    # ── btree indexes (filters, ordering, FK joins) ──────────────────────────
    op.execute("CREATE INDEX IF NOT EXISTS ix_vehicles_status ON vehicles (status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_vehicles_sale_status ON vehicles (sale_status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_vehicles_created_at ON vehicles (created_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_customers_status ON customers (status)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_customers_created_at ON customers (created_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_sales_customer_id ON sales (customer_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_sales_vehicle_id ON sales (vehicle_id)")


def downgrade() -> None:
    for name in (
        "ix_vehicles_reg_no_trgm",
        "ix_vehicles_chassis_trgm",
        "ix_customers_phone_trgm",
        "ix_customers_name_trgm",
        "ix_vehicles_status",
        "ix_vehicles_sale_status",
        "ix_vehicles_created_at",
        "ix_customers_status",
        "ix_customers_created_at",
        "ix_sales_customer_id",
        "ix_sales_vehicle_id",
    ):
        op.execute(f"DROP INDEX IF EXISTS {name}")
