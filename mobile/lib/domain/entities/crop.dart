import '../../core/utils/format.dart';

class Crop {
  Crop({
    required this.id,
    required this.name,
    this.plantId,
    this.plantName,
    this.variety,
    this.plantingDate,
    this.area,
    this.location,
    this.status = 'active',
    this.healthScore = 100,
    this.notes,
    this.lastDisease,
    this.imageUrl,
    this.photoUrl,
    this.createdAt,
    this.lastDiagnosisAt,
  });
  final String id, name, status;
  final String? plantId, plantName, variety, location, notes, lastDisease, imageUrl;
  /// Foydalanuvchi yuklagan ekin surati (S05); bo'lmasa oxirgi tashxis rasmi ishlatiladi.
  final String? photoUrl;
  bool get isArchived => status == 'archived';
  final DateTime? plantingDate, createdAt;
  /// Oxirgi AI tashxis vaqti; null — hali tekshirilmagan ("Ma'lumot yetarli emas").
  final DateTime? lastDiagnosisAt;
  final double? area;
  final int healthScore;

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
        id: j['id'],
        name: j['name'],
        plantId: j['plant_id'],
        plantName: j['plant_name'],
        variety: j['variety'],
        plantingDate: parseDate(j['planting_date']),
        area: j['area'] == null ? null : double.tryParse(j['area'].toString()),
        location: j['location'],
        status: j['status'] ?? 'active',
        healthScore: j['health_score'] ?? 100,
        notes: j['notes'],
        lastDisease: j['last_disease'],
        imageUrl: j['image_url'],
        photoUrl: j['photo_url'],
        createdAt: parseDate(j['created_at']),
        lastDiagnosisAt: parseDate(j['last_diagnosis_at']),
      );
}

class HealthPoint {
  HealthPoint(this.date, this.score, this.disease);
  final DateTime date;
  final int score;
  final String? disease;

  factory HealthPoint.fromJson(Map<String, dynamic> j) =>
      HealthPoint(parseDate(j['date']) ?? DateTime.now(), j['health_score'] ?? 0, j['disease']);
}

/// A04 Kundalik yozuvi: kuzatuv sanasi, matn va/yoki 5 tagacha rasm; `version` — tahrir konflikti uchun.
class CropLog {
  CropLog({required this.id, required this.content, this.imageUrl, this.images = const [], this.observedAt, this.version = 1, this.createdAt, this.updatedAt});
  final String id, content;
  final String? imageUrl;
  final List<String> images;
  final DateTime? observedAt, createdAt, updatedAt;
  final int version;

  DateTime? get date => observedAt ?? createdAt;
  bool get edited => updatedAt != null && createdAt != null && updatedAt!.difference(createdAt!).inSeconds > 5 && version > 1;

  factory CropLog.fromJson(Map<String, dynamic> j) {
    final imgs = List<String>.from(j['images'] ?? const []);
    return CropLog(
      id: j['id'],
      content: j['content'] ?? '',
      imageUrl: j['image_url'],
      images: imgs.isEmpty && j['image_url'] != null ? [j['image_url']] : imgs,
      observedAt: j['observed_at'] == null ? null : DateTime.tryParse(j['observed_at']),
      version: j['version'] ?? 1,
      createdAt: parseDate(j['created_at']),
      updatedAt: parseDate(j['updated_at']),
    );
  }
}

/// Ob-havo va zamburug' kasalliklari xavfi (backend: GET /weather, manba — Open-Meteo).
class Weather {
  Weather({
    required this.city,
    required this.temperature,
    required this.humidity,
    required this.condition,
    required this.risk,
    required this.riskText,
    this.rainMm = 0,
    this.code = 0,
    this.isDay = true,
    this.updatedAt,
    this.region,
    this.hourly = const [],
    this.daily = const [],
  });
  final String city, condition, risk, riskText;

  /// A06: keyingi 24 soat va 7 kun (provayder bergan bo'lsa; hudud mahalliy vaqti).
  final List<HourForecast> hourly;
  final List<DayForecast> daily;
  final String? region;
  final double temperature, rainMm;
  final int humidity;

  /// WMO ob-havo kodi (0 ochiq, 1–3 bulut, 45/48 tuman, 51–67/80–82 yomg'ir, 71–77/85–86 qor, 95+ momaqaldiroq).
  final int code;
  final bool isDay;

  /// Ma'lumot provayderdan olingan vaqt (server keshi). null — eski server.
  final DateTime? updatedAt;

  /// TZ: 2 soatdan eski ob-havo "eskirgan" deb belgilanadi.
  bool get isStale => updatedAt != null && DateTime.now().toUtc().difference(updatedAt!.toUtc()) > const Duration(hours: 2);

  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
        city: j['city'],
        region: j['region'],
        temperature: (j['temperature'] as num).toDouble(),
        humidity: (j['humidity'] as num).toInt(),
        condition: j['condition'] ?? '',
        risk: j['risk'] ?? 'low',
        riskText: j['risk_text'] ?? '',
        rainMm: (j['rain_next_48h_mm'] as num?)?.toDouble() ?? 0,
        code: (j['code'] as num?)?.toInt() ?? 0,
        isDay: j['is_day'] ?? true,
        updatedAt: parseDate(j['updated_at']),
        hourly: [for (final h in (j['hourly'] as List? ?? const [])) HourForecast.fromJson(Map<String, dynamic>.from(h))],
        daily: [for (final d in (j['daily'] as List? ?? const [])) DayForecast.fromJson(Map<String, dynamic>.from(d))],
      );
}

/// Soatlik prognoz. `time` — hudud mahalliy vaqti (vaqt zonasi o'zgartirilmaydi).
class HourForecast {
  HourForecast({required this.time, required this.temperature, this.code = 0, this.rainProbability, this.isDay = true});
  final DateTime time;
  final double temperature;
  final int code;
  final int? rainProbability;
  final bool isDay;
  factory HourForecast.fromJson(Map<String, dynamic> j) => HourForecast(
        time: DateTime.parse(j['time']),
        temperature: (j['temperature'] as num).toDouble(),
        code: (j['code'] as num?)?.toInt() ?? 0,
        rainProbability: (j['rain_probability'] as num?)?.toInt(),
        isDay: j['is_day'] ?? true,
      );
}

class DayForecast {
  DayForecast({required this.date, required this.tMax, required this.tMin, this.code = 0, this.condition = '', this.rainMm = 0, this.rainProbability});
  final DateTime date;
  final double tMax, tMin, rainMm;
  final int code;
  final String condition;
  final int? rainProbability;
  factory DayForecast.fromJson(Map<String, dynamic> j) => DayForecast(
        date: DateTime.parse(j['date']),
        tMax: (j['t_max'] as num).toDouble(),
        tMin: (j['t_min'] as num).toDouble(),
        code: (j['code'] as num?)?.toInt() ?? 0,
        condition: j['condition'] ?? '',
        rainMm: (j['rain_mm'] as num?)?.toDouble() ?? 0,
        rainProbability: (j['rain_probability'] as num?)?.toInt(),
      );
}
