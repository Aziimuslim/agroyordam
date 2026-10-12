"""Dart manbasidagi satr literallarini topish (izohlar, interpolatsiya, raw, uch qo'shtirnoq)."""
import re

ID = re.compile(r'[A-Za-z0-9_]')


class Lit:
    def __init__(self, start, end, raw, quote, parts):
        self.start, self.end, self.raw, self.quote, self.parts = start, end, raw, quote, parts
        # parts: list of ('t', source_text) | ('e', expr_source)

    @property
    def interps(self):
        return [p[1] for p in self.parts if p[0] == 'e']


def unescape(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            n = s[i + 1]
            out.append({'n': '\n', 't': '\t', 'r': '\r'}.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def _expr_end(src, i):
    """src[i] is just after '${' — return index of matching '}'."""
    depth = 0
    while i < len(src):
        c = src[i]
        if c in '\'"':
            lit, j = _string(src, i, False)
            i = j
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            if depth == 0:
                return i
            depth -= 1
        i += 1
    raise ValueError('unterminated interpolation')


def _string(src, i, raw):
    q = src[i]
    triple = src[i:i + 3] == q * 3
    ql = 3 if triple else 1
    quote = q * ql
    j = i + ql
    parts, buf = [], []
    while j < len(src):
        if src.startswith(quote, j):
            if buf:
                parts.append(('t', ''.join(buf)))
            return (quote, parts), j + ql
        c = src[j]
        if not raw and c == '\\':
            buf.append(src[j:j + 2])
            j += 2
            continue
        if not raw and c == '$':
            if src[j + 1:j + 2] == '{':
                k = _expr_end(src, j + 2)
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', src[j + 2:k]))
                j = k + 1
                continue
            m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[j + 1:])
            if m:
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', m.group(0)))
                j += 1 + len(m.group(0))
                continue
        if c == '\n' and not triple:
            raise ValueError(f'newline in string at {i}')
        buf.append(c)
        j += 1
    raise ValueError('unterminated string')


def literals(src):
    """Yuqori darajadagi literallar (interpolatsiya ichidagilar emas)."""
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith('//', i):
            i = src.find('\n', i)
            i = n if i < 0 else i
            continue
        if src.startswith('/*', i):
            i = src.find('*/', i) + 2
            continue
        c = src[i]
        if c in '\'"':
            raw = i > 0 and src[i - 1] == 'r' and (i < 2 or not ID.match(src[i - 2]))
            start = i - 1 if raw else i
            (quote, parts), j = _string(src, i, raw)
            out.append(Lit(start, j, raw, quote, parts))
            i = j
            continue
        i += 1
    return out
