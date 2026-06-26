"""Business logic for financers."""
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.dao.financer_dao import FinancerDAO
from app.models.financer import Financer
from app.schemas.financer import FinancerCreate


class FinancerService:
    @staticmethod
    def list(db: Session) -> list[Financer]:
        return FinancerDAO.list(db)

    @staticmethod
    def get(db: Session, financer_id: int) -> Financer:
        financer = FinancerDAO.get(db, financer_id)
        if financer is None:
            raise HTTPException(status_code=404, detail="Financer not found")
        return financer

    @staticmethod
    def create(db: Session, data: FinancerCreate) -> Financer:
        financer = Financer(name=data.name.strip())
        FinancerDAO.add(db, financer)
        db.commit()
        return FinancerDAO.get(db, financer.id)

    @staticmethod
    def delete(db: Session, financer_id: int) -> None:
        financer = FinancerService.get(db, financer_id)
        FinancerDAO.delete(db, financer)
        db.commit()
