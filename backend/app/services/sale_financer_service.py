"""Business logic for sale financers (separate master from vehicle financers)."""
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.sale_financer_dao import SaleFinancerDAO
from app.models.sale_financer import SaleFinancer
from app.schemas.financer import FinancerCreate


class SaleFinancerService:
    @staticmethod
    def list(db: Session) -> list[SaleFinancer]:
        return SaleFinancerDAO.list(db)

    @staticmethod
    def get(db: Session, financer_id: int) -> SaleFinancer:
        financer = SaleFinancerDAO.get(db, financer_id)
        if financer is None:
            raise HTTPException(status_code=404, detail="Sale financer not found")
        return financer

    @staticmethod
    def create(db: Session, data: FinancerCreate) -> SaleFinancer:
        financer = SaleFinancer(name=data.name.strip())
        SaleFinancerDAO.add(db, financer)
        db.commit()
        return SaleFinancerDAO.get(db, financer.id)

    @staticmethod
    def delete(db: Session, financer_id: int) -> None:
        financer = SaleFinancerService.get(db, financer_id)
        SaleFinancerDAO.delete(db, financer)
        db.commit()
