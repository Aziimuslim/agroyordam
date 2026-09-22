import 'package:intl/intl.dart';

String timeAgo(DateTime? t) {
  if (t == null) return '';
  final diff = DateTime.now().difference(t.toLocal());
  if (diff.inMinutes < 1) return 'hozir';
  if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
  if (diff.inHours < 24) return '${diff.inHours} soat oldin';
  if (diff.inDays < 30) return '${diff.inDays} kun oldin';
  return DateFormat('dd.MM.yyyy').format(t.toLocal());
}

String formatDate(DateTime? t) => t == null ? '' : DateFormat('dd.MM.yyyy').format(t.toLocal());

String formatMoney(num v) => '${NumberFormat.decimalPattern('ru').format(v).replaceAll(' ', ' ')} so\'m';

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 11) return 'Xayrli tong!';
  if (h < 18) return 'Xayrli kun!';
  return 'Xayrli kech!';
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  // Backend UTC vaqtni timezone'siz qaytaradi
  return DateTime.tryParse(s.contains('Z') || s.contains('+') || s.length <= 10 ? s : '${s}Z');
}

const reminderTypeLabels = {
  'watering': "Sug'orish",
  'treatment': 'Davolash',
  'fertilizing': "O'g'itlash",
  'recheck': 'Qayta tekshiruv',
  'other': 'Parvarish',
};

const postCategoryLabels = {
  'disease': 'Kasallik',
  'question': 'Savol',
  'experience': 'Tajriba',
  'advice': 'Maslahat',
};

const riskLabels = {'low': 'Past xavf', 'medium': "O'rta xavf", 'high': 'Yuqori xavf'};
