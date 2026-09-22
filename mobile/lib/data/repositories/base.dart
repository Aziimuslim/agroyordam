import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

abstract class BaseRepository {
  BaseRepository(this.api);
  final ApiClient api;
  Dio get dio => api.dio;

  Future<T> call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  List<T> list<T>(dynamic data, T Function(Map<String, dynamic>) f) =>
      [for (final e in (data as List)) f(Map<String, dynamic>.from(e))];
}
