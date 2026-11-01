import 'strings_en.dart';
import 'strings_kaa.dart';
import 'strings_ru.dart';
import 'translit.dart';

/// Ilova tillari. Manba matnlar o'zbek lotinida yoziladi va kalit sifatida ishlatiladi.
enum AppLang {
  uz('uz', 'Özbekça (Lotin, yangi)', 'UZ'),
  uzOld('uz-old', "O'zbekcha (Lotin, amaldagi)", 'UZ'),
  uzCyrl('uz-Cyrl', 'Ўзбекча (Кирилл)', 'ЎЗ'),
  ru('ru', 'Русский', 'RU'),
  en('en', 'English', 'EN'),
  kaa('kaa', 'Qaraqalpaqsha', 'QQ');

  const AppLang(this.code, this.label, this.short);
  final String code, label, short;

  /// Yangi alifbo qonuni (OʻRQ–1184) kuchga kiradigan kun: shu kungacha til tanlamaganlarga amaldagi lotin.
  static final newAlphabetDate = DateTime(2027, 4, 22);

  /// Tanlanmagan bo'lsa: 2027-yil 22-aprelgacha amaldagi lotin, keyin yangi lotin.
  static AppLang get defaultLang => DateTime.now().isBefore(newAlphabetDate) ? AppLang.uzOld : AppLang.uz;

  static AppLang fromCode(String? code) => code == null ? defaultLang : values.firstWhere((l) => l.code == code, orElse: () => defaultLang);

  /// O'zbek lotin (yangi yoki amaldagi).
  bool get isUzLatin => this == AppLang.uz || this == AppLang.uzOld;
}

class I18n {
  I18n._();
  static AppLang lang = AppLang.uz;
  static final _cyrCache = <String, String>{};
  static final _newCache = <String, String>{};

  static Map<String, String>? get _dict => switch (lang) {
        AppLang.ru => stringsRu,
        AppLang.en => stringsEn,
        AppLang.kaa => stringsKaa,
        _ => null,
      };
}

/// Matnni joriy tilga o'giradi. Tarjima topilmasa — o'zbekcha manba qaytadi.
String tr(String s) {
  switch (I18n.lang) {
    case AppLang.uz:
      // Manba matnlar eski yozuvda (kalit sifatida); ekranga yangi harflar bilan chiqadi: ö, ğ, ş, ç
      return I18n._newCache.putIfAbsent(s, () => toNewLatin(s));
    case AppLang.uzOld:
      return s; // manba matnlar amaldagi yozuvda
    case AppLang.uzCyrl:
      return I18n._cyrCache.putIfAbsent(s, () => toCyrillic(s));
    default:
      return I18n._dict![s] ?? s;
  }
}

/// Matnni berilgan tilda qaytaradi (global tilni o'zgartirmasdan) — til tanlashda oldindan ko'rish uchun (TZ S32).
String trIn(AppLang l, String s) => switch (l) {
      AppLang.uz => toNewLatin(s),
      AppLang.uzOld => s,
      AppLang.uzCyrl => toCyrillic(s),
      AppLang.ru => stringsRu[s] ?? s,
      AppLang.en => stringsEn[s] ?? s,
      AppLang.kaa => stringsKaa[s] ?? s,
    };

/// O'rinbosarli matn: trf('{0} kun oldin', [3]).
String trf(String s, List<Object?> args) {
  var r = tr(s);
  for (var i = 0; i < args.length; i++) {
    r = r.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return r;
}

/// Serverdan kelgan o'zbekcha matn (ekin, kasallik nomi va h.k.): kirill rejimida o'giriladi, boshqa tillarda o'zgarmaydi.
String trData(String? s) {
  if (s == null) return '';
  return switch (I18n.lang) {
    AppLang.uzCyrl => I18n._cyrCache.putIfAbsent(s, () => toCyrillic(s)),
    AppLang.uz => I18n._newCache.putIfAbsent(s, () => toNewLatin(s)),
    AppLang.uzOld => toOldLatin(s),
    _ => s,
  };
}
