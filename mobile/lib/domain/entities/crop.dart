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
    this.createdAt,
  });
  final String id, name, status;
  final String? plantId, plantName, variety, location, notes, lastDisease, imageUrl;
  final DateTime? plantingDate, createdAt;
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
        createdAt: parseDate(j['created_at']),
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

class CropLog {
  CropLog({required this.id, required this.content, this.imageUrl, this.createdAt});
  final String id, content;
  final String? imageUrl;
  final DateTime? createdAt;

  factory CropLog.fromJson(Map<String, dynamic> j) =>
      CropLog(id: j['id'], content: j['content'], imageUrl: j['image_url'], createdAt: parseDate(j['created_at']));
}

/// Ob-havo va zamburug' kasalliklari xavfi (backend: GET /weather, manba — Open-Meteo).
class Weather {
  Weather({required this.city, required this.temperature, required this.humidity, required this.condition, required this.risk, required this.riskText, this.rainMm = 0});
  final String city, condition, risk, riskText;
  final double temperature, rainMm;
  final int humidity;

  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
        city: j['city'],
        temperature: (j['temperature'] as num).toDouble(),
        humidity: (j['humidity'] as num).toInt(),
        condition: j['condition'] ?? '',
        risk: j['risk'] ?? 'low',
        riskText: j['risk_text'] ?? '',
        rainMm: (j['rain_next_48h_mm'] as num?)?.toDouble() ?? 0,
      );
}
