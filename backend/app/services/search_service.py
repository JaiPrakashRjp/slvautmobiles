"""Global search across customers + vehicles (by name / phone / vehicle no)."""
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.enums import SaleLifecycle
from app.models.sale import Sale
from app.models.vehicle import Vehicle
from app.schemas.search import SearchResult, SearchVehicle


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
            # Every vehicle sold to this customer (via their sales; skip cancelled).
            veh_rows = db.execute(
                select(
                    Vehicle.id, Vehicle.reg_no, Vehicle.chassis_no,
                    Vehicle.model, Sale.sale_status,
                )
                .join(Sale, Sale.vehicle_id == Vehicle.id)
                .where(
                    Sale.customer_id == c.id,
                    Sale.sale_status != SaleLifecycle.cancelled,
                )
                .order_by(Sale.created_at.desc())
            ).all()
            veh = [
                SearchVehicle(
                    id=r.id,
                    label=r.chassis_no or r.reg_no or r.model or f"Vehicle #{r.id}",
                    subtitle=" · ".join(
                        p for p in (r.reg_no, r.model, r.sale_status.value if r.sale_status else None) if p
                    ),
                )
                for r in veh_rows
            ]
            count = len(veh)
            subtitle = c.phone if count == 0 else f"{c.phone} · {count} vehicle{'s' if count != 1 else ''}"
            results.append(
                SearchResult(
                    kind="customer", id=c.id, label=name, subtitle=subtitle, vehicles=veh
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
            label = v.chassis_no or v.reg_no or v.model or f"Vehicle #{v.id}"
            subtitle = " · ".join(p for p in (v.reg_no, v.model) if p)
            results.append(
                SearchResult(
                    kind="vehicle", id=v.id, label=label, subtitle=subtitle
                )
            )

        return results
