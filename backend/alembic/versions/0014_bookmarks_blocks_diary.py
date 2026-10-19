"""saqlanganlar, bloklash, kundalik (rasmlar, kuzatuv sanasi, versiya) — Tabiiy Agro A02/A04/A08

Revision ID: 0014
Revises: 0013
Create Date: 2026-10-20 15:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0014'
down_revision = '0013'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'bookmarks',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('kind', sa.String(length=10), nullable=False),
        sa.Column('target_id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.func.now()),
        sa.UniqueConstraint('user_id', 'kind', 'target_id'),
    )
    op.create_index('ix_bookmarks_user_id', 'bookmarks', ['user_id'])
    op.create_table(
        'user_blocks',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('blocker_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('blocked_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.func.now()),
        sa.UniqueConstraint('blocker_id', 'blocked_id'),
    )
    op.create_index('ix_user_blocks_blocker_id', 'user_blocks', ['blocker_id'])
    op.create_index('ix_user_blocks_blocked_id', 'user_blocks', ['blocked_id'])
    op.add_column('crop_logs', sa.Column('images', sa.JSON(), nullable=True))
    op.add_column('crop_logs', sa.Column('observed_at', sa.Date(), nullable=True))
    op.add_column('crop_logs', sa.Column('version', sa.Integer(), nullable=False, server_default='1'))
    op.add_column('crop_logs', sa.Column('updated_at', sa.DateTime(), nullable=True, server_default=sa.func.now()))
    op.execute("UPDATE crop_logs SET observed_at = CAST(created_at AS DATE)")


def downgrade() -> None:
    for col in ('updated_at', 'version', 'observed_at', 'images'):
        op.drop_column('crop_logs', col)
    op.drop_index('ix_user_blocks_blocked_id', table_name='user_blocks')
    op.drop_index('ix_user_blocks_blocker_id', table_name='user_blocks')
    op.drop_table('user_blocks')
    op.drop_index('ix_bookmarks_user_id', table_name='bookmarks')
    op.drop_table('bookmarks')
