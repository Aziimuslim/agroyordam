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
    this.completedAt,
    this.seriesId,
    this.repeat,
    this.repeatEvery,
    this.repeatUntil,
    this.remindBefore,
  });
  final String id, title;
  final String? description, type, time, cropId, cropName, diagnosisId;
  final DateTime date;
  final bool isCompleted;
  final DateTime? completedAt, repeatUntil;

  /// Takrorlanuvchi seriya (har sana — alohida yozuv); [repeat]: daily | weekly | monthly | custom.
  final String? seriesId, repeat;
  final int? repeatEvery;

  /// Bildirishnoma necha daqiqa oldin.
  final int? remindBefore;

  bool get isSeries => seriesId != null;
  bool get isAllDay => time == null;

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
        completedAt: parseDate(j['completed_at']),
        seriesId: j['series_id'],
        repeat: j['repeat'],
        repeatEvery: j['repeat_every'],
        repeatUntil: j['repeat_until'] == null ? null : DateTime.parse(j['repeat_until']),
        remindBefore: j['remind_before'],
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
