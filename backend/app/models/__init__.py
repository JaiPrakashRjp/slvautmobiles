"""Model layer. Importing here registers all tables on Base.metadata."""
from app.models.customer import Customer
from app.models.customer_document import CustomerDocument
from app.models.module import Module
from app.models.notification import Notification
from app.models.reminder_log import ReminderLog
from app.models.role import Role
from app.models.sale import Sale
from app.models.sale_financer import SaleFinancer
from app.models.sale_installment import SaleInstallment
from app.models.sale_payment import SalePayment
from app.models.user import User
from app.models.user_module import UserModule
from app.models.vehicle import Vehicle
from app.models.vehicle_document import VehicleDocument

__all__ = [
    "Module",
    "Role",
    "User",
    "UserModule",
    "Customer",
    "CustomerDocument",
    "Vehicle",
    "VehicleDocument",
    "Sale",
    "SaleFinancer",
    "SaleInstallment",
    "SalePayment",
    "ReminderLog",
    "Notification",
]
