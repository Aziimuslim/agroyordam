"""agronom roli: arizalar, tekshirish navbati, savollar, bilimlar bazasi jurnali

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-11 16:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users', sa.Column('specialization', sa.String(length=200), nullable=True))
    op.add_column('users', sa.Column('accepting_questions', sa.Boolean(), server_default='true', nullable=False))

    op.add_column('diagnoses', sa.Column('review_requested', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('diagnoses', sa.Column('review_note', sa.Text(), nullable=True))
    op.add_column('diagnoses', sa.Column('expert_comment', sa.Text(), nullable=True))
    op.create_index('ix_diagnoses_review_requested', 'diagnoses', ['review_requested'])

    op.create_table(
        'expert_applications',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('specialization', sa.String(length=200), nullable=False),
        sa.Column('experience_years', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('about', sa.Text(), nullable=True),
        sa.Column('document_url', sa.String(length=255), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='pending'),
        sa.Column('reason', sa.String(length=255), nullable=True),
        sa.Column('reviewed_by', sa.Uuid(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('reviewed_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
    )
    op.create_index('ix_expert_applications_user_id', 'expert_applications', ['user_id'])
    op.create_index('ix_expert_applications_status', 'expert_applications', ['status'])

    op.create_table(
        'questions',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('crop_id', sa.Uuid(), sa.ForeignKey('crops.id', ondelete='SET NULL'), nullable=True),
        sa.Column('diagnosis_id', sa.Uuid(), sa.ForeignKey('diagnoses.id', ondelete='SET NULL'), nullable=True),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('body', sa.Text(), nullable=True),
        sa.Column('image_url', sa.String(length=255), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='new'),
        sa.Column('expert_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('rating', sa.SmallInteger(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
    )
    op.create_index('ix_questions_user_id', 'questions', ['user_id'])
    op.create_index('ix_questions_status', 'questions', ['status'])
    op.create_index('ix_questions_expert_id', 'questions', ['expert_id'])

    op.create_table(
        'question_messages',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('question_id', sa.Uuid(), sa.ForeignKey('questions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('sender_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('body', sa.Text(), nullable=True),
        sa.Column('medicine_id', sa.Uuid(), sa.ForeignKey('medicines.id', ondelete='SET NULL'), nullable=True),
        sa.Column('image_url', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
    )
    op.create_index('ix_question_messages_question_id', 'question_messages', ['question_id'])

    op.create_table(
        'catalog_changes',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('entity', sa.String(length=20), nullable=False),
        sa.Column('entity_id', sa.Uuid(), nullable=True),
        sa.Column('action', sa.String(length=20), nullable=False),
        sa.Column('summary', sa.String(length=255), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
    )
    op.create_index('ix_catalog_changes_user_id', 'catalog_changes', ['user_id'])


def downgrade() -> None:
    op.drop_table('catalog_changes')
    op.drop_table('question_messages')
    op.drop_table('questions')
    op.drop_table('expert_applications')
    op.drop_index('ix_diagnoses_review_requested', table_name='diagnoses')
    for col in ('expert_comment', 'review_note', 'review_requested'):
        op.drop_column('diagnoses', col)
    op.drop_column('users', 'accepting_questions')
    op.drop_column('users', 'specialization')
