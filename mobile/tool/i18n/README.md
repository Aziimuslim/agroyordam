# Ilova tillari

Manba matnlar koddagi o'zbek lotin matnining o'zi: `tr("Saqlash")`, `trf('{0} kun oldin', [n])`.

| Til | Qanday ishlaydi |
|---|---|
| O'zbekcha (lotin) | manba matn |
| Ўзбекча (кирилл) | avtomatik transliteratsiya (`lib/core/i18n/translit.dart`), lug'at kerak emas |
| Русский, English, Qaraqalpaqsha | `ru.json`, `en.json`, `kaa.json` lug'atlari |

Yangi matn qo'shganda:

```bash
python3 tool/i18n/i18n.py check   # qaysi kalitlarga tarjima yo'q
# ru.json / en.json / kaa.json ga qo'shing
python3 tool/i18n/i18n.py build   # lib/core/i18n/strings_*.dart ni qayta yaratadi
```

CI ikkalasini ham tekshiradi. Lug'atda topilmagan matn o'zbekcha ko'rinadi.
Serverdan kelgan kontent (ma'lumotnoma, ob-havo maslahati) hozircha o'zbekcha; kirill rejimida `trData()` bilan o'girish mumkin.
