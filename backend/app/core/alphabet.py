"""O'zbek lotin yozuvini yangi harflarga o'tkazish: oʻ → ö, gʻ → ğ, sh → ş, ch → ç.

Rasmiy alifbo: OʻRQ–1184 (2026-yil 21-oktyabr), 28 harf + tutuq belgisi; "ng" o'zgarmaydi.

Brendlar, qisqartmalar, havolalar, email, {0} kabi o'rinbosarlar va lotincha ilmiy nomlar o'zgarmaydi.
Funksiya idempotent: yangi yozuvdagi matn qayta o'tkazilsa o'zgarmaydi.
"""
from __future__ import annotations

import re

# O'zgarmaydigan so'zlar (brend, texnik atama, ilmiy nom qismlari) — kichik harfda
KEEP = {
    "agroyordam", "payme", "click", "telegram", "whatsapp", "google", "chrome", "android", "iphone", "push",
    "fastapi", "plantvillage", "wi-fi", "flash", "dashboard", "chat", "check", "match", "sha", "hash",
    "cherry", "peach", "scorch", "squash", "trichoderma", "cichoracearum", "chrysanthemi", "sclerotiorum", "fusarium", "erysiphe", "pseudomonas", "xanthomonas",
}
_APOS = "'ʻʼ‘’`"
_URL = re.compile(r"(https?://\S+|www\.\S+|[\w.+-]+@[\w-]+\.[\w.]+|\{\d+\}|@\w+)")
_WORD = re.compile(r"[A-Za-zÖöĞğŞşÇç" + _APOS + r"\-]+")
# Lotincha ilmiy nom belgilari (ph, th, rh, ae, oe, -us/-um/-ae bilan tugash va h.k.)
_SCI = re.compile(r"(ph|th|rh|aceae|ae$)", re.I)


def _case(src: str, new_lower: str, new_upper: str, whole_upper: bool) -> str:
    if src[0].isupper():
        return new_upper
    return new_lower


def _word(w: str) -> str:
    lw = w.lower().strip("-")
    base = re.sub(r"[" + _APOS + r"].*$", "", lw)
    if lw in KEEP or base in KEEP:
        return w
    # Ilmiy (lotincha) so'z: sh/ch bo'lsa-yu o'zbekcha emas — tegmaymiz
    if ("ch" in lw or "sh" in lw) and _SCI.search(lw) and not re.search("[" + _APOS + "]", lw) and lw not in ("shira",):
        return w
    up = len(w) > 1 and w.upper() == w and any(ch.isalpha() for ch in w)
    out = []
    i, n = 0, len(w)
    while i < n:
        c = w[i]
        nx = w[i + 1] if i + 1 < n else ""
        lc = c.lower()
        if lc in "og" and nx and nx in _APOS:
            out.append(("Ö" if lc == "o" else "Ğ") if c.isupper() else ("ö" if lc == "o" else "ğ"))
            i += 2
            continue
        if lc in "sc" and nx.lower() == "h":
            # s'h / s‘h (alohida tovush) — o'zgarmaydi; bu holat apostrof bilan yoziladi va bu yerga kelmaydi
            out.append(("Ş" if lc == "s" else "Ç") if c.isupper() else ("ş" if lc == "s" else "ç"))
            i += 2
            continue
        out.append(c)
        i += 1
    r = "".join(out)
    return r.upper() if up else r


# 0.8.26–0.8.27 da xato ishlatilgan ó/ǵ — rasmiy ö/ğ ga
_LEGACY = str.maketrans({"ó": "ö", "Ó": "Ö", "ǵ": "ğ", "Ǵ": "Ğ"})


def to_new_latin(text: str | None) -> str | None:
    """Matndagi o'zbekcha so'zlarni yangi harflarga o'tkazadi; boshqa qismlar o'zgarmaydi."""
    if not text:
        return text
    text = text.translate(_LEGACY)
    parts = _URL.split(text)
    res = []
    for k, part in enumerate(parts):
        if k % 2 == 1:  # havola / email / o'rinbosar
            res.append(part)
            continue
        res.append(_WORD.sub(lambda m: _word(m.group(0)), part))
    return "".join(res)


_OLD = str.maketrans({"ö": "o'", "Ö": "O'", "ğ": "g'", "Ğ": "G'", "ó": "o'", "Ó": "O'", "ǵ": "g'", "Ǵ": "G'", "ş": "sh", "Ş": "Sh", "ç": "ch", "Ç": "Ch"})


def to_old_latin(text: str) -> str:
    return text.translate(_OLD)


def search_variants(q: str) -> list[str]:
    """Qidiruv uchun: matn eski yoki yangi yozuvda bo'lsa ham topilsin."""
    new = to_new_latin(q) or q
    return list(dict.fromkeys([q, new, to_old_latin(q)]))
