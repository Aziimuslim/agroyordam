import glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from dartstr import literals, unescape
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')) + '/'
EXTRA = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba',
         'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
         # Server xabarlari (api_exception.dart: tr(detail))
         "AI Yordamchi uchun kunlik bepul limit tugadi. Premium'ga o'ting.", "AI xizmati vaqtincha ishlamayapti", "Agronom topilmadi",
         "Arizangiz ko'rib chiqilmoqda", "Avtorizatsiya talab qilinadi", "Bo'sh xabar", "Bu savolga boshqa agronom javob bermoqda",
         "Bu tashxis allaqachon tekshirilgan", "Bu tashxisni agronom allaqachon tekshirgan", "Dori topilmadi", "Ekin topilmadi",
         "Email yoki telefon band", "Eslatma topilmadi", "Faol obuna yo'q", "Faqat JPG, PNG yoki WEBP rasm yuklash mumkin",
         "Faqat muallif tahrirlay oladi", "Fayl haqiqiy rasm emas", "Foydalanuvchi faol emas", "Foydalanuvchi topilmadi yoki bloklangan",
         "Foydalanuvchi topilmadi", "Hali agronom javob bermagan", "Havola yaroqsiz yoki muddati o'tgan",
         "Havola yaroqsiz, ishlatilgan yoki muddati o'tgan", "Hisob bloklangan", "Izoh topilmadi",
         "Juda ko'p urinish. Birozdan so'ng qayta urinib ko'ring.", "Login yoki parol noto'g'ri", "O'simlik turi topilmadi",
         "O'zingiz bilan suhbat ochib bo'lmaydi", "O'zingizga obuna bo'lolmaysiz", "Ob-havo ma'lumoti vaqtincha mavjud emas",
         "Obuna topilmadi", "Post topilmadi", "Ruxsat yo'q", "Savol topilmadi", "Savol yopilgan", "Siz allaqachon agronomsiz",
         "Suhbat topilmadi", "Tashxis topilmadi", "Token yaroqsiz yoki allaqachon ishlatilgan", "Token yaroqsiz yoki muddati o'tgan",
         "Topilmadi", "Xabar bo'sh", "Xabar topilmadi", "Yozuv o'chirilgan", "Email yoki telefon raqamidan kamida bittasi kerak",
         # Tarif imkoniyatlari (backend payment_service.PREMIUM_FEATURES, premium_screen: tr(f))
         "AI tashxis — cheksiz", "\"Mening bog'im\" — cheksiz ekin", "AI Yordamchi — cheksiz va ustuvor javob", "Batafsil sog'liq tarixi"]


def text(lit):
    assert not lit.interps, lit.parts
    return ''.join(unescape(v) for k, v in lit.parts)


def _scan(src, path, keys):
    lits = literals(src)
    i = 0
    while i < len(lits):
        lit = lits[i]
        for expr in lit.interps:  # ichma-ich: '${a ? tr('X') : ''}'
            _scan(expr, path, keys)
        if re.search(r'\btrf?\(\s*$', src[:lit.start]) and not lit.interps:
            s, j = text(lit), i
            while j + 1 < len(lits) and src[lits[j].end:lits[j + 1].start].strip() == '':
                j += 1
                s += text(lits[j])
            keys.setdefault(s, path)
            i = j + 1
            continue
        i += 1


def collect():
    keys = {}
    for f in sorted(glob.glob(ROOT + 'lib/**/*.dart', recursive=True)):
        if '/i18n/' in f:
            continue
        _scan(open(f).read(), f.replace(ROOT, ''), keys)
    for e in EXTRA:
        keys.setdefault(e, 'lib/core/utils/format.dart')
    return keys


HERE = os.path.dirname(__file__)
LANGS = ['ru', 'en', 'kaa']


def build():
    """tool/i18n/<til>.json → lib/core/i18n/strings_<til>.dart"""
    for lang in LANGS:
        d = json.load(open(os.path.join(HERE, lang + '.json'), encoding='utf-8'))
        name = 'strings' + lang.capitalize()
        lines = [f"// Avtomatik yaratilgan: python3 tool/i18n/i18n.py build — qo'lda tahrirlamang, tool/i18n/{lang}.json ni o'zgartiring.",
                 '// ignore_for_file: lines_longer_than_80_chars', f'const {name} = <String, String>{{']
        for k in sorted(d):
            lines.append(f'  {json.dumps(k, ensure_ascii=False)}: {json.dumps(d[k], ensure_ascii=False)},'.replace('$', r'\$'))
        lines.append('};\n')
        open(os.path.join(ROOT, 'lib/core/i18n', f'strings_{lang}.dart'), 'w', encoding='utf-8').write('\n'.join(lines))
    print('build ok')


def check():
    """Koddagi tr()/trf() kalitlari har bir tilda bormi."""
    keys = collect()
    bad = 0
    for lang in LANGS:
        d = json.load(open(os.path.join(HERE, lang + '.json'), encoding='utf-8'))
        miss = [k for k in keys if k not in d]
        for k in miss:
            print(f'{lang}: tarjima yo\'q: {k!r}  ({keys[k]})')
        bad += len(miss)
    print('kalitlar:', len(keys), 'yetishmaydi:', bad)
    return bad


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    if cmd == 'build':
        build()
    else:
        sys.exit(1 if check() else 0)
