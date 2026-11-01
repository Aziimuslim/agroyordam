"""Bazadagi o'zbekcha matnlar yangi lotin harflarida: oʻ → ó, gʻ → ǵ, sh → ş, ch → ç.

Qamrov: katalog (o'simlik, kasallik, dori, tavsiyalar), tizim matnlari (tashxis belgilari/tavsiyalari,
bildirishnomalar, eslatmalar) va ekin nomlari. Foydalanuvchi yozgan post, izoh, shaxsiy xabar, ism va
login o'zgarmaydi. Ilmiy nomlar, ai_label, havolalar o'zgarmaydi (app/core/alphabet.py).

Revision ID: 0021
Revises: 0020
"""
import sqlalchemy as sa
from alembic import op

from app.core.alphabet import to_new_latin, to_old_latin

revision = '0021'
down_revision = '0020'
branch_labels = None
depends_on = None

# jadval → (kalit ustunlar, matn ustunlari)
TABLES = {
    'plants': (('id',), ('name', 'description', 'care_info')),
    'diseases': (('id',), ('name', 'description', 'symptoms', 'causes', 'treatment', 'prevention')),
    'medicines': (('id',), ('name', 'active_ingredient', 'description', 'usage', 'precautions')),
    'disease_medicines': (('disease_id', 'medicine_id'), ('recommendation',)),
    'diagnoses': (('id',), ('symptoms', 'causes', 'recommendations')),
    'notifications': (('id',), ('title', 'body')),
    'reminders': (('id',), ('title', 'description')),
    'crops': (('id',), ('name',)),
}


def _convert(fn) -> None:
    bind = op.get_bind()
    for table, (keys, cols) in TABLES.items():
        names = ', '.join('"%s"' % c for c in keys + cols)
        rows = bind.execute(sa.text(f"SELECT {names} FROM {table}")).mappings().all()
        for r in rows:
            changed = {}
            for c in cols:
                v = r[c]
                if v:
                    nv = fn(v)
                    if nv != v:
                        changed[c] = nv
            if not changed:
                continue
            sets = ', '.join(f'"{c}" = :{c}' for c in changed)
            where = ' AND '.join(f'"{k}" = :k_{k}' for k in keys)
            bind.execute(sa.text(f"UPDATE {table} SET {sets} WHERE {where}"),
                         {**changed, **{f"k_{k}": r[k] for k in keys}})


def upgrade() -> None:
    _convert(to_new_latin)


def downgrade() -> None:
    _convert(to_old_latin)
