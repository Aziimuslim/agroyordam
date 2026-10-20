"""mayda bandlar: tashxis fikri sababi (S08), chat xabari ustidan shikoyat (S16)

Revision ID: 0019
Revises: 0018
Create Date: 2026-10-24 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0019'
down_revision = '0018'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('diagnoses', sa.Column('feedback_reason', sa.Text(), nullable=True))
    op.add_column('reports', sa.Column('message_id', sa.Uuid(), nullable=True))
    op.create_foreign_key('fk_reports_message', 'reports', 'messages', ['message_id'], ['id'], ondelete='CASCADE')


def downgrade() -> None:
    op.drop_constraint('fk_reports_message', 'reports', type_='foreignkey')
    op.drop_column('reports', 'message_id')
    op.drop_column('diagnoses', 'feedback_reason')
