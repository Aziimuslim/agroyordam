import '../../core/utils/format.dart';
import 'catalog.dart';

class Diagnosis {
  Diagnosis({
    required this.id,
    required this.imageUrl,
    this.cropId,
    this.plantId,
    this.plantName,
    this.diseaseId,
    this.diseaseName,
    this.confidence = 0,
    this.riskLevel,
    this.symptoms,
    this.causes,
    this.treatment,
    this.prevention,
    this.recommendations,
    this.isHealthy = false,
    this.lowConfidence = false,
    this.medicines = const [],
    this.diagnosedAt,
  });
  final String id, imageUrl;
  final String? cropId, plantId, plantName, diseaseId, diseaseName, riskLevel, symptoms, causes, treatment, prevention, recommendations;
  final double confidence;
  final bool isHealthy, lowConfidence;
  final List<Medicine> medicines;
  final DateTime? diagnosedAt;

  String get title => isHealthy ? "O'simlik sog'lom" : (diseaseName ?? 'Aniqlanmadi');

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        id: j['id'],
        imageUrl: j['image_url'],
        cropId: j['crop_id'],
        plantId: j['plant_id'],
        plantName: j['plant_name'],
        diseaseId: j['disease_id'],
        diseaseName: j['disease_name'],
        confidence: double.tryParse('${j['confidence'] ?? 0}') ?? 0,
        riskLevel: j['risk_level'],
        symptoms: j['symptoms'],
        causes: j['causes'],
        treatment: j['treatment'],
        prevention: j['prevention'],
        recommendations: j['recommendations'],
        isHealthy: j['is_healthy'] ?? false,
        lowConfidence: j['low_confidence'] ?? false,
        medicines: [for (final m in (j['medicines'] as List? ?? [])) Medicine.fromJson(m)],
        diagnosedAt: parseDate(j['diagnosed_at']),
      );
}

class CarePlanTask {
  CarePlanTask({required this.day, required this.date, required this.time, required this.title, required this.type, this.description});
  final int day;
  final DateTime date;
  final String time, title, type;
  final String? description;

  factory CarePlanTask.fromJson(Map<String, dynamic> j) => CarePlanTask(
        day: j['day'],
        date: DateTime.parse(j['date']),
        time: j['time'],
        title: j['title'],
        type: j['reminder_type'],
        description: j['description'],
      );
}

/// Tashxis bo'yicha kunlik parvarish/davolash rejasi (backend: GET /diagnoses/{id}/care-plan).
class CarePlan {
  CarePlan({required this.diagnosisId, required this.durationDays, required this.tasks, this.cropId, this.plantId, this.plantName, this.diseaseName, this.confidence = 0, this.isHealthy = false});
  final String diagnosisId;
  final String? cropId, plantId, plantName, diseaseName;
  final double confidence;
  final bool isHealthy;
  final int durationDays;
  final List<CarePlanTask> tasks;

  factory CarePlan.fromJson(Map<String, dynamic> j) => CarePlan(
        diagnosisId: j['diagnosis_id'],
        cropId: j['crop_id'],
        plantId: j['plant_id'],
        plantName: j['plant_name'],
        diseaseName: j['disease_name'],
        confidence: double.tryParse('${j['confidence'] ?? 0}') ?? 0,
        isHealthy: j['is_healthy'] ?? false,
        durationDays: j['duration_days'],
        tasks: [for (final t in (j['tasks'] as List? ?? [])) CarePlanTask.fromJson(t)],
      );
}
