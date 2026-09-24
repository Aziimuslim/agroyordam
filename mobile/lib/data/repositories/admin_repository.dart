import '../../domain/entities/entities.dart';
import 'base.dart';

class AdminRepository extends BaseRepository {
  AdminRepository(super.api);

  Future<Map<String, dynamic>> platform() => call(() async => Map<String, dynamic>.from((await dio.get('/admin/stats/platform')).data));
  Future<Map<String, dynamic>> ai() => call(() async => Map<String, dynamic>.from((await dio.get('/admin/stats/ai')).data));
  Future<Map<String, dynamic>> revenue() => call(() async => Map<String, dynamic>.from((await dio.get('/admin/stats/revenue')).data));
  Future<List<AppUser>> users({String? q}) =>
      call(() async => list((await dio.get('/admin/users', queryParameters: {if (q != null && q.isNotEmpty) 'q': q})).data, AppUser.fromJson));
  Future<void> block(String id, bool blocked) => call(() => dio.put('/admin/users/$id/block', queryParameters: {'blocked': blocked}));
  Future<List<Map<String, dynamic>>> reports() =>
      call(() async => List<Map<String, dynamic>>.from((await dio.get('/reports', queryParameters: {'status_': 'pending'})).data));
  Future<void> resolve(String id, {bool remove = false}) =>
      call(() => dio.put('/reports/$id/resolve', queryParameters: {'remove_content': remove}));

  // Dataset yig'ish
  Future<Map<String, dynamic>> datasetStats() =>
      call(() async => Map<String, dynamic>.from((await dio.get('/admin/dataset/stats')).data));
  Future<List<String>> datasetLabels() => call(() async => List<String>.from((await dio.get('/admin/dataset/labels')).data));
  Future<List<DatasetItem>> datasetItems({String status = 'pending', bool flagged = false, int offset = 0}) => call(() async => list(
      (await dio.get('/admin/dataset/items', queryParameters: {'status': status, if (flagged) 'flagged': true, 'offset': offset, 'limit': 30})).data,
      DatasetItem.fromJson));
  Future<void> review(String id, String status, {String? label}) =>
      call(() => dio.put('/admin/dataset/items/$id', data: {'status': status, if (label != null) 'label': label}));
  Future<String> exportLink() => call(() async => (await dio.post('/admin/dataset/export-link')).data['url'] as String);
}
