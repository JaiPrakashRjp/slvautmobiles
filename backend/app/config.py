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


settings = Settings()
