"""FastAPI application entry point."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.controllers.auth_controller import router as auth_router
from app.controllers.customer_controller import router as customers_router
from app.controllers.device_controller import router as devices_router
from app.controllers.financer_controller import router as financers_router
from app.controllers.notification_controller import router as notifications_router
from app.controllers.report_controller import router as reports_router
from app.controllers.sale_controller import router as sales_router
from app.controllers.sale_financer_controller import router as sale_financers_router
from app.controllers.search_controller import router as search_router
from app.controllers.user_controller import router as users_router
from app.controllers.vehicle_controller import router as vehicles_router
from app.controllers.version_controller import router as version_router
from app.controllers.whatsapp_controller import router as whatsapp_router

app = FastAPI(title="SLV Auto Consultant API", version="0.1.0")

# CORS: the Flutter app (web build, or any origin during development) calls this
# API from a different origin, so allow cross-origin requests. Origins come from
# the CORS_ORIGINS env var (comma-separated); defaults to "*" for local dev and
# the mobile APK. Set it to the real frontend domain(s) in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(vehicles_router)
app.include_router(customers_router)
app.include_router(sales_router)
app.include_router(notifications_router)
app.include_router(reports_router)
app.include_router(financers_router)
app.include_router(devices_router)
app.include_router(sale_financers_router)
app.include_router(whatsapp_router)
app.include_router(search_router)
app.include_router(version_router)


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}
