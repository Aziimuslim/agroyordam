"""dataset: diagnoses.ai_label, foydalanuvchi fikri va mutaxassis tekshiruvi

Revision ID: 0003
Revises: 0002
Create Date: 2026-09-24 08:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('diagnoses', sa.Column('ai_label', sa.String(length=150), nullable=True))
    op.add_column('diagnoses', sa.Column('user_feedback', sa.Boolean(), nullable=True))
    op.add_column('diagnoses', sa.Column('review_status', sa.String(length=20), server_default='pending', nullable=False))
    op.add_column('diagnoses', sa.Column('verified_label', sa.String(length=150), nullable=True))
    op.add_column('diagnoses', sa.Column('reviewed_by', sa.Uuid(), nullable=True))
    op.add_column('diagnoses', sa.Column('reviewed_at', sa.DateTime(), nullable=True))
    op.create_foreign_key('fk_diagnoses_reviewed_by_users', 'diagnoses', 'users', ['reviewed_by'], ['id'], ondelete='SET NULL')
    op.create_index('ix_diagnoses_review_status', 'diagnoses', ['review_status'])
    op.create_index('ix_diagnoses_verified_label', 'diagnoses', ['verified_label'])
    # Eski tashxislar: ai_label ni bog'langan kasallikdan tiklaymiz
    op.execute(
        "UPDATE diagnoses SET ai_label = diseases.ai_label FROM diseases "
        "WHERE diagnoses.disease_id = diseases.id AND diagnoses.ai_label IS NULL"
    )


def downgrade() -> None:
    op.drop_index('ix_diagnoses_verified_label', table_name='diagnoses')
    op.drop_index('ix_diagnoses_review_status', table_name='diagnoses')
    op.drop_constraint('fk_diagnoses_reviewed_by_users', 'diagnoses', type_='foreignkey')
    for col in ('reviewed_at', 'reviewed_by', 'verified_label', 'review_status', 'user_feedback', 'ai_label'):
        op.drop_column('diagnoses', col)
