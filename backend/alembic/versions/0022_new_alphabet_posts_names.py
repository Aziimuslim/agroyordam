"""Post, izoh va foydalanuvchi ismlari yangi lotin harflarida (ó, ǵ, ş, ç).

Login (username, email, telefon) va shaxsiy xabarlar o'zgarmaydi. Havola, email, @eslatma o'zgarmaydi.

Revision ID: 0022
Revises: 0021
"""
import sqlalchemy as sa
from alembic import op

from app.core.alphabet import to_new_latin, to_old_latin

revision = '0022'
down_revision = '0021'
branch_labels = None
depends_on = None

TABLES = {
    'posts': ('title', 'content'),
    'comments': ('content',),
    'users': ('full_name',),
}


def _convert(fn) -> None:
    bind = op.get_bind()
    for table, cols in TABLES.items():
        names = ', '.join('"%s"' % c for c in ('id',) + cols)
        for r in bind.execute(sa.text(f"SELECT {names} FROM {table}")).mappings().all():
            changed = {c: fn(r[c]) for c in cols if r[c] and fn(r[c]) != r[c]}
            if changed:
                sets = ', '.join('"%s" = :%s' % (c, c) for c in changed)
                bind.execute(sa.text(f'UPDATE {table} SET {sets} WHERE "id" = :k_id'), {**changed, 'k_id': r['id']})


def upgrade() -> None:
    _convert(to_new_latin)


def downgrade() -> None:
    _convert(to_old_latin)
