import 'package:intl/intl.dart';

import '../i18n/i18n.dart';

String timeAgo(DateTime? t) {
  if (t == null) return '';
  final diff = DateTime.now().difference(t.toLocal());
  if (diff.inMinutes < 1) return tr('hozir');
  if (diff.inMinutes < 60) return trf('{0} daqiqa oldin', [diff.inMinutes]);
  if (diff.inHours < 24) return trf('{0} soat oldin', [diff.inHours]);
  if (diff.inDays < 30) return trf('{0} kun oldin', [diff.inDays]);
  return DateFormat('dd.MM.yyyy').format(t.toLocal());
}

String formatDate(DateTime? t) => t == null ? '' : DateFormat('dd.MM.yyyy').format(t.toLocal());

String formatMoney(num v) => trf("{0} so'm", [NumberFormat.decimalPattern('ru').format(v).replaceAll(' ', ' ')]);

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 11) return tr('Xayrli tong!');
  if (h < 18) return tr('Xayrli kun!');
  return tr('Xayrli kech!');
}

List<String> get _weekdays => ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];
List<String> get _months => ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];

/// "Seshanba, 30-sentabr"
String formatDayLong([DateTime? d]) {
  final t = d ?? DateTime.now();
  final day = tr(_weekdays[t.weekday - 1]), month = tr(_months[t.month - 1]);
  // "Seshanba, 30-sentabr" / "Вторник, 30 сентября" / "Tuesday, 30 September"
  return trf('{0}, {1}-{2}', [day, t.day, month]);
}

/// "12-oktabr" (yil va hafta kunisiz)
String formatDayMonth(DateTime d) {
  final t = d.toLocal();
  return trf('{0}-{1}', [t.day, tr(_months[t.month - 1])]);
}

/// "Xayrli tong" (undovsiz, ism bilan ishlatish uchun)
String greetingShort([DateTime? now]) => greeting(now).replaceAll('!', '');

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  // Backend UTC vaqtni timezone'siz qaytaradi
  return DateTime.tryParse(s.contains('Z') || s.contains('+') || s.length <= 10 ? s : '${s}Z');
}

Map<String, String> get reminderTypeLabels => {
  'watering': tr("Sug'orish"),
  'treatment': tr('Davolash'),
  'fertilizing': tr("O'g'itlash"),
  'recheck': tr('Qayta tekshiruv'),
  'other': tr('Parvarish'),
};

Map<String, String> get postCategoryLabels => {
  'disease': tr('Kasallik'),
  'question': tr('Savol'),
  'experience': tr('Tajriba'),
  'advice': tr('Maslahat'),
};

Map<String, String> get riskLabels => {'low': tr('Past xavf'), 'medium': tr("O'rta xavf"), 'high': tr('Yuqori xavf')};

/// "08:05" — mahalliy vaqt.
String hhmmLocal(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
