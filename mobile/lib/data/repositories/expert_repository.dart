import '../../domain/entities/entities.dart';
import 'base.dart';

/// Agronomlar, "Men agronomman" arizasi va dehqon savollari.
class ExpertRepository extends BaseRepository {
  ExpertRepository(super.api);

  Future<List<Expert>> experts() => call(() async => list((await dio.get('/experts')).data, Expert.fromJson));

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
}
