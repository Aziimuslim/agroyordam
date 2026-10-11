import '../../core/utils/format.dart';
import 'user.dart';

/// Dehqonlar ko'radigan agronom kartasi.
class Expert {
  Expert({required this.id, required this.fullName, this.avatarUrl, this.region, this.specialization, this.acceptingQuestions = true,
      this.answers = 0, this.rating});
  final String id, fullName;
  final String? avatarUrl, region, specialization;
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
