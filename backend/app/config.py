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


settings = Settings()
