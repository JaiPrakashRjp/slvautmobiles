# SLV Auto Consultant — Backend (Python)

FastAPI + SQLAlchemy + Alembic over PostgreSQL. Single backend (no Node).

## Layout (layered)

```
backend/
├─ app/
│   ├─ models/        Model layer    — SQLAlchemy ORM (Module, Vehicle, VehicleDocument)
│   ├─ dao/           DAO layer      — pure DB access, no business rules
│   ├─ services/      Service layer  — business logic incl. the role-gate
│   ├─ controllers/   API layer      — FastAPI routers (endpoints)
│   ├─ schemas/       pydantic request/response models
│   ├─ config.py      settings from .env
│   ├─ db.py          engine / session / Base
│   └─ main.py        FastAPI app
├─ alembic/           migrations  (versions/0001_init_vehicles.py)
├─ alembic.ini
├─ requirements.txt
└─ .env               DATABASE_URL, APP_ENV
```

Each module (vehicles, customers, …) gets its own file in each layer.

## Data model (vehicles module)

- **`modules`** — the three business modules (auto_sale / rental / loan), seeded.
- **`vehicles`** — vehicle details, linked to a module. Role-gate columns
  (`status`, `created_by`, `confirmed_by`, `confirmed_at`, `rejection_reason`).
- **`vehicle_documents`** — every file for a vehicle (RC/FC/Insurance/Permit/
  Others/NOC + previous-owner ID proof & photo), **stored as binary (`BYTEA`)**
  so one DB backup contains everything.

## Setup

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows  (source .venv/bin/activate on mac/linux)
pip install -r requirements.txt

# create the database (once)
createdb slv_auto               # or: psql -c "CREATE DATABASE slv_auto;"

# edit .env if your Postgres user/password/db differ, then run migrations
alembic upgrade head

# run the API
uvicorn app.main:app --reload
```

Open http://localhost:8000/docs for the interactive API.

## Endpoints (vehicles)

| Method | Path | Purpose |
|---|---|---|
| GET | `/vehicles` | list (filters: `status`, `branch`) |
| GET | `/vehicles/{id}` | one vehicle (with documents) |
| POST | `/vehicles?created_by=&actor_role=` | create (role-gate sets status) |
| POST | `/vehicles/{id}/confirm?by_user_id=` | Super Admin approve |
| POST | `/vehicles/{id}/reject?reason=&by_user_id=` | reject with reason |
| DELETE | `/vehicles/{id}` | delete |
| POST | `/vehicles/{id}/documents` | upload a file (multipart: `doc_type`, `file`) |
| GET | `/vehicles/documents/{doc_id}` | download a file |

## TODO

- Auth: `actor_role` / `created_by` / `by_user_id` are passed explicitly for now;
  wire them from the authenticated user when the users module lands.
- Add the customers / sales / rentals / loans modules (same layering).
