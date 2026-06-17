"""users + roles + module assignment + notifications + sales/installments/payments/reminders

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-16

Adds:
  * roles, users, user_modules  — user management + email/password login
  * notifications               — in-app verification alerts (NOT WhatsApp)
  * sales, sale_installments, sale_payments — vehicle sales + monthly schedule + ledger
  * reminder_logs               — per-recipient WhatsApp reminder log with sent_at
  * a `user_management` modules row + one seeded super-admin user
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Default seeded super-admin login (change after first sign-in).
SUPER_ADMIN_EMAIL = "owner@slvauto.in"
SUPER_ADMIN_PHONE = "9900000001"
SUPER_ADMIN_PASSWORD = "Admin@123"

ENUMS = {
    "deposit_type": ("full_cash", "down_payment"),
    "sale_lifecycle": ("active", "closed", "cancelled"),
    "installment_status": ("pending", "paid", "overdue"),
    "payment_kind": ("installment", "early_payoff", "advance"),
    "reminder_recipient": ("customer", "super_admin"),
    "reminder_channel": ("whatsapp", "sms"),
    "reminder_status": ("pending", "sent", "failed"),
    "account_status": ("active", "suspended"),
    "notification_type": ("verification_request", "info"),
    "notification_entity": ("vehicle", "customer", "sale"),
}


def _enum(name: str):
    return postgresql.ENUM(name=name, create_type=False)


def _gated_columns():
    """Audit / role-gate columns shared by gated entities (mirrors 0001)."""
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


def _bcrypt(password: str) -> str:
    import bcrypt
    # bcrypt caps the password at 72 bytes.
    pw = password.encode("utf-8")[:72]
    return bcrypt.hashpw(pw, bcrypt.gensalt()).decode("utf-8")


def upgrade() -> None:
    for name, values in ENUMS.items():
        vals = ", ".join(f"'{v}'" for v in values)
        op.execute(
            f"DO $$ BEGIN CREATE TYPE {name} AS ENUM ({vals}); "
            f"EXCEPTION WHEN duplicate_object THEN NULL; END $$;"
        )

    # add the User Management module (auto_sale/rental/loan already seeded in 0001)
    op.execute(
        "INSERT INTO modules (code, name) VALUES "
        "('user_management','User Management') ON CONFLICT (code) DO NOTHING"
    )

    # ── roles ──────────────────────────────────────────────────────────────────
    op.create_table(
        "roles",
        sa.Column("id", sa.SmallInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("name", sa.Text, nullable=False, unique=True),
        sa.Column("label", sa.Text, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
    )
    op.execute(
        "INSERT INTO roles (name, label) VALUES "
        "('super_admin','Super admin'),('admin','Admin') "
        "ON CONFLICT (name) DO NOTHING"
    )

    # ── users ──────────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("first_name", sa.Text, nullable=False),
        sa.Column("last_name", sa.Text, nullable=False, server_default=""),
        sa.Column("email", sa.Text, nullable=False, unique=True),
        sa.Column("phone", sa.String(10), nullable=False),
        sa.Column("role_id", sa.SmallInteger, sa.ForeignKey("roles.id"), nullable=False),
        sa.Column("password_hash", sa.Text, nullable=False),
        sa.Column("account_status", _enum("account_status"),
                  server_default="active", nullable=False),
        *_gated_columns(),
    )
    op.create_index("users_role_idx", "users", ["role_id"])
    op.create_index("users_status_idx", "users", ["status"])
    _updated_at_trigger("users")

    # seed one super-admin (status active so it can log in immediately)
    op.execute(
        sa.text(
            "INSERT INTO users (first_name, last_name, email, phone, role_id, "
            "password_hash, account_status, status, created_by) "
            "SELECT 'Owner', '', :email, :phone, r.id, :pw, 'active', 'active', 1 "
            "FROM roles r WHERE r.name = 'super_admin' "
            "ON CONFLICT (email) DO NOTHING"
        ).bindparams(
            email=SUPER_ADMIN_EMAIL, phone=SUPER_ADMIN_PHONE, pw=_bcrypt(SUPER_ADMIN_PASSWORD)
        )
    )

    # ── user_modules (assignment from the existing modules table) ──────────────
    op.create_table(
        "user_modules",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("user_id", sa.BigInteger,
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("assigned_by", sa.BigInteger),
        sa.Column("assigned_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "module_id", name="user_modules_unique"),
    )
    op.create_index("user_modules_user_idx", "user_modules", ["user_id"])

    # ── notifications (in-app verification alerts) ─────────────────────────────
    op.create_table(
        "notifications",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("recipient_user_id", sa.BigInteger,
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", _enum("notification_type"),
                  server_default="verification_request", nullable=False),
        sa.Column("title", sa.Text, nullable=False),
        sa.Column("message", sa.Text, nullable=False, server_default=""),
        sa.Column("entity_type", _enum("notification_entity")),
        sa.Column("entity_id", sa.BigInteger),
        sa.Column("is_read", sa.Boolean, server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("notifications_recipient_idx", "notifications", ["recipient_user_id"])
    op.create_index("notifications_is_read_idx", "notifications", ["is_read"])

    # ── sales ──────────────────────────────────────────────────────────────────
    op.create_table(
        "sales",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("vehicle_id", sa.BigInteger, sa.ForeignKey("vehicles.id"), nullable=False),
        sa.Column("customer_id", sa.BigInteger, sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("deposit_type", _enum("deposit_type"), nullable=False),
        sa.Column("sale_price", sa.Numeric(12, 2), nullable=False),
        sa.Column("sale_date", sa.Date),
        sa.Column("amount_received", sa.Numeric(12, 2), server_default="0", nullable=False),
        sa.Column("remaining_amount", sa.Numeric(12, 2), server_default="0", nullable=False),
        sa.Column("monthly_amount", sa.Numeric(12, 2)),
        sa.Column("installment_count", sa.Integer),
        sa.Column("first_due_date", sa.Date),
        sa.Column("customer_whatsapp", sa.Text),
        sa.Column("invoice_no", sa.Text),
        sa.Column("sale_status", _enum("sale_lifecycle"),
                  server_default="active", nullable=False),
        sa.Column("closed_at", sa.TIMESTAMP(timezone=True)),
        *_gated_columns(),
    )
    op.create_index("sales_module_idx", "sales", ["module_id"])
    op.create_index("sales_vehicle_idx", "sales", ["vehicle_id"])
    op.create_index("sales_customer_idx", "sales", ["customer_id"])
    op.create_index("sales_sale_status_idx", "sales", ["sale_status"])
    op.create_index("sales_status_idx", "sales", ["status"])
    op.create_index("sales_first_due_idx", "sales", ["first_due_date"])
    _updated_at_trigger("sales")

    # ── sale_installments ──────────────────────────────────────────────────────
    op.create_table(
        "sale_installments",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("sale_id", sa.BigInteger,
                  sa.ForeignKey("sales.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module_id", sa.SmallInteger, sa.ForeignKey("modules.id"), nullable=False),
        sa.Column("month_number", sa.Integer, nullable=False),
        sa.Column("due_date", sa.Date, nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("paid_date", sa.Date),
        sa.Column("status", _enum("installment_status"),
                  server_default="pending", nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("sale_id", "month_number", name="sale_installments_unique"),
    )
    op.create_index("sale_installments_sale_idx", "sale_installments", ["sale_id"])
    op.create_index("sale_installments_due_idx", "sale_installments", ["due_date"])
    op.create_index("sale_installments_status_idx", "sale_installments", ["status"])
    _updated_at_trigger("sale_installments")

    # ── sale_payments (ledger; captures early payoff) ──────────────────────────
    op.create_table(
        "sale_payments",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("sale_id", sa.BigInteger,
                  sa.ForeignKey("sales.id", ondelete="CASCADE"), nullable=False),
        sa.Column("installment_id", sa.BigInteger,
                  sa.ForeignKey("sale_installments.id", ondelete="SET NULL")),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("paid_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("kind", _enum("payment_kind"),
                  server_default="installment", nullable=False),
        sa.Column("recorded_by", sa.BigInteger, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("sale_payments_sale_idx", "sale_payments", ["sale_id"])
    op.create_index("sale_payments_installment_idx", "sale_payments", ["installment_id"])
    op.create_index("sale_payments_paid_at_idx", "sale_payments", ["paid_at"])

    # ── reminder_logs (one row per recipient per reminder; sent_at = when sent) ─
    op.create_table(
        "reminder_logs",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("sale_id", sa.BigInteger,
                  sa.ForeignKey("sales.id", ondelete="CASCADE"), nullable=False),
        sa.Column("installment_id", sa.BigInteger,
                  sa.ForeignKey("sale_installments.id", ondelete="SET NULL")),
        sa.Column("recipient_type", _enum("reminder_recipient"), nullable=False),
        sa.Column("recipient_phone", sa.Text, nullable=False),
        sa.Column("channel", _enum("reminder_channel"),
                  server_default="whatsapp", nullable=False),
        sa.Column("message", sa.Text, nullable=False, server_default=""),
        sa.Column("due_date", sa.Date, nullable=False),
        sa.Column("sent_at", sa.TIMESTAMP(timezone=True)),
        sa.Column("status", _enum("reminder_status"),
                  server_default="pending", nullable=False),
        sa.Column("provider_message_id", sa.Text),
        sa.Column("error", sa.Text),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("reminder_logs_sale_idx", "reminder_logs", ["sale_id"])
    op.create_index("reminder_logs_installment_idx", "reminder_logs", ["installment_id"])
    op.create_index("reminder_logs_due_idx", "reminder_logs", ["due_date"])
    op.create_index("reminder_logs_status_idx", "reminder_logs", ["status"])


def downgrade() -> None:
    for t in ("sales", "sale_installments", "users"):
        op.execute(f"DROP TRIGGER IF EXISTS {t}_set_updated_at ON {t}")
    op.drop_table("reminder_logs")
    op.drop_table("sale_payments")
    op.drop_table("sale_installments")
    op.drop_table("sales")
    op.drop_table("notifications")
    op.drop_table("user_modules")
    op.drop_table("users")
    op.drop_table("roles")
    op.execute("DELETE FROM modules WHERE code = 'user_management'")
    for name in reversed(list(ENUMS.keys())):
        op.execute(f"DROP TYPE IF EXISTS {name}")
