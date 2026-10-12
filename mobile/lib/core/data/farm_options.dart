import '../i18n/i18n.dart';
/// Xo'jalik turi va sug'orish usuli — server qiymati → ko'rinadigan nom.
Map<String, String> get farmTypes => {
  'tomorqa': tr('Tomorqa'),
  'dehqon': tr("Dehqon xo'jaligi"),
  'fermer': tr("Fermer xo'jaligi"),
  'issiqxona': tr('Issiqxona'),
};

Map<String, String> get irrigationTypes => {
  'ariq': tr('Ariq (egat)'),
  'tomchi': tr('Tomchilatib'),
  'yomgir': tr("Yomg'irlatib"),
  'nasos': tr('Quduq / nasos'),
  'lalmi': tr("Lalmi (sug'orilmaydi)"),
};

/// Maydon gektarda saqlanadi; 1 gektardan kichigi sotixda ko'rsatiladi (1 ga = 100 sotix).
String formatArea(double? ha) {
  if (ha == null) return '';
  String n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(v < 10 ? 2 : 1).replaceAll(RegExp(r'\.?0+$'), '');
  return ha < 1 ? trf('{0} sotix', [n(ha * 100)]) : trf('{0} gektar', [n(ha)]);
}
