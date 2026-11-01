"""Rasmiy yangi alifbo harflari: 0.8.26–0.8.27 da yozilgan ó/ǵ → ö/ğ (OʻRQ–1184, 2026-yil 21-oktyabr).

0021 va 0022 qamrab olgan ustunlar qayta o'tkaziladi; to_new_latin idempotent, ó/ǵ ni ö/ğ ga almashtiradi.

Revision ID: 0023
Revises: 0022
"""
import sqlalchemy as sa
from alembic import op

from app.core.alphabet import to_new_latin

revision = '0023'
down_revision = '0022'
branch_labels = None
depends_on = None

TABLES = {
    'plants': (('id',), ('name', 'description', 'care_info')),
    'diseases': (('id',), ('name', 'description', 'symptoms', 'causes', 'treatment', 'prevention')),
    'medicines': (('id',), ('name', 'active_ingredient', 'description', 'usage', 'precautions')),
    'disease_medicines': (('disease_id', 'medicine_id'), ('recommendation',)),
    'diagnoses': (('id',), ('symptoms', 'causes', 'recommendations')),
    'notifications': (('id',), ('title', 'body')),
    'reminders': (('id',), ('title', 'description')),
    'crops': (('id',), ('name',)),
    'posts': (('id',), ('title', 'content')),
    'comments': (('id',), ('content',)),
    'users': (('id',), ('full_name',)),
}


def upgrade() -> None:
    bind = op.get_bind()
    for table, (keys, cols) in TABLES.items():
        names = ', '.join('"%s"' % c for c in keys + cols)
        for r in bind.execute(sa.text(f"SELECT {names} FROM {table}")).mappings().all():
            changed = {c: to_new_latin(r[c]) for c in cols if r[c] and to_new_latin(r[c]) != r[c]}
            if changed:
                sets = ', '.join('"%s" = :%s' % (c, c) for c in changed)
                where = ' AND '.join('"%s" = :k_%s' % (k, k) for k in keys)
                bind.execute(sa.text(f"UPDATE {table} SET {sets} WHERE {where}"), {**changed, **{f"k_{k}": r[k] for k in keys}})


def downgrade() -> None:
    pass  # ó/ǵ ga qaytarish kerak emas
