"""Model layer. Importing here registers all tables on Base.metadata.

Every model MUST be listed here. SQLAlchemy resolves string ForeignKey targets
(e.g. ForeignKey("personal_loans.id")) lazily against Base.metadata the first
time any object is flushed — if a referenced table's model was never imported
anywhere in the running process, that flush raises NoReferencedTableError. The
standalone cron jobs (app/jobs/run_*.py) each import a narrow slice of
services, not every model, so they must `import app.models` up front to be
safe regardless of which tables that particular job happens to touch.
"""
from app.models.customer import Customer
from app.models.customer_document import CustomerDocument
from app.models.device_token import DeviceToken
from app.models.financer import Financer
from app.models.loan import Loan
from app.models.loan_emi import LoanEmi
from app.models.loan_payment import LoanPayment
from app.models.loan_payment_document import LoanPaymentDocument
from app.models.module import Module
from app.models.notification import Notification
from app.models.personal_loan import PersonalLoan
from app.models.personal_loan_emi import PersonalLoanEmi
from app.models.personal_loan_financer import PersonalLoanFinancer
from app.models.reminder_log import ReminderLog
from app.models.rental import Rental
from app.models.rental_installment import RentalInstallment
from app.models.rental_payment import RentalPayment
from app.models.rental_payment_document import RentalPaymentDocument
from app.models.role import Role
from app.models.sale import Sale
from app.models.sale_financer import SaleFinancer
from app.models.sale_installment import SaleInstallment
from app.models.sale_payment import SalePayment
from app.models.sale_payment_document import SalePaymentDocument
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
    "Financer",
    "Sale",
    "SaleFinancer",
    "SaleInstallment",
    "SalePayment",
    "SalePaymentDocument",
    "Rental",
    "RentalInstallment",
    "RentalPayment",
    "RentalPaymentDocument",
    "Loan",
    "LoanEmi",
    "LoanPayment",
    "LoanPaymentDocument",
    "PersonalLoan",
    "PersonalLoanEmi",
    "PersonalLoanFinancer",
    "ReminderLog",
    "Notification",
    "DeviceToken",
]
