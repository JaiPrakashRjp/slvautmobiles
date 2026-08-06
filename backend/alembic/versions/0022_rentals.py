"""Rental module: rentals + rental_installments + rental_payments +
rental_payment_documents (mirrors the sale tables). Reuses the customers and
vehicles tables via module_id = rental.

Revision ID: 0022
Revises: 0021
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0022"
down_revision = "0021"
branch_labels = None
depends_on = None


def _enum(name: str):
    return postgresql.ENUM(name=name, create_type=False)


def _updated_at_trigger(table: str) -> None:
    op.execute(f"DROP TRIGGER IF EXISTS {table}_set_updated_at ON {table};")
    op.execute(
        f"CREATE TRIGGER {table}_set_updated_at BEFORE UPDATE ON {table} "
        f"FOR EACH ROW EXECUTE FUNCTION set_updated_at();"
    )


def upgrade() -> None:
    # New lifecycle enum for a rental (active/completed/cancelled/seized).
    op.execute(
        "DO $$ BEGIN CREATE TYPE rental_lifecycle AS ENUM "
        "('active','completed','cancelled','seized'); "
        "EXCEPTION WHEN duplicate_object THEN NULL; END $$;"
    )
    # Allow rental verification notifications. ALTER TYPE ... ADD VALUE cannot run
    # inside a transaction block, so use an autocommit block.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE notification_entity ADD VALUE IF NOT EXISTS 'rental'"
        )

    # ── rentals ──────────────────────────────────────────────────────────────
    op.create_table(
        "rentals",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("vehicle_id", sa.BigInteger, sa.ForeignKey("vehicles.id"), nullable=False),
        sa.Column("customer_id", sa.BigInteger, sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("total_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("advance_amount", sa.Numeric(12, 2), server_default="0", nullable=False),
        sa.Column("remaining_amount", sa.Numeric(12, 2), server_default="0", nullable=False),
        sa.Column("start_date", sa.Date),
        sa.Column("invoice_no", sa.Text),
        sa.Column("remarks", sa.Text),
        sa.Column("rental_status", _enum("rental_lifecycle"),
                  server_default="active", nullable=False),
        sa.Column("completed_at", sa.TIMESTAMP(timezone=True)),
        # seizure
        sa.Column("seized_at", sa.TIMESTAMP(timezone=True)),
        sa.Column("seized_by", sa.BigInteger),
        sa.Column("seize_reason", sa.Text),
        sa.Column("seize_stage", sa.Text),
        # edit approval
        sa.Column("pending_edit", postgresql.JSONB),
        sa.Column("edit_stage", sa.Text),
        sa.Column("edit_requested_by", sa.BigInteger),
        # gated / audit
        sa.Column("status", _enum("entity_status"),
                  server_default="pending_confirmation", nullable=False),
        sa.Column("created_by", sa.BigInteger, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("confirmed_by", sa.BigInteger),
        sa.Column("confirmed_at", sa.TIMESTAMP(timezone=True)),
        sa.Column("rejection_reason", sa.Text),
    )
    op.create_index("rentals_module_idx", "rentals", ["module_id"])
    op.create_index("rentals_vehicle_idx", "rentals", ["vehicle_id"])
    op.create_index("rentals_customer_idx", "rentals", ["customer_id"])
    op.create_index("rentals_rental_status_idx", "rentals", ["rental_status"])
    op.create_index("rentals_status_idx", "rentals", ["status"])
    _updated_at_trigger("rentals")

    # ── rental_installments (rent-collection reminders) ──────────────────────
    op.create_table(
        "rental_installments",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("rental_id", sa.BigInteger,
                  sa.ForeignKey("rentals.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("number", sa.Integer, nullable=False),
        sa.Column("due_date", sa.Date, nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("paid_date", sa.Date),
        sa.Column("status", _enum("installment_status"),
                  server_default="pending", nullable=False),
        sa.Column("created_by", sa.BigInteger),
        sa.Column("taken_by", sa.BigInteger),
        sa.Column("taken_at", sa.TIMESTAMP(timezone=True)),
        sa.Column("cancel_reason", sa.Text),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("rental_id", "number", name="rental_installments_unique"),
    )
    op.create_index("rental_installments_rental_idx", "rental_installments", ["rental_id"])
    op.create_index("rental_installments_due_idx", "rental_installments", ["due_date"])
    op.create_index("rental_installments_status_idx", "rental_installments", ["status"])
    _updated_at_trigger("rental_installments")

    # ── rental_payments (ledger) ─────────────────────────────────────────────
    op.create_table(
        "rental_payments",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("rental_id", sa.BigInteger,
                  sa.ForeignKey("rentals.id", ondelete="CASCADE"), nullable=False),
        sa.Column("installment_id", sa.BigInteger,
                  sa.ForeignKey("rental_installments.id", ondelete="SET NULL")),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("paid_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("kind", _enum("payment_kind"),
                  server_default="installment", nullable=False),
        sa.Column("recorded_by", sa.BigInteger, nullable=False),
        sa.Column("status", _enum("entity_status"),
                  server_default="active", nullable=False),
        sa.Column("confirmed_by", sa.BigInteger),
        sa.Column("confirmed_at", sa.TIMESTAMP(timezone=True)),
        sa.Column("rejection_reason", sa.Text),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("rental_payments_rental_idx", "rental_payments", ["rental_id"])
    op.create_index("rental_payments_installment_idx", "rental_payments", ["installment_id"])

    # ── rental_payment_documents (proof screenshots) ─────────────────────────
    op.create_table(
        "rental_payment_documents",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("payment_id", sa.BigInteger,
                  sa.ForeignKey("rental_payments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("file_name", sa.Text, nullable=False),
        sa.Column("mime_type", sa.Text, nullable=False),
        sa.Column("size_bytes", sa.BigInteger),
        sa.Column("content", sa.LargeBinary, nullable=False),
        sa.Column("uploaded_by", sa.BigInteger),
        sa.Column("uploaded_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("rental_payment_documents_payment_idx",
                    "rental_payment_documents", ["payment_id"])


def downgrade() -> None:
    op.drop_table("rental_payment_documents")
    op.drop_table("rental_payments")
    op.drop_table("rental_installments")
    op.drop_table("rentals")
    op.execute("DROP TYPE IF EXISTS rental_lifecycle")
