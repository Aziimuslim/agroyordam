"""bildirishnoma turlari sozlamasi (Tabiiy Agro A05)

Revision ID: 0015
Revises: 0014
Create Date: 2026-10-20 18:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0015'
down_revision = '0014'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users', sa.Column('notification_prefs', sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'notification_prefs')
