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
}
