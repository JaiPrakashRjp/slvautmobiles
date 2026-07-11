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
    # Token lifetime. Long-lived (30 days) because the mobile app has no refresh
    # flow — a user stays signed in until it expires or they sign out.
    JWT_EXPIRE_MINUTES: int = int(os.getenv("JWT_EXPIRE_MINUTES", str(60 * 24 * 30)))

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
