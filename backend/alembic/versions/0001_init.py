"""init schema: modules, customers, vehicles, documents (integer PKs)

Revision ID: 0001
Revises:
Create Date: 2026-06-15

Fresh consolidated schema:
  * BIGINT identity primary keys (1, 2, 3 …) everywhere
  * created_by / confirmed_by / assigned_to_customer_id are BIGINT
  * sale_status (not_sold/sold) alongside inventory_status
  * customers + customer_documents (KYC docs as BYTEA)
  * unique (parent, doc_type) so re-upload replaces a document
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

ENUMS = {
    "branch": ("branch_1", "branch_2"),
    "vehicle_hand": ("first_hand", "second_hand"),
    "fuel_type": ("cng", "lpg", "electric"),
    "showroom": ("amba", "aestece", "khivraj"),
    "vehicle_doc_type": (
        "rc", "fc", "insurance", "permit", "others", "noc",
        "prev_owner_id_proof", "prev_owner_photo",
    ),
    "kyc_doc_type": (
        "aadhaar", "pan", "dl", "rental_agreement", "photo", "assurity_id_proof",
    ),
    "inventory_status": ("available", "reserved", "sold", "on_rent"),
    "sale_status": ("not_sold", "sold"),
    "entity_status": ("pending_confirmation", "active", "rejected"),
}


def _enum(name: str):
    return postgresql.ENUM(name=name, create_type=False)


def _gated_columns():
    """Audit / role-gate columns shared by vehicles and customers."""
    return [
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
    ]


def _updated_at_trigger(table: str) -> None:
    op.execute(f"DROP TRIGGER IF EXISTS {table}_set_updated_at ON {table};")
    op.execute(
        f"CREATE TRIGGER {table}_set_updated_at BEFORE UPDATE ON {table} "
        f"FOR EACH ROW EXECUTE FUNCTION set_updated_at();"
    )


def upgrade() -> None:
    op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto"')

    for name, values in ENUMS.items():
        vals = ", ".join(f"'{v}'" for v in values)
        op.execute(
            f"DO $$ BEGIN CREATE TYPE {name} AS ENUM ({vals}); "
            f"EXCEPTION WHEN duplicate_object THEN NULL; END $$;"
        )

    op.execute(
        "CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$ "
        "BEGIN NEW.updated_at = now(); RETURN NEW; END $$ LANGUAGE plpgsql;"
    )

    # ── modules ──────────────────────────────────────────────────────────────
    op.create_table(
        "modules",
        sa.Column("id", sa.SmallInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("code", sa.Text, nullable=False, unique=True),
        sa.Column("name", sa.Text, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
    )
    op.execute(
        "INSERT INTO modules (code, name) VALUES "
        "('auto_sale','Auto Sale System'),"
        "('rental','Auto Rental Collection'),"
        "('loan','Loan Management') ON CONFLICT (code) DO NOTHING"
    )

    # ── customers (created before vehicles for the FK) ─────────────────────────
    op.create_table(
        "customers",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("first_name", sa.Text, nullable=False),
        sa.Column("last_name", sa.Text, nullable=False, server_default=""),
        sa.Column("phone", sa.String(10), nullable=False),
        sa.Column("address", sa.Text, nullable=False, server_default=""),
        sa.Column("branch", _enum("branch")),
        sa.Column("age", sa.SmallInteger),
        sa.Column("dob", sa.Date),
        sa.Column("assurity_name", sa.Text),
        sa.Column("assurity_mobile", sa.String(10)),
        *_gated_columns(),
    )
    op.create_index("customers_module_idx", "customers", ["module_id"])
    op.create_index("customers_status_idx", "customers", ["status"])
    op.create_index("customers_branch_idx", "customers", ["branch"])
    op.create_index("customers_phone_idx", "customers", ["phone"])
    _updated_at_trigger("customers")

    op.create_table(
        "customer_documents",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("customer_id", sa.BigInteger,
                  sa.ForeignKey("customers.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("doc_type", _enum("kyc_doc_type"), nullable=False),
        sa.Column("file_name", sa.Text, nullable=False),
        sa.Column("mime_type", sa.Text, nullable=False),
        sa.Column("size_bytes", sa.BigInteger),
        sa.Column("content", postgresql.BYTEA, nullable=False),
        sa.Column("uploaded_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("customer_id", "doc_type", name="customer_documents_unique"),
    )
    op.create_index("customer_documents_customer_idx", "customer_documents", ["customer_id"])
    op.create_index("customer_documents_module_idx", "customer_documents", ["module_id"])

    # ── vehicles ─────────────────────────────────────────────────────────────
    op.create_table(
        "vehicles",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("branch", _enum("branch"), nullable=False),
        sa.Column("owned_hand", _enum("vehicle_hand"), nullable=False),
        sa.Column("chassis_no", sa.Text, nullable=False),
        sa.Column("model", sa.Text, nullable=False),
        sa.Column("fuel_type", _enum("fuel_type")),
        sa.Column("purchase_date", sa.Date),
        sa.Column("buying_expenses", sa.Numeric(12, 2)),
        sa.Column("showroom", _enum("showroom")),
        sa.Column("reg_no", sa.Text),
        sa.Column("insurance_date", sa.Date),
        sa.Column("fc_date", sa.Date),
        sa.Column("permit_date", sa.Date),
        sa.Column("prev_owner_name", sa.Text),
        sa.Column("prev_owner_mobile", sa.String(10)),
        sa.Column("prev_owner_address", sa.Text),
        sa.Column("inventory_status", _enum("inventory_status"),
                  server_default="available", nullable=False),
        sa.Column("sale_status", _enum("sale_status"),
                  server_default="not_sold", nullable=False),
        sa.Column("next_service_due_date", sa.Date),
        sa.Column("assigned_to_customer_id", sa.BigInteger,
                  sa.ForeignKey("customers.id")),
        *_gated_columns(),
        sa.CheckConstraint("owned_hand <> 'second_hand' OR reg_no IS NOT NULL",
                           name="vehicles_second_hand_reg_no_chk"),
        sa.CheckConstraint("owned_hand <> 'first_hand' OR showroom IS NOT NULL",
                           name="vehicles_first_hand_showroom_chk"),
    )
    op.create_index("vehicles_module_idx", "vehicles", ["module_id"])
    op.create_index("vehicles_status_idx", "vehicles", ["status"])
    op.create_index("vehicles_branch_idx", "vehicles", ["branch"])
    op.create_index("vehicles_inventory_idx", "vehicles", ["inventory_status"])
    op.create_index("vehicles_sale_status_idx", "vehicles", ["sale_status"])
    op.create_index("vehicles_assigned_cust_idx", "vehicles", ["assigned_to_customer_id"])
    op.create_index("vehicles_chassis_idx", "vehicles", ["chassis_no"])
    _updated_at_trigger("vehicles")

    op.create_table(
        "vehicle_documents",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("vehicle_id", sa.BigInteger,
                  sa.ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("doc_type", _enum("vehicle_doc_type"), nullable=False),
        sa.Column("file_name", sa.Text, nullable=False),
        sa.Column("mime_type", sa.Text, nullable=False),
        sa.Column("size_bytes", sa.BigInteger),
        sa.Column("content", postgresql.BYTEA, nullable=False),
        sa.Column("uploaded_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("vehicle_id", "doc_type", name="vehicle_documents_unique"),
    )
    op.create_index("vehicle_documents_vehicle_idx", "vehicle_documents", ["vehicle_id"])
    op.create_index("vehicle_documents_module_idx", "vehicle_documents", ["module_id"])


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS vehicles_set_updated_at ON vehicles")
    op.execute("DROP TRIGGER IF EXISTS customers_set_updated_at ON customers")
    op.drop_table("vehicle_documents")
    op.drop_table("vehicles")
    op.drop_table("customer_documents")
    op.drop_table("customers")
    op.drop_table("modules")
    op.execute("DROP FUNCTION IF EXISTS set_updated_at")
    for name in reversed(list(ENUMS.keys())):
        op.execute(f"DROP TYPE IF EXISTS {name}")
