"""ekin surati (Tabiiy Agro S05)

Revision ID: 0008
Revises: 0007
Create Date: 2026-10-18 22:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0008'
down_revision = '0007'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('crops', sa.Column('photo_url', sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column('crops', 'photo_url')
