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
final _token = RegExp(r"\{\d+\}|[A-Za-zÖöĞğŞşÇçÓóǴǵ'ʻʼ‘’`\-]+|[^A-Za-zÖöĞğŞşÇçÓóǴǵ'ʻʼ‘’`{]+|\{");

String toCyrillic(String s) {
  final out = StringBuffer();
  for (final m in _token.allMatches(s)) {
    final w = m.group(0)!;
    if (!RegExp('[A-Za-zÖöĞğŞşÇç]').hasMatch(w) || w.startsWith('{') || _keep.contains(w) || _keep.contains(w.replaceAll(RegExp(r"[.,!?:;]+$"), ''))) {
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
    // Yangi harflar: ö ğ ş ç
    const nw = {'ö': 'ў', 'ğ': 'ғ', 'ş': 'ш', 'ç': 'ч', 'ó': 'ў', 'ǵ': 'ғ'};
    if (nw.containsKey(lc)) {
      b.write(cased(nw[lc]!, c));
      i += 1;
      continue;
    }
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

// ---------------------------------------------------------------------------
// Yangi o'zbek lotin harflari: oʻ → ö, gʻ → ğ, sh → ş, ch → ç (backend/app/core/alphabet.py bilan bir xil).

const _keepNew = {
  'agroyordam', 'payme', 'click', 'telegram', 'whatsapp', 'google', 'chrome', 'android', 'iphone', 'push', 'fastapi',
  'plantvillage', 'wi-fi', 'flash', 'dashboard', 'chat', 'check', 'match', 'sha', 'hash', 'cherry', 'peach', 'scorch',
  'squash', 'trichoderma', 'cichoracearum', 'chrysanthemi', 'sclerotiorum', 'fusarium', 'erysiphe', 'pseudomonas', 'xanthomonas',
};
final _skipNew = RegExp(r"(https?://\S+|www\.\S+|[\w.+-]+@[\w-]+\.[\w.]+|\{\d+\}|@\w+)");
final _wordNew = RegExp(r"[A-Za-zÖöĞğŞşÇç'ʻʼ‘’`\-]+");
final _sciNew = RegExp(r'(ph|th|rh|aceae|ae$)', caseSensitive: false);
final _hasApos = RegExp("['ʻʼ‘’`]");

String _newWord(String w) {
  final lw = w.toLowerCase().replaceAll(RegExp(r'^-+|-+$'), '');
  final base = lw.replaceAll(RegExp("['ʻʼ‘’`].*\$"), '');
  if (_keepNew.contains(lw) || _keepNew.contains(base)) return w;
  if ((lw.contains('ch') || lw.contains('sh')) && _sciNew.hasMatch(lw) && !_hasApos.hasMatch(lw) && lw != 'shira') return w;
  final up = w.length > 1 && w.toUpperCase() == w && RegExp('[A-Za-z]').hasMatch(w);
  final out = StringBuffer();
  var i = 0;
  while (i < w.length) {
    final c = w[i];
    final nx = i + 1 < w.length ? w[i + 1] : '';
    final lc = c.toLowerCase();
    final isUp = c != lc;
    if ((lc == 'o' || lc == 'g') && nx.isNotEmpty && _isApos(nx)) {
      out.write(lc == 'o' ? (isUp ? 'Ö' : 'ö') : (isUp ? 'Ğ' : 'ğ'));
      i += 2;
      continue;
    }
    if ((lc == 's' || lc == 'c') && nx.toLowerCase() == 'h') {
      out.write(lc == 's' ? (isUp ? 'Ş' : 'ş') : (isUp ? 'Ç' : 'ç'));
      i += 2;
      continue;
    }
    out.write(c);
    i += 1;
  }
  final r = out.toString();
  return up ? r.toUpperCase() : r;
}

/// O'zbekcha matnni yangi lotin harflariga o'tkazadi. Havola, email, {0}, brend va lotincha ilmiy nomlar o'zgarmaydi.
String toNewLatin(String s) {
  if (s.isEmpty) return s;
  // 0.8.26–0.8.27 dagi ó/ǵ → rasmiy ö/ğ
  s = s.replaceAll('ó', 'ö').replaceAll('Ó', 'Ö').replaceAll('ǵ', 'ğ').replaceAll('Ǵ', 'Ğ');
  final out = StringBuffer();
  var last = 0;
  for (final m in _skipNew.allMatches(s)) {
    out.write(s.substring(last, m.start).replaceAllMapped(_wordNew, (x) => _newWord(x.group(0)!)));
    out.write(m.group(0));
    last = m.end;
  }
  out.write(s.substring(last).replaceAllMapped(_wordNew, (x) => _newWord(x.group(0)!)));
  return out.toString();
}

/// Yangi harflardan amaldagi lotinga: ö → oʻ (o'), ğ → g', ş → sh, ç → ch. "Lotin (amaldagi)" tanlanganda server matni uchun.
String toOldLatin(String s) {
  if (s.isEmpty || !RegExp('[ÖöĞğŞşÇçÓóǴǵ]').hasMatch(s)) return s;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    final nx = i + 1 < s.length ? s[i + 1] : '';
    final nextUp = nx.isNotEmpty && nx.toUpperCase() == nx && nx.toLowerCase() != nx;
    switch (c) {
      case 'ö' || 'ó':
        b.write("o'");
      case 'Ö' || 'Ó':
        b.write("O'");
      case 'ğ' || 'ǵ':
        b.write("g'");
      case 'Ğ' || 'Ǵ':
        b.write("G'");
      case 'ş':
        b.write('sh');
      case 'Ş':
        b.write(nextUp ? 'SH' : 'Sh');
      case 'ç':
        b.write('ch');
      case 'Ç':
        b.write(nextUp ? 'CH' : 'Ch');
      default:
        b.write(c);
    }
  }
  return b.toString();
}

/// Qidiruv kaliti: kichik harf + yangi yozuv — "shira", "şira", "ШИРА"siz ham bir xil topiladi.
String searchKey(String s) => toNewLatin(s.toLowerCase());
