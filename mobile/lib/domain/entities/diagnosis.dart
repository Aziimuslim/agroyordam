import '../../core/i18n/i18n.dart';
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
    this.userFeedback,
    this.feedbackReason,
    this.diagnosedAt,
    this.aiLabel,
    this.diseaseLabel,
    this.reviewStatus = 'pending',
    this.reviewRequested = false,
    this.expertComment,
  });
  final String id, imageUrl;
  final String? cropId, plantId, plantName, diseaseId, diseaseName, riskLevel, symptoms, causes, treatment, prevention, recommendations;
  final double confidence;
  final bool isHealthy, lowConfidence;
  final List<Medicine> medicines;
  final bool? userFeedback;
  final String? feedbackReason;
  final DateTime? diagnosedAt;

  /// AI sinfi (ma'lumotnoma rasmi uchun) va agronom tekshiruvi: pending | confirmed | corrected | rejected.
  final String? aiLabel, expertComment;

  /// Bilimlar bazasidagi kasallik sinfi — agronom tuzatgan bo'lsa ham to'g'ri ma'lumotnoma rasmi uchun.
  final String? diseaseLabel;
  final String reviewStatus;
  final bool reviewRequested;

  bool get expertChecked => reviewStatus == 'confirmed' || reviewStatus == 'corrected';
  bool get canAskExpert => reviewStatus == 'pending' && !reviewRequested;

  String get title => isHealthy ? tr("O'simlik sog'lom") : (diseaseName ?? tr('Aniqlanmadi'));

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
        userFeedback: j['user_feedback'],
        feedbackReason: j['feedback_reason'],
        diagnosedAt: parseDate(j['diagnosed_at']),
        aiLabel: j['ai_label'],
        diseaseLabel: j['disease_label'],
        reviewStatus: j['review_status'] ?? 'pending',
        reviewRequested: j['review_requested'] ?? false,
        expertComment: j['expert_comment'],
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
  CarePlan({required this.diagnosisId, required this.durationDays, required this.tasks, this.cropId, this.plantId, this.plantName, this.diseaseName, this.confidence = 0, this.isHealthy = false, this.replaces = const []});
  final String diagnosisId;
  final String? cropId, plantId, plantName, diseaseName;
  final double confidence;
  final bool isHealthy;
  final int durationDays;
  final List<CarePlanTask> tasks;

  /// TZ S04: qayta yaratilsa almashtiriladigan, hali bajarilmagan vazifalar (sarlavha, sana).
  final List<(String, DateTime)> replaces;

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
        replaces: [for (final r in (j['replaces'] as List? ?? [])) ('${r['title']}', DateTime.parse(r['date']))],
      );
}

/// TZ A01: fon tahlili holati — queued | processing | finishing | done | failed | cancelled.
class AnalysisJob {
  AnalysisJob({required this.id, required this.status, this.diagnosisId, this.error, this.errorCode});
  final String id, status;
  final String? diagnosisId, error;
  final int? errorCode;

  bool get isActive => status == 'queued' || status == 'processing' || status == 'finishing';
  bool get isDone => status == 'done' && diagnosisId != null;

  factory AnalysisJob.fromJson(Map<String, dynamic> j) => AnalysisJob(
        id: j['id'],
        status: j['status'] ?? 'queued',
        diagnosisId: j['diagnosis_id'],
        error: j['error'],
        errorCode: j['error_code'],
      );
}
