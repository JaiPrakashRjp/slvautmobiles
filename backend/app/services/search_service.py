"""Global search across customers + vehicles (by name / phone / vehicle no)."""
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.enums import RentalLifecycle, SaleLifecycle
from app.models.rental import Rental
from app.models.sale import Sale
from app.models.vehicle import Vehicle
from app.schemas.search import SearchResult, SearchVehicle


class SearchService:
    @staticmethod
    def search(
        db: Session, q: str, *, limit: int = 20, silo_ids: list[int] | None = None
    ) -> list[SearchResult]:
        term = (q or "").strip()
        if not term:
            return []
        like = f"%{term}%"
        results: list[SearchResult] = []

        # customers — by name or phone
        customer_stmt = select(Customer).where(
            or_(
                Customer.first_name.ilike(like),
                Customer.last_name.ilike(like),
                Customer.phone.ilike(like),
            )
        )
        if silo_ids is not None:
            customer_stmt = customer_stmt.where(Customer.created_by.in_(silo_ids))
        customers = db.scalars(
            customer_stmt.order_by(Customer.created_at.desc()).limit(limit)
        ).all()
        for c in customers:
            name = f"{c.first_name} {c.last_name}".strip()
            # Vehicles linked to this customer via SALES or RENTALS (skip cancelled),
            # deduped by vehicle id so sale + rental customers both show their vehicle.
            veh_map: dict = {}
            sale_stmt = (
                select(
                    Vehicle.id, Vehicle.reg_no, Vehicle.chassis_no,
                    Vehicle.model, Sale.sale_status,
                )
                .join(Sale, Sale.vehicle_id == Vehicle.id)
                .where(
                    Sale.customer_id == c.id,
                    Sale.sale_status != SaleLifecycle.cancelled,
                )
            )
            if silo_ids is not None:
                sale_stmt = sale_stmt.where(Sale.created_by.in_(silo_ids))
            sale_rows = db.execute(sale_stmt.order_by(Sale.created_at.desc())).all()
            for r in sale_rows:
                veh_map[r.id] = SearchVehicle(
                    id=r.id,
                    label=r.chassis_no or r.reg_no or r.model or f"Vehicle #{r.id}",
                    subtitle=" · ".join(
                        p for p in (r.reg_no, r.model,
                                    r.sale_status.value if r.sale_status else None) if p
                    ),
                )
            rent_stmt = (
                select(
                    Vehicle.id, Vehicle.reg_no, Vehicle.chassis_no,
                    Vehicle.model, Rental.rental_status,
                )
                .join(Rental, Rental.vehicle_id == Vehicle.id)
                .where(
                    Rental.customer_id == c.id,
                    Rental.rental_status != RentalLifecycle.cancelled,
                )
            )
            if silo_ids is not None:
                rent_stmt = rent_stmt.where(Rental.created_by.in_(silo_ids))
            rent_rows = db.execute(rent_stmt.order_by(Rental.created_at.desc())).all()
            for r in rent_rows:
                veh_map.setdefault(r.id, SearchVehicle(
                    id=r.id,
                    label=r.chassis_no or r.reg_no or r.model or f"Vehicle #{r.id}",
                    subtitle=" · ".join(
                        p for p in (r.reg_no, r.model,
                                    r.rental_status.value if r.rental_status else None) if p
                    ),
                ))
            veh = list(veh_map.values())
            count = len(veh)
            subtitle = c.phone if count == 0 else f"{c.phone} · {count} vehicle{'s' if count != 1 else ''}"
            results.append(
                SearchResult(
                    kind="customer", id=c.id, label=name, subtitle=subtitle, vehicles=veh
                )
            )

        # vehicles — by reg no / chassis / model
        vehicle_stmt = select(Vehicle).where(
            or_(
                Vehicle.reg_no.ilike(like),
                Vehicle.chassis_no.ilike(like),
                Vehicle.model.ilike(like),
            )
        )
        if silo_ids is not None:
            vehicle_stmt = vehicle_stmt.where(Vehicle.created_by.in_(silo_ids))
        vehicles = db.scalars(
            vehicle_stmt.order_by(Vehicle.created_at.desc()).limit(limit)
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
