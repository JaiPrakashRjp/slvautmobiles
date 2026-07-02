"""Global search across customers + vehicles (by name / phone / vehicle no)."""
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.vehicle import Vehicle
from app.schemas.search import SearchResult


class SearchService:
    @staticmethod
    def search(db: Session, q: str, *, limit: int = 20) -> list[SearchResult]:
        term = (q or "").strip()
        if not term:
            return []
        like = f"%{term}%"
        results: list[SearchResult] = []

        # customers — by name or phone
        customers = db.scalars(
            select(Customer)
            .where(
                or_(
                    Customer.first_name.ilike(like),
                    Customer.last_name.ilike(like),
                    Customer.phone.ilike(like),
                )
            )
            .order_by(Customer.created_at.desc())
            .limit(limit)
        ).all()
        for c in customers:
            name = f"{c.first_name} {c.last_name}".strip()
            results.append(
                SearchResult(
                    kind="customer", id=c.id, label=name, subtitle=c.phone
                )
            )

        # vehicles — by reg no / chassis / model
        vehicles = db.scalars(
            select(Vehicle)
            .where(
                or_(
                    Vehicle.reg_no.ilike(like),
                    Vehicle.chassis_no.ilike(like),
                    Vehicle.model.ilike(like),
                )
            )
            .order_by(Vehicle.created_at.desc())
            .limit(limit)
        ).all()
        for v in vehicles:
            label = v.reg_no or v.model or f"Vehicle #{v.id}"
            results.append(
                SearchResult(
                    kind="vehicle", id=v.id, label=label, subtitle=v.model or ""
                )
            )

        return results
