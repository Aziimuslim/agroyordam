"""admin panel: harakatlar jurnali, sozlamalar, bilimlar bazasi o'zgarishini qaytarish

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-11 20:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0006'
down_revision = '0005'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'audit_log',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('actor_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('action', sa.String(length=40), nullable=False),
        sa.Column('target_id', sa.Uuid(), nullable=True),
        sa.Column('summary', sa.String(length=500), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
    )
    op.create_index('ix_audit_log_actor_id', 'audit_log', ['actor_id'])
    op.create_index('ix_audit_log_target_id', 'audit_log', ['target_id'])
    op.create_table(
        'app_settings',
        sa.Column('key', sa.String(length=60), primary_key=True),
        sa.Column('value', sa.String(length=255), nullable=False),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
    )
    op.add_column('catalog_changes', sa.Column('before', sa.JSON(), nullable=True))
    op.add_column('catalog_changes', sa.Column('reverted_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('catalog_changes', 'reverted_at')
    op.drop_column('catalog_changes', 'before')
    op.drop_table('app_settings')
    op.drop_index('ix_audit_log_target_id', 'audit_log')
    op.drop_index('ix_audit_log_actor_id', 'audit_log')
    op.drop_table('audit_log')
