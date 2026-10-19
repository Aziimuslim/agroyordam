"""katalog: o'simlik toifasi, dori toifasi/turi/yorliq tasdig'i, manba va yangilangan sana (Tabiiy Agro S17–S22)

Revision ID: 0011
Revises: 0010
Create Date: 2026-10-19 18:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0011'
down_revision = '0010'
branch_labels = None
depends_on = None

# seed nomlari bo'yicha boshlang'ich tasnif (app/seed.py bilan bir xil); boshqa yozuvlar bo'sh qoladi
PLANT_CATEGORY = {'Pomidor': 'vegetable', 'Kartoshka': 'vegetable', 'Bolgar qalampiri': 'vegetable', 'Bodring': 'vegetable', 'Qovoq': 'vegetable', 'Olma': 'fruit', 'Shaftoli': 'fruit', 'Olcha': 'fruit', 'Uzum': 'vine', "Makkajo'xori": 'grain', 'Qulupnay': 'berry'}
MEDICINE_META = {'Mis oksixlorid': ('fungicide', 'active'), 'Bordo suyuqligi': ('fungicide', 'mixture'), 'Oltingugurt kukuni': ('fungicide', 'active'), 'Mankoseb': ('fungicide', 'active'), 'Trichoderma (bio)': ('biological', 'active'), 'Bioinsektitsid (Bt)': ('biological', 'active'), 'Abamektin': ('insecticide', 'active'), 'Tebukonazol': ('fungicide', 'active'), 'Azoksistrobin': ('fungicide', 'active'), 'Imidakloprid': ('insecticide', 'active')}


def upgrade() -> None:
    op.add_column('plants', sa.Column('category', sa.String(length=20), nullable=True))
    op.add_column('diseases', sa.Column('source', sa.Text(), nullable=True))
    op.add_column('diseases', sa.Column('updated_at', sa.DateTime(), nullable=True))
    op.add_column('medicines', sa.Column('category', sa.String(length=20), nullable=True))
    op.add_column('medicines', sa.Column('kind', sa.String(length=10), nullable=True))
    op.add_column('medicines', sa.Column('label_verified', sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column('medicines', sa.Column('source', sa.Text(), nullable=True))
    op.add_column('medicines', sa.Column('updated_at', sa.DateTime(), nullable=True))
    op.execute("UPDATE diseases SET updated_at = created_at")
    op.execute("UPDATE medicines SET updated_at = created_at")
    plants = sa.table('plants', sa.column('name', sa.String), sa.column('category', sa.String))
    for name, cat in PLANT_CATEGORY.items():
        op.execute(plants.update().where(plants.c.name == name).values(category=cat))
    meds = sa.table('medicines', sa.column('name', sa.String), sa.column('category', sa.String), sa.column('kind', sa.String))
    for name, (cat, kind) in MEDICINE_META.items():
        op.execute(meds.update().where(meds.c.name == name).values(category=cat, kind=kind))


def downgrade() -> None:
    for col in ('updated_at', 'source', 'label_verified', 'kind', 'category'):
        op.drop_column('medicines', col)
    op.drop_column('diseases', 'updated_at')
    op.drop_column('diseases', 'source')
    op.drop_column('plants', 'category')
