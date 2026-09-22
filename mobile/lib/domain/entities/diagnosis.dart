import '../../core/utils/format.dart';
import 'catalog.dart';

class Diagnosis {
  Diagnosis({
    required this.id,
    required this.imageUrl,
    this.cropId,
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
  final String? cropId, plantName, diseaseId, diseaseName, riskLevel, symptoms, causes, treatment, prevention, recommendations;
  final double confidence;
  final bool isHealthy, lowConfidence;
  final List<Medicine> medicines;
  final DateTime? diagnosedAt;

  String get title => isHealthy ? "O'simlik sog'lom" : (diseaseName ?? 'Aniqlanmadi');

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        id: j['id'],
        imageUrl: j['image_url'],
        cropId: j['crop_id'],
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
