import 'strings_en.dart';
import 'strings_kaa.dart';
import 'strings_ru.dart';
import 'translit.dart';

/// Ilova tillari. Manba matnlar o'zbek lotinida yoziladi va kalit sifatida ishlatiladi.
enum AppLang {
  uz('uz', "O'zbekcha (Lotin)", 'UZ'),
  uzCyrl('uz-Cyrl', 'Ўзбекча (Кирилл)', 'ЎЗ'),
  ru('ru', 'Русский', 'RU'),
  en('en', 'English', 'EN'),
  kaa('kaa', 'Qaraqalpaqsha', 'QQ');

  const AppLang(this.code, this.label, this.short);
  final String code, label, short;

  static AppLang fromCode(String? code) => values.firstWhere((l) => l.code == code, orElse: () => AppLang.uz);
}

class I18n {
  I18n._();
  static AppLang lang = AppLang.uz;
  static final _cyrCache = <String, String>{};

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
      return s;
    case AppLang.uzCyrl:
      return I18n._cyrCache.putIfAbsent(s, () => toCyrillic(s));
    default:
      return I18n._dict![s] ?? s;
  }
}

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
  return I18n.lang == AppLang.uzCyrl ? I18n._cyrCache.putIfAbsent(s, () => toCyrillic(s)) : s;
}
