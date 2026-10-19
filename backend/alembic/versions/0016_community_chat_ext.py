"""jamoat va chat kengaytmasi: 5 rasm, izohga javob, yetkazildi, ovozsiz/yashirish (TZ S12, S13, S15, S16)

Revision ID: 0016
Revises: 0015
Create Date: 2026-10-21 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0016'
down_revision = '0015'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('posts', sa.Column('image_urls', sa.JSON(), nullable=True))
    op.add_column('comments', sa.Column('parent_id', sa.Uuid(), nullable=True))
    op.add_column('comments', sa.Column('reply_to_id', sa.Uuid(), nullable=True))
    op.add_column('comments', sa.Column('deleted_at', sa.DateTime(), nullable=True))
    op.create_foreign_key('fk_comments_parent', 'comments', 'comments', ['parent_id'], ['id'], ondelete='SET NULL')
    op.create_foreign_key('fk_comments_reply_to', 'comments', 'comments', ['reply_to_id'], ['id'], ondelete='SET NULL')
    op.create_index('ix_comments_parent_id', 'comments', ['parent_id'])
    op.add_column('messages', sa.Column('image_urls', sa.JSON(), nullable=True))
    op.add_column('messages', sa.Column('delivered_at', sa.DateTime(), nullable=True))
    # mavjud o'qilgan xabarlar yetkazilgan ham hisoblanadi
    op.execute("UPDATE messages SET delivered_at = created_at WHERE is_read")
    op.add_column('conversation_participants', sa.Column('muted', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('conversation_participants', sa.Column('hidden_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('conversation_participants', 'hidden_at')
    op.drop_column('conversation_participants', 'muted')
    op.drop_column('messages', 'delivered_at')
    op.drop_column('messages', 'image_urls')
    op.drop_index('ix_comments_parent_id', 'comments')
    op.drop_constraint('fk_comments_reply_to', 'comments', type_='foreignkey')
    op.drop_constraint('fk_comments_parent', 'comments', type_='foreignkey')
    op.drop_column('comments', 'deleted_at')
    op.drop_column('comments', 'reply_to_id')
    op.drop_column('comments', 'parent_id')
    op.drop_column('posts', 'image_urls')
