"""obuna: to'lov vaqti va qaytarilgan vaqt — to'lov natijasi obuna holatidan ajratiladi (Tabiiy Agro S29/S30)

Revision ID: 0012
Revises: 0011
Create Date: 2026-10-20 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0012'
down_revision = '0011'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('subscriptions', sa.Column('paid_at', sa.DateTime(), nullable=True))
    op.add_column('subscriptions', sa.Column('refunded_at', sa.DateTime(), nullable=True))
    # Mavjud yozuvlar: provayder tasdig'i bo'lgan va muddat berilgan (yoki faol/tugagan) obunalar to'langan hisoblanadi.
    # Muvaffaqiyatsiz to'lovda muddat yozilmaydi, shuning uchun u to'langan deb belgilanmaydi.
    op.execute(
        "UPDATE subscriptions SET paid_at = started_at WHERE external_txn_id IS NOT NULL "
        "AND (status IN ('active', 'expired') OR expires_at IS NOT NULL)"
    )
    # Avtomatik qayta yechish amalga oshirilmagan — va'da qilinmasin
    op.execute("UPDATE subscriptions SET auto_renew = false")


def downgrade() -> None:
    op.drop_column('subscriptions', 'refunded_at')
    op.drop_column('subscriptions', 'paid_at')
