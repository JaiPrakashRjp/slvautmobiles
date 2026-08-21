"""Personal-loan financer master — finance companies for PERSONAL loans.

Kept separate from vehicle financers and sale financers (each module has its own
list), per the requirement to bifurcate financers module-wise.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Identity, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class PersonalLoanFinancer(Base):
    __tablename__ = "personal_loan_financers"

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
