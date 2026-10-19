import 'package:dio/dio.dart';

import '../../domain/entities/entities.dart';
import 'base.dart';

class GardenRepository extends BaseRepository {
  GardenRepository(super.api);

  Future<List<Crop>> crops({String status = 'active'}) =>
      call(() async => list((await dio.get('/crops', queryParameters: {'status': status})).data, Crop.fromJson));
  Future<Crop> crop(String id) => call(() async => Crop.fromJson((await dio.get('/crops/$id')).data));
  Future<Crop> createCrop(Map<String, dynamic> data) => call(() async => Crop.fromJson((await dio.post('/crops', data: data)).data));
  Future<Crop> updateCrop(String id, Map<String, dynamic> data) =>
      call(() async => Crop.fromJson((await dio.put('/crops/$id', data: data)).data));
  Future<void> deleteCrop(String id) => call(() => dio.delete('/crops/$id'));
  Future<Crop> setCropArchived(String id, bool archived) =>
      call(() async => Crop.fromJson((await dio.put('/crops/$id', data: {'status': archived ? 'archived' : 'active'})).data));
  Future<Crop> uploadCropPhoto(String id, List<int> bytes, String filename) => call(() async {
        final ext = filename.toLowerCase().split('.').last;
        final sub = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');
        final form = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType('image', sub))});
        return Crop.fromJson((await dio.post('/crops/$id/photo', data: form)).data);
      });
  Future<Crop> deleteCropPhoto(String id) => call(() async => Crop.fromJson((await dio.delete('/crops/$id/photo')).data));

  Future<List<HealthPoint>> health(String id) =>
      call(() async => list((await dio.get('/crops/$id/health-history')).data, HealthPoint.fromJson));
  Future<List<CropLog>> logs(String id) => call(() async => list((await dio.get('/crops/$id/logs')).data, CropLog.fromJson));
  Future<void> addLog(String id, String content) => call(() => dio.post('/crops/$id/logs', data: {'content': content}));

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<CropLog> saveLog(String cropId, {String? logId, int? version, required String content, required List<String> images, required DateTime observedAt}) =>
      call(() async {
        final data = {'content': content, 'images': images, 'observed_at': _day(observedAt), if (version != null) 'version': version};
        final r = logId == null ? await dio.post('/crops/$cropId/logs', data: data) : await dio.put('/crops/$cropId/logs/$logId', data: data);
        return CropLog.fromJson(r.data);
      });

  Future<void> deleteLog(String cropId, String logId) => call(() => dio.delete('/crops/$cropId/logs/$logId'));

  Future<Weather> weather() => call(() async => Weather.fromJson((await dio.get('/weather')).data));

  // Tashxis
  /// TZ A01: tahlilni fonda boshlash. [clientKey] — tanlangan rasm uchun bir marta yaratiladi: qayta yuborilsa
  /// server o'sha ishni qaytaradi (dublikat tahlil yo'q).
  Future<AnalysisJob> startAnalysis(List<int> bytes, String filename,
          {required String clientKey, String? cropId, String? plantId, void Function()? onUploaded, CancelToken? cancel}) =>
      call(() async {
        final ext = filename.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');
        final form = FormData.fromMap({
          'image': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType('image', mime)),
          'client_key': clientKey,
          if (cropId != null) 'crop_id': cropId,
          if (cropId == null && plantId != null) 'plant_id': plantId,
        });
        var notified = false;
        return AnalysisJob.fromJson((await dio.post('/diagnoses/jobs',
                data: form,
                cancelToken: cancel,
                onSendProgress: (sent, total) {
                  if (!notified && total > 0 && sent >= total) {
                    notified = true;
                    onUploaded?.call();
                  }
                }))
            .data);
      });
  Future<AnalysisJob> analysisJob(String id) => call(() async => AnalysisJob.fromJson((await dio.get('/diagnoses/jobs/$id')).data));
  Future<AnalysisJob> cancelAnalysis(String id) => call(() async => AnalysisJob.fromJson((await dio.post('/diagnoses/jobs/$id/cancel')).data));

  /// Tarixdan yashirish (yozuv serverda saqlanadi) va qaytarish — TZ S07.
  Future<void> hideDiagnosis(String id) => call(() => dio.delete('/diagnoses/$id'));
  Future<Diagnosis> restoreDiagnosis(String id) => call(() async => Diagnosis.fromJson((await dio.post('/diagnoses/$id/restore')).data));
  Future<List<Diagnosis>> diagnoses({String? cropId}) => call(() async =>
      list((await dio.get('/diagnoses', queryParameters: {if (cropId != null) 'crop_id': cropId})).data, Diagnosis.fromJson));
  Future<Diagnosis> diagnosis(String id) => call(() async => Diagnosis.fromJson((await dio.get('/diagnoses/$id')).data));
  Future<CarePlan> carePlan(String id) => call(() async => CarePlan.fromJson((await dio.get('/diagnoses/$id/care-plan')).data));

  /// Tashxisni bog'ga qo'shadi va rejani eslatmalar sifatida saqlaydi → ekin ID.
  Future<String> applyCarePlan(String id, {String? cropId, String? cropName, String? plantId}) => call(() async =>
      (await dio.post('/diagnoses/$id/care-plan', data: {
        if (cropId != null) 'crop_id': cropId,
        if (cropName != null && cropName.isNotEmpty) 'crop_name': cropName,
        if (plantId != null) 'plant_id': plantId,
      }))
          .data['crop_id'] as String);
  /// "Agronomga yuborish": tashxis agronomlar navbatida birinchi turadi.
  Future<Diagnosis> requestReview(String id, {String? note}) => call(() async =>
      Diagnosis.fromJson((await dio.post('/diagnoses/$id/request-review', data: {if (note != null && note.isNotEmpty) 'note': note})).data));

  Future<Diagnosis> feedback(String id, bool correct) =>
      call(() async => Diagnosis.fromJson((await dio.post('/diagnoses/$id/feedback', data: {'correct': correct})).data));
  Future<Post> shareDiagnosis(String id) => call(() async => Post.fromJson((await dio.post('/diagnoses/$id/share')).data));

  // Eslatmalar
  Future<List<Reminder>> reminders({String? cropId}) => call(() async =>
      list((await dio.get('/reminders', queryParameters: {if (cropId != null) 'crop_id': cropId})).data, Reminder.fromJson));
  Future<Reminder> createReminder(Map<String, dynamic> data) =>
      call(() async => Reminder.fromJson((await dio.post('/reminders', data: data)).data));
  Future<Reminder> toggleReminder(String id) => call(() async => Reminder.fromJson((await dio.put('/reminders/$id/complete')).data));
  /// [scope] = one | future (takrorlanuvchi seriyada: faqat shu yoki shu va keyingilar).
  Future<void> deleteReminder(String id, {String scope = 'one'}) => call(() => dio.delete('/reminders/$id', queryParameters: {'scope': scope}));
  Future<Reminder> reminder(String id) => call(() async => Reminder.fromJson((await dio.get('/reminders/$id')).data));
  Future<Reminder> updateReminder(String id, Map<String, dynamic> data, {String scope = 'one'}) =>
      call(() async => Reminder.fromJson((await dio.put('/reminders/$id', data: data, queryParameters: {'scope': scope})).data));

  Future<String> upload(List<int> bytes, String filename, {String folder = 'posts'}) => call(() async {
        final ext = filename.split('.').last.toLowerCase();
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType('image', ext == 'png' ? 'png' : 'jpeg')),
        });
        return (await dio.post('/uploads', data: form, queryParameters: {'folder': folder})).data['url'] as String;
      });
}
