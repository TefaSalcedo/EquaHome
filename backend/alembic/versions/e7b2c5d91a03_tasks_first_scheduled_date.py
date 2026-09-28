"""tasks first_scheduled_date

Revision ID: e7b2c5d91a03
Revises: d4a1f02c8e5b
Create Date: 2026-09-27 19:40:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'e7b2c5d91a03'
down_revision = 'd4a1f02c8e5b'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('tasks', sa.Column('first_scheduled_date', sa.Date(), nullable=True))
    op.execute("UPDATE tasks SET first_scheduled_date = scheduled_date")
    op.alter_column('tasks', 'first_scheduled_date', nullable=False)


def downgrade() -> None:
    op.drop_column('tasks', 'first_scheduled_date')
