import '../../domain/entities/entities.dart';
import 'base.dart';

/// Agronomlar, "Men agronomman" arizasi va dehqon savollari.
class ExpertRepository extends BaseRepository {
  ExpertRepository(super.api);

  Future<List<Expert>> experts() => call(() async => list((await dio.get('/experts')).data, Expert.fromJson));
  Future<Expert> expert(String id) => call(() async => Expert.fromJson((await dio.get('/experts/$id')).data));

  Future<ExpertApplication> apply({required String specialization, required int experienceYears, String? about}) => call(() async =>
      ExpertApplication.fromJson((await dio.post('/experts/applications',
              data: {'specialization': specialization, 'experience_years': experienceYears, if (about != null && about.isNotEmpty) 'about': about}))
          .data));

  Future<ExpertApplication?> myApplication() => call(() async {
        final d = (await dio.get('/experts/applications/me')).data;
        return d == null ? null : ExpertApplication.fromJson(Map<String, dynamic>.from(d));
      });

  Future<QuestionQuota> quota() => call(() async => QuestionQuota.fromJson((await dio.get('/questions/quota')).data));

  Future<Question> ask({required String title, String? body, String? cropId, String? diagnosisId}) => call(() async =>
      Question.fromJson((await dio.post('/questions', data: {
        'title': title,
        if (body != null && body.isNotEmpty) 'body': body,
        if (cropId != null) 'crop_id': cropId,
        if (diagnosisId != null) 'diagnosis_id': diagnosisId,
      }))
          .data));

  Future<List<Question>> mine() => call(() async => list((await dio.get('/questions/mine')).data, Question.fromJson));
  Future<Question> question(String id) => call(() async => Question.fromJson((await dio.get('/questions/$id')).data));
  Future<Question> send(String id, {String? body, String? medicineId}) => call(() async => Question.fromJson(
      (await dio.post('/questions/$id/messages', data: {if (body != null) 'body': body, if (medicineId != null) 'medicine_id': medicineId})).data));
  Future<void> close(String id) => call(() => dio.post('/questions/$id/close'));
  Future<void> rate(String id, int rating) => call(() => dio.post('/questions/$id/rate', data: {'rating': rating}));

  // ---------- Agronom rejimi ----------
  Future<ExpertStats> stats() => call(() async => ExpertStats.fromJson((await dio.get('/experts/stats/me')).data));
  Future<void> updateMe({bool? acceptingQuestions, String? workHours, String? specialization}) => call(() => dio.put('/experts/me', data: {
        if (acceptingQuestions != null) 'accepting_questions': acceptingQuestions,
        if (workHours != null) 'work_hours': workHours,
        if (specialization != null) 'specialization': specialization,
      }));

  Future<List<QueueItem>> queue(String filter) =>
      call(() async => list((await dio.get('/experts/queue', queryParameters: {'filter': filter})).data, QueueItem.fromJson));
  Future<QueueItem> queueItem(String id) => call(() async => QueueItem.fromJson((await dio.get('/experts/queue/$id')).data));

  /// status: confirmed | corrected | rejected. Javob — navbatdagi keyingi tashxis (bo'lmasa null).
  Future<QueueItem?> review(String id, {required String status, String? label, String? comment}) => call(() async {
        final d = (await dio.post('/experts/queue/$id', data: {
          'status': status,
          if (label != null) 'label': label,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        }))
            .data;
        return d == null ? null : QueueItem.fromJson(Map<String, dynamic>.from(d));
      });

  /// status: new | mine | closed_mine
  Future<List<Question>> inbox(String status) =>
      call(() async => list((await dio.get('/questions', queryParameters: {'status': status})).data, Question.fromJson));

  Future<List<CatalogChange>> changes({bool mine = false}) =>
      call(() async => list((await dio.get('/experts/catalog-changes', queryParameters: {'mine': mine})).data, CatalogChange.fromJson));
  Future<List<DatasetImage>> datasetImages(String label) =>
      call(() async => list((await dio.get('/experts/dataset-images', queryParameters: {'label': label})).data, DatasetImage.fromJson));
}
