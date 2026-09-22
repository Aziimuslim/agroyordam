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
  Future<List<HealthPoint>> health(String id) =>
      call(() async => list((await dio.get('/crops/$id/health-history')).data, HealthPoint.fromJson));
  Future<List<CropLog>> logs(String id) => call(() async => list((await dio.get('/crops/$id/logs')).data, CropLog.fromJson));
  Future<void> addLog(String id, String content) => call(() => dio.post('/crops/$id/logs', data: {'content': content}));

  // Tashxis
  Future<Diagnosis> diagnose(List<int> bytes, String filename, {String? cropId}) => call(() async {
        final ext = filename.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');
        final form = FormData.fromMap({
          'image': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType('image', mime)),
          if (cropId != null) 'crop_id': cropId,
        });
        return Diagnosis.fromJson((await dio.post('/diagnoses', data: form)).data);
      });
  Future<List<Diagnosis>> diagnoses({String? cropId}) => call(() async =>
      list((await dio.get('/diagnoses', queryParameters: {if (cropId != null) 'crop_id': cropId})).data, Diagnosis.fromJson));
  Future<Diagnosis> diagnosis(String id) => call(() async => Diagnosis.fromJson((await dio.get('/diagnoses/$id')).data));
  Future<Post> shareDiagnosis(String id) => call(() async => Post.fromJson((await dio.post('/diagnoses/$id/share')).data));

  // Eslatmalar
  Future<List<Reminder>> reminders({String? cropId}) => call(() async =>
      list((await dio.get('/reminders', queryParameters: {if (cropId != null) 'crop_id': cropId})).data, Reminder.fromJson));
  Future<Reminder> createReminder(Map<String, dynamic> data) =>
      call(() async => Reminder.fromJson((await dio.post('/reminders', data: data)).data));
  Future<Reminder> toggleReminder(String id) => call(() async => Reminder.fromJson((await dio.put('/reminders/$id/complete')).data));
  Future<void> deleteReminder(String id) => call(() => dio.delete('/reminders/$id'));

  Future<String> upload(List<int> bytes, String filename, {String folder = 'posts'}) => call(() async {
        final ext = filename.split('.').last.toLowerCase();
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType('image', ext == 'png' ? 'png' : 'jpeg')),
        });
        return (await dio.post('/uploads', data: form, queryParameters: {'folder': folder})).data['url'] as String;
      });
}
