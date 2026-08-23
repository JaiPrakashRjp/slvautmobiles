"""Application settings loaded from environment / .env."""
import os

from dotenv import load_dotenv

# Load .env sitting at backend/python/.env (two levels up from this file).
load_dotenv()

#settings
class Settings:
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg2://postgres:postgres@localhost:5432/slv_auto",
    )
    APP_ENV: str = os.getenv("APP_ENV", "development")

    # Comma-separated list of allowed CORS origins. Defaults to "*" so local
    # development and the mobile APK keep working; set CORS_ORIGINS to the real
    # frontend domain(s) in production, e.g.
    #   CORS_ORIGINS=https://app.slvauto.com,https://admin.slvauto.com
    CORS_ORIGINS: list[str] = [
        o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()
    ]

    # ── Auth (signed bearer tokens) ──────────────────────────────────────────
    # JWT_SECRET MUST be set to a long random value in production; the insecure
    # default only exists so local dev runs without extra setup. Anyone who
    # knows the secret can mint tokens for any user/role, so keep it private.
    JWT_SECRET: str = os.getenv("JWT_SECRET", "dev-insecure-change-me")
    JWT_ALG: str = os.getenv("JWT_ALG", "HS256")
    # Token lifetime — 24 hours. A user stays signed in for a day (across app
    # restarts); after that the session expires and they must log in again. The
    # Logout button ends it immediately.
    JWT_EXPIRE_MINUTES: int = int(os.getenv("JWT_EXPIRE_MINUTES", str(60 * 24)))

    # ── WhatsApp (Meta Cloud API) ────────────────────────────────────────────
    # From the Meta app dashboard → WhatsApp → API Setup. The "API Setup" token
    # is temporary (~24h, for testing); use a System User token for production.
    # WHATSAPP_PHONE_NUMBER_ID is what the send API is called against; the actual
    # phone number is only for reference.
    WHATSAPP_TOKEN: str = os.getenv("WHATSAPP_TOKEN", "")
    WHATSAPP_PHONE_NUMBER_ID: str = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")
    WHATSAPP_BUSINESS_ACCOUNT_ID: str = os.getenv("WHATSAPP_BUSINESS_ACCOUNT_ID", "")
    # Approved template used for installment reminders (body vars: name, amount, date).
    WHATSAPP_REMINDER_TEMPLATE: str = os.getenv("WHATSAPP_REMINDER_TEMPLATE", "payment_reminder")
    WHATSAPP_REMINDER_LANG: str = os.getenv("WHATSAPP_REMINDER_LANG", "en_US")
    # Separate, rental-specific reminder template (rent collections read very
    # differently from an installment/loan reminder). Same 3 body vars so the
    # sender stays generic: {{1}} = customer name, {{2}} = rent amount,
    # {{3}} = due date. Approve a distinct template in Meta and set its name here.
    WHATSAPP_RENTAL_REMINDER_TEMPLATE: str = os.getenv(
        "WHATSAPP_RENTAL_REMINDER_TEMPLATE", "rent_reminder"
    )
    # NOTE: the approved rent_reminder template in Meta is language "en"
    # (not "en_US" like payment_reminder). A mismatch here → Meta error 132001
    # and every rental reminder logs as failed. Verified via a live test send.
    WHATSAPP_RENTAL_REMINDER_LANG: str = os.getenv(
        "WHATSAPP_RENTAL_REMINDER_LANG", "en"
    )
    # Personal-loan reminders all go to this one WhatsApp number (the office /
    # owner follows up), regardless of the loan. Change it via the env var.
    PERSONAL_LOAN_REMINDER_PHONE: str = os.getenv(
        "PERSONAL_LOAN_REMINDER_PHONE", "9741120927"
    )
    # Loan module EMI reminder template (body vars: {{1}} customer name,
    # {{2}} amount, {{3}} due date). Approve it in Meta and set the LANG to the
    # language you approved it in (a mismatch → Meta error 132001).
    WHATSAPP_LOAN_REMINDER_TEMPLATE: str = os.getenv(
        "WHATSAPP_LOAN_REMINDER_TEMPLATE", "loan_emi_reminder"
    )
    # Approved in Meta as plain "English" (en), NOT "English (US)" (en_US) — a
    # mismatch → Meta error 132001 and every loan reminder logs as failed.
    WHATSAPP_LOAN_REMINDER_LANG: str = os.getenv(
        "WHATSAPP_LOAN_REMINDER_LANG", "en"
    )
    # Personal-loan reminder template (body vars: {{1}} vehicle number,
    # {{2}} amount, {{3}} due date). Also approved as "English" (en).
    WHATSAPP_PERSONAL_LOAN_REMINDER_TEMPLATE: str = os.getenv(
        "WHATSAPP_PERSONAL_LOAN_REMINDER_TEMPLATE", "personal_loan_reminder"
    )
    WHATSAPP_PERSONAL_LOAN_REMINDER_LANG: str = os.getenv(
        "WHATSAPP_PERSONAL_LOAN_REMINDER_LANG", "en"
    )

    @property
    def whatsapp_enabled(self) -> bool:
        return bool(self.WHATSAPP_TOKEN and self.WHATSAPP_PHONE_NUMBER_ID)

    # ── Firebase (FCM push) ──────────────────────────────────────────────────
    # Path to the Admin SDK service-account JSON (git-ignored). Relative paths
    # resolve from the backend working dir; set an absolute path on the server.
    FIREBASE_CREDENTIALS_FILE: str = os.getenv(
        "FIREBASE_CREDENTIALS_FILE", "firebase-service-account.json"
    )

    @property
    def fcm_enabled(self) -> bool:
        return os.path.exists(self.FIREBASE_CREDENTIALS_FILE)


settings = Settings()
