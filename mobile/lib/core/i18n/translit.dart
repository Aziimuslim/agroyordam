/// O'zbek lotin → kirill (rasmiy imlo qoidalari asosida).
/// Brend, qisqartma va {0} kabi o'rinbosarlar o'zgarmaydi.
library;

const _keep = {'AgroYordam', 'AGROYORDAM', 'AI', "AI'ni", 'SMS', 'PDF', 'APK', 'FastAPI', 'Wi-Fi', "Wi-Fi'da", 'Payme', 'Click', 'PlantVillage', 'TDAU', 'URL'};

const _single = {
  'a': 'а', 'b': 'б', 'd': 'д', 'e': 'е', 'f': 'ф', 'g': 'г', 'h': 'ҳ', 'i': 'и', 'j': 'ж', 'k': 'к', 'l': 'л', 'm': 'м',
  'n': 'н', 'o': 'о', 'p': 'п', 'q': 'қ', 'r': 'р', 's': 'с', 't': 'т', 'u': 'у', 'v': 'в', 'x': 'х', 'y': 'й', 'z': 'з',
  'c': 'ц', 'w': 'в',
};

const _vowels = 'aeiouAEIOU';
final _apos = RegExp("['ʻʼ‘’`]");
final _token = RegExp(r"\{\d+\}|[A-Za-z'ʻʼ‘’`\-]+|[^A-Za-z'ʻʼ‘’`{]+|\{");

String toCyrillic(String s) {
  final out = StringBuffer();
  for (final m in _token.allMatches(s)) {
    final w = m.group(0)!;
    if (!RegExp('[A-Za-z]').hasMatch(w) || w.startsWith('{') || _keep.contains(w) || _keep.contains(w.replaceAll(RegExp(r"[.,!?:;]+$"), ''))) {
      out.write(w);
    } else {
      out.write(_word(w));
    }
  }
  return out.toString();
}

bool _isApos(String c) => _apos.hasMatch(c);

String _word(String w) {
  final b = StringBuffer();
  final n = w.length;
  final allCaps = w.length > 1 && w == w.toUpperCase();
  String cased(String cyr, String src) {
    if (src.isEmpty) return cyr;
    final up = src[0] != src[0].toLowerCase();
    if (!up) return cyr;
    return allCaps ? cyr.toUpperCase() : cyr[0].toUpperCase() + cyr.substring(1);
  }

  var i = 0;
  while (i < n) {
    final c = w[i];
    final lc = c.toLowerCase();
    final next = i + 1 < n ? w[i + 1] : '';
    final nl = next.toLowerCase();
    final prev = i > 0 ? w[i - 1] : '';
    // o' / g'
    if ((lc == 'o' || lc == 'g') && next.isNotEmpty && _isApos(next)) {
      b.write(cased(lc == 'o' ? 'ў' : 'ғ', c));
      i += 2;
      continue;
    }
    if (lc == 's' && nl == 'h') {
      b.write(cased('ш', c));
      i += 2;
      continue;
    }
    if (lc == 'c' && nl == 'h') {
      b.write(cased('ч', c));
      i += 2;
      continue;
    }
    if (lc == 'y' && 'aoue'.contains(nl) && nl.isNotEmpty) {
      // ya, yo, yu, ye (yo' — "йў")
      final after = i + 2 < n ? w[i + 2] : '';
      if (nl == 'o' && _isApos(after)) {
        b.write(cased('й', c));
        i += 1;
        continue;
      }
      final m = {'a': 'я', 'o': 'ё', 'u': 'ю', 'e': 'е'}[nl]!;
      b.write(cased(m, c));
      i += 2;
      continue;
    }
    if (lc == 'e') {
      // So'z boshida yoki unlidan keyin — "э"
      final start = i == 0 || prev == '-';
      final afterVowel = prev.isNotEmpty && _vowels.contains(prev);
      b.write(cased(start || afterVowel ? 'э' : 'е', c));
      i += 1;
      continue;
    }
    if (_isApos(c)) {
      // Atoqli otdan keyingi qo'shimcha (Premium'ga) — belgisiz; aks holda tutuq belgisi
      final stem = w.substring(0, i);
      if (stem.length >= 5 && stem[0] != stem[0].toLowerCase()) {
        i += 1;
        continue;
      }
      b.write(prev.isNotEmpty && RegExp('[A-Za-z]').hasMatch(prev) && next.isNotEmpty ? 'ъ' : c);
      i += 1;
      continue;
    }
    final m = _single[lc];
    b.write(m == null ? c : cased(m, c));
    i += 1;
  }
  return b.toString();
}
