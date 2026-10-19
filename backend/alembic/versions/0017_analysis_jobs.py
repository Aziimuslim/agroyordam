"""AI tahlil fon jarayoni (TZ A01)

Revision ID: 0017
Revises: 0016
Create Date: 2026-10-22 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0017'
down_revision = '0016'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'analysis_jobs',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('client_key', sa.String(64), nullable=False),
        sa.Column('status', sa.String(20), server_default='queued', nullable=False),
        sa.Column('image_url', sa.String(255), nullable=False),
        sa.Column('ext', sa.String(8), nullable=False),
        sa.Column('crop_id', sa.Uuid(), sa.ForeignKey('crops.id', ondelete='SET NULL'), nullable=True),
        sa.Column('plant_id', sa.Uuid(), sa.ForeignKey('plants.id', ondelete='SET NULL'), nullable=True),
        sa.Column('diagnosis_id', sa.Uuid(), sa.ForeignKey('diagnoses.id', ondelete='SET NULL'), nullable=True),
        sa.Column('error', sa.Text(), nullable=True),
        sa.Column('error_code', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.UniqueConstraint('user_id', 'client_key', name='uq_analysis_jobs_user_key'),
    )
    op.create_index('ix_analysis_jobs_user_id', 'analysis_jobs', ['user_id'])
    op.create_index('ix_analysis_jobs_status', 'analysis_jobs', ['status'])


def downgrade() -> None:
    op.drop_index('ix_analysis_jobs_status', 'analysis_jobs')
    op.drop_index('ix_analysis_jobs_user_id', 'analysis_jobs')
    op.drop_table('analysis_jobs')
