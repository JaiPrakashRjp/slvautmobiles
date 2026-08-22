"""Loan seizure (repossession) columns on loans.

seize_stage: NULL | 'pending' (admin requested) | 'seized' (confirmed). The rest
record who/when/why and any cancel remark. Cancelling clears the stage so the
loan continues with the customer.

Revision ID: 0030
Revises: 0029
"""
from __future__ import annotations

from typing import Union

import sqlalchemy as sa
from alembic import op

revision: str = "0030"
down_revision: Union[str, None] = "0029"
branch_labels = None
depends_on = None

_COLS = [
    ("seize_stage", sa.Text),
    ("seize_reason", sa.Text),
    ("seized_by", sa.BigInteger),
    ("seized_at", sa.DateTime(timezone=False)),
    ("seize_confirmed_by", sa.BigInteger),
    ("seize_confirmed_at", sa.DateTime(timezone=False)),
    ("seize_cancel_remarks", sa.Text),
]


def upgrade() -> None:
    for name, coltype in _COLS:
        op.add_column("loans", sa.Column(name, coltype))


def downgrade() -> None:
    for name, _ in reversed(_COLS):
        op.drop_column("loans", name)
