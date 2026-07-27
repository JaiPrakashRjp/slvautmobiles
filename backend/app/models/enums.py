"""Domain enums — values match the PostgreSQL enum types created in the migration."""
import enum


class Branch(str, enum.Enum):
    branch_1 = "branch_1"
    branch_2 = "branch_2"


class VehicleHand(str, enum.Enum):
    first_hand = "first_hand"
    second_hand = "second_hand"


class FuelType(str, enum.Enum):
    cng = "cng"
    lpg = "lpg"
    electric = "electric"


class Showroom(str, enum.Enum):
    amba = "amba"
    acetec = "acetec"
    khivraj = "khivraj"


class VehicleDocType(str, enum.Enum):
    rc = "rc"
    fc = "fc"
    insurance = "insurance"
    permit = "permit"
    others = "others"
    noc = "noc"
    prev_owner_id_proof = "prev_owner_id_proof"
    prev_owner_photo = "prev_owner_photo"


class InventoryStatus(str, enum.Enum):
    available = "available"
    reserved = "reserved"
    sold = "sold"
    on_rent = "on_rent"


class SaleStatus(str, enum.Enum):
    not_sold = "not_sold"
    sold = "sold"


class KycDocType(str, enum.Enum):
    aadhaar = "aadhaar"
    pan = "pan"
    dl = "dl"
    rental_agreement = "rental_agreement"
    photo = "photo"
    assurity_id_proof = "assurity_id_proof"


class EntityStatus(str, enum.Enum):
    pending_confirmation = "pending_confirmation"
    active = "active"
    rejected = "rejected"


class AccountStatus(str, enum.Enum):
    active = "active"
    suspended = "suspended"


class DepositType(str, enum.Enum):
    full_cash = "full_cash"
    down_payment = "down_payment"


class SaleLifecycle(str, enum.Enum):
    active = "active"
    closed = "closed"
    cancelled = "cancelled"
    seized = "seized"


class RentalLifecycle(str, enum.Enum):
    active = "active"        # rent ongoing, balance outstanding
    completed = "completed"  # fully collected + confirmed complete
    cancelled = "cancelled"  # rental reversed
    seized = "seized"        # vehicle repossessed from the renter


class InstallmentStatus(str, enum.Enum):
    pending = "pending"          # reminder set, not yet acted on
    in_progress = "in_progress"  # an admin took the call (locked)
    paid = "paid"                # payment approved
    cancelled = "cancelled"      # call made, no payment (deferred)
    overdue = "overdue"


class PaymentKind(str, enum.Enum):
    installment = "installment"
    early_payoff = "early_payoff"
    advance = "advance"


class ReminderRecipient(str, enum.Enum):
    customer = "customer"
    super_admin = "super_admin"


class ReminderChannel(str, enum.Enum):
    whatsapp = "whatsapp"
    sms = "sms"


class ReminderStatus(str, enum.Enum):
    pending = "pending"
    sent = "sent"
    failed = "failed"


class NotificationType(str, enum.Enum):
    verification_request = "verification_request"
    info = "info"


class NotificationEntity(str, enum.Enum):
    vehicle = "vehicle"
    customer = "customer"
    sale = "sale"
    rental = "rental"


def pg_enum(py_enum, name):
    """Helper: a native PG enum column type that references the type created by
    Alembic (so SQLAlchemy never tries to create/drop it)."""
    from sqlalchemy import Enum as SAEnum

    return SAEnum(
        py_enum,
        name=name,
        native_enum=True,
        create_type=False,
        values_callable=lambda e: [m.value for m in e],
    )
