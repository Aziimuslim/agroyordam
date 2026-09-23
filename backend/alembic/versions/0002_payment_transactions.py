"""payment transactions

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-23 06:45:14.049103
"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('payment_transactions',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('provider', sa.String(length=20), nullable=False),
    sa.Column('provider_txn_id', sa.String(length=100), nullable=False),
    sa.Column('subscription_id', sa.Uuid(), nullable=False),
    sa.Column('amount', sa.Numeric(precision=14, scale=2), nullable=False),
    sa.Column('state', sa.Integer(), server_default='1', nullable=False),
    sa.Column('reason', sa.Integer(), nullable=True),
    sa.Column('provider_time', sa.BigInteger(), nullable=True),
    sa.Column('create_time', sa.BigInteger(), nullable=False),
    sa.Column('perform_time', sa.BigInteger(), server_default='0', nullable=False),
    sa.Column('cancel_time', sa.BigInteger(), server_default='0', nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
    sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
    sa.ForeignKeyConstraint(['subscription_id'], ['subscriptions.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('provider', 'provider_txn_id')
    )
    op.create_index(op.f('ix_payment_transactions_subscription_id'), 'payment_transactions', ['subscription_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_payment_transactions_subscription_id'), table_name='payment_transactions')
    op.drop_table('payment_transactions')
