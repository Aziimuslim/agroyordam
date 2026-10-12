"""profil: tuman, manzil, o'zi haqida, xo'jalik (dehqon), ta'lim va yo'nalishlar (agronom)

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-12 21:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0007'
down_revision = '0006'
branch_labels = None
depends_on = None

COLUMNS = [
    ('district', sa.String(length=100)),
    ('address', sa.String(length=255)),
    ('about', sa.Text()),
    ('experience_years', sa.SmallInteger()),
    ('farm_type', sa.String(length=20)),
    ('farm_area', sa.Float()),
    ('main_crops', sa.JSON()),
    ('irrigation', sa.String(length=20)),
    ('education', sa.String(length=255)),
    ('skills', sa.JSON()),
]


def upgrade() -> None:
    for name, type_ in COLUMNS:
        op.add_column('users', sa.Column(name, type_, nullable=True))


def downgrade() -> None:
    for name, _ in reversed(COLUMNS):
        op.drop_column('users', name)
