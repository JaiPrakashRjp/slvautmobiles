"""Data Access Object for sale financers — pure persistence, no business rules."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.sale_financer import SaleFinancer


class SaleFinancerDAO:
    @staticmethod
    def list(db: Session) -> list[SaleFinancer]:
        stmt = select(SaleFinancer).order_by(SaleFinancer.name)
        return list(db.scalars(stmt).all())

    @staticmethod
    def get(db: Session, financer_id: int) -> SaleFinancer | None:
        return db.get(SaleFinancer, financer_id)

    @staticmethod
    def add(db: Session, financer: SaleFinancer) -> SaleFinancer:
        db.add(financer)
        db.flush()
        return financer

    @staticmethod
    def delete(db: Session, financer: SaleFinancer) -> None:
        db.delete(financer)
