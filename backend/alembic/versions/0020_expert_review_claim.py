"""agronom tekshiruvi: ishni olish (claim), xulosa manbasi va qayta surat sababi (Agronom TZ Y01–Y03)

Revision ID: 0020
Revises: 0019
Create Date: 2026-10-31 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0020'
down_revision = '0019'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('diagnoses', sa.Column('review_claimed_by', sa.Uuid(), nullable=True))
    op.add_column('diagnoses', sa.Column('review_claimed_at', sa.DateTime(), nullable=True))
    op.add_column('diagnoses', sa.Column('expert_source', sa.String(length=500), nullable=True))
    op.add_column('diagnoses', sa.Column('retake_reason', sa.String(length=40), nullable=True))
    op.create_foreign_key('fk_diagnoses_claimed_by', 'diagnoses', 'users', ['review_claimed_by'], ['id'], ondelete='SET NULL')


def downgrade() -> None:
    op.drop_constraint('fk_diagnoses_claimed_by', 'diagnoses', type_='foreignkey')
    op.drop_column('diagnoses', 'retake_reason')
    op.drop_column('diagnoses', 'expert_source')
    op.drop_column('diagnoses', 'review_claimed_at')
    op.drop_column('diagnoses', 'review_claimed_by')
