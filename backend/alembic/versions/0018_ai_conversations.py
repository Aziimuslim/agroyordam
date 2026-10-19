"""AI suhbatlar: bir nechta suhbat, qisman javob, javobni savolga bog'lash (TZ S09/S10)

Revision ID: 0018
Revises: 0017
Create Date: 2026-10-23 10:00:00
"""
import uuid

from alembic import op
import sqlalchemy as sa


revision = '0018'
down_revision = '0017'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'ai_conversations',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('user_id', sa.Uuid(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('title', sa.String(100), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.func.now(), nullable=True),
    )
    op.create_index('ix_ai_conversations_user_id', 'ai_conversations', ['user_id'])
    op.add_column('ai_chat_messages', sa.Column('conversation_id', sa.Uuid(), nullable=True))
    op.add_column('ai_chat_messages', sa.Column('reply_to_id', sa.Uuid(), nullable=True))
    op.add_column('ai_chat_messages', sa.Column('status', sa.String(20), server_default='done', nullable=False))
    op.create_foreign_key('fk_ai_msg_conversation', 'ai_chat_messages', 'ai_conversations', ['conversation_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key('fk_ai_msg_reply_to', 'ai_chat_messages', 'ai_chat_messages', ['reply_to_id'], ['id'], ondelete='SET NULL')
    op.create_index('ix_ai_chat_messages_conversation_id', 'ai_chat_messages', ['conversation_id'])

    # Eski yagona tarix — har foydalanuvchi uchun bitta "Oldingi suhbat"ga o'tkaziladi
    bind = op.get_bind()
    rows = bind.execute(sa.text(
        "SELECT user_id, MIN(created_at), MAX(created_at) FROM ai_chat_messages GROUP BY user_id")).fetchall()
    conv = sa.table('ai_conversations', sa.column('id', sa.Uuid()), sa.column('user_id', sa.Uuid()), sa.column('title', sa.String()),
                    sa.column('created_at', sa.DateTime()), sa.column('updated_at', sa.DateTime()))
    msgs = sa.table('ai_chat_messages', sa.column('user_id', sa.Uuid()), sa.column('conversation_id', sa.Uuid()))
    for user_id, first, last in rows:
        cid = uuid.uuid4()
        bind.execute(conv.insert().values(id=cid, user_id=user_id, title='Oldingi suhbat', created_at=first, updated_at=last))
        bind.execute(msgs.update().where(msgs.c.user_id == user_id).values(conversation_id=cid))


def downgrade() -> None:
    op.drop_index('ix_ai_chat_messages_conversation_id', 'ai_chat_messages')
    op.drop_constraint('fk_ai_msg_reply_to', 'ai_chat_messages', type_='foreignkey')
    op.drop_constraint('fk_ai_msg_conversation', 'ai_chat_messages', type_='foreignkey')
    op.drop_column('ai_chat_messages', 'status')
    op.drop_column('ai_chat_messages', 'reply_to_id')
    op.drop_column('ai_chat_messages', 'conversation_id')
    op.drop_table('ai_conversations')
