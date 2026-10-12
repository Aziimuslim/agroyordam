/// Xo'jalik turi va sug'orish usuli — server qiymati → ko'rinadigan nom.
const farmTypes = <String, String>{
  'tomorqa': 'Tomorqa',
  'dehqon': "Dehqon xo'jaligi",
  'fermer': "Fermer xo'jaligi",
  'issiqxona': 'Issiqxona',
};

const irrigationTypes = <String, String>{
  'ariq': 'Ariq (egat)',
  'tomchi': 'Tomchilatib',
  'yomgir': "Yomg'irlatib",
  'nasos': 'Quduq / nasos',
  'lalmi': "Lalmi (sug'orilmaydi)",
};

/// Maydon gektarda saqlanadi; 1 gektardan kichigi sotixda ko'rsatiladi (1 ga = 100 sotix).
String formatArea(double? ha) {
  if (ha == null) return '';
  String n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(v < 10 ? 2 : 1).replaceAll(RegExp(r'\.?0+$'), '');
  return ha < 1 ? '${n(ha * 100)} sotix' : '${n(ha)} gektar';
}
