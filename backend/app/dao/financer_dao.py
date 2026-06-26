"""Data Access Object for financers — pure persistence, no business rules."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.financer import Financer


class FinancerDAO:
    @staticmethod
    def list(db: Session) -> list[Financer]:
        stmt = select(Financer).order_by(Financer.name)
        return list(db.scalars(stmt).all())

    @staticmethod
    def get(db: Session, financer_id: int) -> Financer | None:
        return db.get(Financer, financer_id)

    @staticmethod
    def add(db: Session, financer: Financer) -> Financer:
        db.add(financer)
        db.flush()
        return financer

    @staticmethod
    def delete(db: Session, financer: Financer) -> None:
        db.delete(financer)
