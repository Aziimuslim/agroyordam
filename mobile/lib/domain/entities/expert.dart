import '../../core/utils/format.dart';
import 'user.dart';

/// Dehqonlar ko'radigan agronom kartasi.
class Expert {
  Expert({required this.id, required this.fullName, this.avatarUrl, this.region, this.specialization, this.acceptingQuestions = true,
      this.answers = 0, this.rating, this.workHours});
  final String id, fullName;
  final String? avatarUrl, region, specialization, workHours;
  final bool acceptingQuestions;
  final int answers;
  final double? rating;

  factory Expert.fromJson(Map<String, dynamic> j) => Expert(
        id: j['id'],
        fullName: j['full_name'] ?? '',
        avatarUrl: j['avatar_url'],
        region: j['region'],
        specialization: j['specialization'],
        acceptingQuestions: j['accepting_questions'] ?? true,
        answers: j['answers'] ?? 0,
        rating: (j['rating'] as num?)?.toDouble(),
        workHours: j['work_hours'],
      );
}

/// "Men agronomman" arizasi.
class ExpertApplication {
  ExpertApplication({required this.id, required this.status, required this.specialization, this.experienceYears = 0, this.reason, this.createdAt});
  final String id, status, specialization;
  final int experienceYears;
  final String? reason;
  final DateTime? createdAt;

  bool get pending => status == 'pending';

  factory ExpertApplication.fromJson(Map<String, dynamic> j) => ExpertApplication(
        id: j['id'],
        status: j['status'],
        specialization: j['specialization'] ?? '',
        experienceYears: j['experience_years'] ?? 0,
        reason: j['reason'],
        createdAt: parseDate(j['created_at']),
      );
}

class QuestionMessage {
  QuestionMessage({required this.id, required this.sender, this.body, this.medicineName, this.medicineUsage, this.imageUrl, this.createdAt});
  final String id;
  final AppUser sender;
  final String? body, medicineName, medicineUsage, imageUrl;
  final DateTime? createdAt;

  factory QuestionMessage.fromJson(Map<String, dynamic> j) => QuestionMessage(
        id: j['id'],
        sender: AppUser.fromJson(j['sender']),
        body: j['body'],
        medicineName: j['medicine']?['name'],
        medicineUsage: j['medicine']?['usage'],
        imageUrl: j['image_url'],
        createdAt: parseDate(j['created_at']),
      );
}

/// Dehqonning agronomga savoli. status: new | answered | closed.
class Question {
  Question({
    required this.id,
    required this.author,
    required this.title,
    required this.status,
    this.expert,
    this.body,
    this.imageUrl,
    this.cropName,
    this.diagnosisId,
    this.diagnosisName,
    this.diagnosisConfidence,
    this.rating,
    this.messagesCount = 0,
    this.messages = const [],
    this.createdAt,
    this.updatedAt,
  });
  final String id, title, status;
  final AppUser author;
  final AppUser? expert;
  final String? body, imageUrl, cropName, diagnosisId, diagnosisName;
  final double? diagnosisConfidence;
  final int? rating;
  final int messagesCount;
  final List<QuestionMessage> messages;
  final DateTime? createdAt, updatedAt;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        author: AppUser.fromJson(j['author']),
        expert: j['expert'] == null ? null : AppUser.fromJson(j['expert']),
        title: j['title'] ?? '',
        status: j['status'] ?? 'new',
        body: j['body'],
        imageUrl: j['image_url'],
        cropName: j['crop_name'],
        diagnosisId: j['diagnosis_id'],
        diagnosisName: j['diagnosis_name'],
        diagnosisConfidence: (j['diagnosis_confidence'] as num?)?.toDouble(),
        rating: j['rating'],
        messagesCount: j['messages_count'] ?? 0,
        messages: [for (final m in (j['messages'] as List? ?? [])) QuestionMessage.fromJson(m)],
        createdAt: parseDate(j['created_at']),
        updatedAt: parseDate(j['updated_at']),
      );
}

/// Oylik bepul savollar. limit == null — cheksiz (Premium).
class QuestionQuota {
  QuestionQuota({required this.used, this.limit, this.remaining});
  final int used;
  final int? limit, remaining;
  bool get unlimited => limit == null;

  factory QuestionQuota.fromJson(Map<String, dynamic> j) =>
      QuestionQuota(used: j['used'] ?? 0, limit: j['limit'], remaining: j['remaining']);
}

/// AI ning muqobil javobi (tekshirish navbatida agronom bitta bosish bilan tanlaydi).
class Alternative {
  Alternative({required this.label, this.confidence, this.diseaseId, this.diseaseName, this.healthy = false});
  final String label;
  final double? confidence;
  final String? diseaseId, diseaseName;
  final bool healthy;

  factory Alternative.fromJson(Map<String, dynamic> j) => Alternative(
        label: j['label'],
        confidence: (j['confidence'] as num?)?.toDouble(),
        diseaseId: j['disease_id'],
        diseaseName: j['disease_name'],
        healthy: j['healthy'] ?? false,
      );
}

/// Tekshirish navbatidagi AI tashxisi.
class QueueItem {
  QueueItem({
    required this.id,
    required this.imageUrl,
    required this.farmerName,
    this.aiLabel,
    this.diseaseName,
    this.plantId,
    this.plantName,
    this.confidence,
    this.alternatives = const [],
    this.reviewRequested = false,
    this.reviewNote,
    this.farmerRegion,
    this.diagnosedAt,
  });
  final String id, imageUrl, farmerName;
  final String? aiLabel, diseaseName, plantId, plantName, reviewNote, farmerRegion;
  final double? confidence;
  final List<Alternative> alternatives;
  final bool reviewRequested;
  final DateTime? diagnosedAt;

  bool get lowConfidence => (confidence ?? 0) < 70;
  String get title => diseaseName ?? (aiLabel != null && aiLabel!.endsWith('healthy') ? "Sog'lom" : 'Aniqlanmagan');

  factory QueueItem.fromJson(Map<String, dynamic> j) => QueueItem(
        id: j['id'],
        imageUrl: j['image_url'],
        farmerName: j['farmer_name'] ?? 'Dehqon',
        aiLabel: j['ai_label'],
        diseaseName: j['disease_name'],
        plantId: j['plant_id'],
        plantName: j['plant_name'],
        confidence: (j['confidence'] as num?)?.toDouble(),
        alternatives: [for (final a in (j['alternatives'] as List? ?? [])) Alternative.fromJson(a)],
        reviewRequested: j['review_requested'] ?? false,
        reviewNote: j['review_note'],
        farmerRegion: j['farmer_region'],
        diagnosedAt: parseDate(j['diagnosed_at']),
      );
}

/// Agronomning o'z ko'rsatkichlari (navbat sarlavhasi va profil).
class ExpertStats {
  ExpertStats({this.reviewedToday = 0, this.reviewedTotal = 0, this.aiAgreement, this.queuePending = 0, this.questionsNew = 0,
      this.answers = 0, this.rating, this.ratingsCount = 0, this.avgAnswerMinutes});
  final int reviewedToday, reviewedTotal, queuePending, questionsNew, answers, ratingsCount;
  final int? aiAgreement, avgAnswerMinutes;
  final double? rating;

  factory ExpertStats.fromJson(Map<String, dynamic> j) => ExpertStats(
        reviewedToday: j['reviewed_today'] ?? 0,
        reviewedTotal: j['reviewed_total'] ?? 0,
        aiAgreement: j['ai_agreement'],
        queuePending: j['queue_pending'] ?? 0,
        questionsNew: j['questions_new'] ?? 0,
        answers: j['answers'] ?? 0,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingsCount: j['ratings_count'] ?? 0,
        avgAnswerMinutes: j['avg_answer_minutes'],
      );
}

/// Bilimlar bazasidagi o'zgarish (tarix).
class CatalogChange {
  CatalogChange({required this.id, required this.entity, required this.action, required this.summary, this.userName, this.mine = false,
      this.entityId, this.createdAt});
  final String id, entity, action, summary;
  final String? userName, entityId;
  final bool mine;
  final DateTime? createdAt;

  factory CatalogChange.fromJson(Map<String, dynamic> j) => CatalogChange(
        id: j['id'],
        entity: j['entity'],
        action: j['action'],
        summary: j['summary'] ?? '',
        userName: j['user_name'],
        mine: j['mine'] ?? false,
        entityId: j['entity_id'],
        createdAt: parseDate(j['created_at']),
      );
}

/// Agronom tasdiqlagan dala rasmi (ma'lumotnoma rasmini tanlash uchun).
class DatasetImage {
  DatasetImage({required this.id, required this.imageUrl});
  final String id, imageUrl;
  factory DatasetImage.fromJson(Map<String, dynamic> j) => DatasetImage(id: j['id'], imageUrl: j['image_url']);
}
