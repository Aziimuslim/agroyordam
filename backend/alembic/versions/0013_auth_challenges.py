"""bir martalik kod (auth_challenges) va qoidalarga rozilik (Tabiiy Agro S33–S36)

Revision ID: 0013
Revises: 0012
Create Date: 2026-10-20 12:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0013'
down_revision = '0012'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'auth_challenges',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('purpose', sa.String(length=20), nullable=False),
        sa.Column('channel', sa.String(length=10), nullable=False),
        sa.Column('destination', sa.String(length=150), nullable=False),
        sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=True),
        sa.Column('code_hash', sa.String(length=64), nullable=False),
        sa.Column('attempts', sa.SmallInteger(), nullable=False, server_default='0'),
        sa.Column('resends', sa.SmallInteger(), nullable=False, server_default='0'),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('resend_at', sa.DateTime(), nullable=False),
        sa.Column('consumed_at', sa.DateTime(), nullable=True),
        sa.Column('payload', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.func.now()),
    )
    op.create_index('ix_auth_challenges_destination', 'auth_challenges', ['destination'])
    op.add_column('users', sa.Column('terms_version', sa.String(length=40), nullable=True))
    op.add_column('users', sa.Column('terms_accepted_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'terms_accepted_at')
    op.drop_column('users', 'terms_version')
    op.drop_index('ix_auth_challenges_destination', table_name='auth_challenges')
    op.drop_table('auth_challenges')
