"""eslatma: takrorlash seriyasi, oldindan eslatish, bajarilgan vaqt (Tabiiy Agro S25/S26)

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-19 14:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0010'
down_revision = '0009'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('reminders', sa.Column('completed_at', sa.DateTime(), nullable=True))
    op.add_column('reminders', sa.Column('series_id', sa.Uuid(), nullable=True))
    op.add_column('reminders', sa.Column('repeat', sa.String(length=10), nullable=True))
    op.add_column('reminders', sa.Column('repeat_every', sa.SmallInteger(), nullable=True))
    op.add_column('reminders', sa.Column('repeat_until', sa.Date(), nullable=True))
    op.add_column('reminders', sa.Column('remind_before', sa.Integer(), nullable=True))
    op.create_index('ix_reminders_series_id', 'reminders', ['series_id'])


def downgrade() -> None:
    op.drop_index('ix_reminders_series_id', table_name='reminders')
    for col in ('remind_before', 'repeat_until', 'repeat_every', 'repeat', 'series_id', 'completed_at'):
        op.drop_column('reminders', col)
