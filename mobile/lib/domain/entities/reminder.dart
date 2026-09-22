import '../../core/utils/format.dart';

class Reminder {
  Reminder({
    required this.id,
    required this.title,
    required this.date,
    this.description,
    this.type,
    this.time,
    this.cropId,
    this.cropName,
    this.diagnosisId,
    this.isCompleted = false,
  });
  final String id, title;
  final String? description, type, time, cropId, cropName, diagnosisId;
  final DateTime date;
  final bool isCompleted;

  bool get isTreatment => type == 'treatment' || type == 'recheck';

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'],
        title: j['title'],
        description: j['description'],
        type: j['reminder_type'],
        date: DateTime.parse(j['reminder_date']),
        time: j['reminder_time'],
        cropId: j['crop_id'],
        cropName: j['crop_name'],
        diagnosisId: j['diagnosis_id'],
        isCompleted: j['is_completed'] ?? false,
      );
}

class AppNotification {
  AppNotification({required this.id, this.type, this.title, this.body, this.referenceId, this.isRead = false, this.createdAt});
  final String id;
  final String? type, title, body, referenceId;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        type: j['type'],
        title: j['title'],
        body: j['body'],
        referenceId: j['reference_id'],
        isRead: j['is_read'] ?? false,
        createdAt: parseDate(j['created_at']),
      );
}
