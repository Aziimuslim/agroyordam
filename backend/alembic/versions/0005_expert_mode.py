"""agronom rejimi: AI muqobil tashxislari va agronom ish vaqti

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-11 18:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('diagnoses', sa.Column('ai_top', sa.JSON(), nullable=True))
    op.add_column('users', sa.Column('work_hours', sa.String(length=100), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'work_hours')
    op.drop_column('diagnoses', 'ai_top')
