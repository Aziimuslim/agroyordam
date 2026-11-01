import 'package:flutter_test/flutter_test.dart';
import 'package:agroyordam/core/i18n/i18n.dart';
import 'package:agroyordam/core/i18n/translit.dart';

void main() {
  test('Yangi lotin: oʻ gʻ sh ch', () {
    expect(toNewLatin("O'zbekcha bog'dagi shaftoli uchun o'g'it"), 'Özbekça boğdagi şaftoli uçun öğit');
    expect(toNewLatin('SHIRA va Choy'), 'ŞIRA va Çoy');
    expect(toNewLatin("ma'lumot"), "ma'lumot");
    expect(toNewLatin('https://agroyordam.duckdns.org/shop {0} user@mail.uz'), 'https://agroyordam.duckdns.org/shop {0} user@mail.uz');
    expect(toNewLatin('AgroYordam Payme Click Telegram'), 'AgroYordam Payme Click Telegram');
    expect(toNewLatin('Phytophthora infestans, Erysiphe cichoracearum'), 'Phytophthora infestans, Erysiphe cichoracearum');
    expect(toNewLatin(toNewLatin("o'sha")), 'öşa');
    expect(searchKey('Shaftoli'), searchKey('şaftoli'));
    expect(toCyrillic('Özbekça şaftoli'), 'Ўзбекча шафтоли');
    // Rasmiy harflar ö/ğ; eski xato ó/ǵ avtomatik tuzatiladi
    expect(toNewLatin('Kóçat óǵit'), 'Köçat öğit');
    expect(toCyrillic('Kóçat'), 'Кўчат');
  });

  test('Lotin (amaldagi): server matni eski yozuvda, menyu manba matni', () {
    expect(toOldLatin('Özbekça şaftoli uçun öğit, ŞIRA, Şohruh'), "O'zbekcha shaftoli uchun o'g'it, SHIRA, Shohruh");
    expect(toOldLatin('https://x.uz/a 123'), 'https://x.uz/a 123');
    expect(AppLang.fromCode('uz'), AppLang.uz);
    expect(AppLang.fromCode('uz-old'), AppLang.uzOld);
    expect(AppLang.fromCode(null), DateTime.now().isBefore(DateTime(2027, 4, 22)) ? AppLang.uzOld : AppLang.uz);
    final prev = I18n.lang;
    I18n.lang = AppLang.uzOld;
    expect(tr('Saqlash'), 'Saqlash');
    expect(trData('Şaftoli'), 'Shaftoli');
    I18n.lang = AppLang.uz;
    expect(tr('Saqlash'), 'Saqlaş');
    I18n.lang = prev;
  });
}
