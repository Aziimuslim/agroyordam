import 'dart:async';

import 'package:dio/dio.dart';

import '../config.dart';
import '../storage/token_storage.dart';
import '../i18n/i18n.dart';
import '../i18n/translit.dart';

/// JWT'ni avtomatik qo'shadi va 401 bo'lsa refresh token bilan bir marta yangilaydi.
class ApiClient {
  ApiClient(this.storage, {Dio? dio, this.onSessionExpired})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: '${AppConfig.apiUrl}/api/v1',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            )) {
    this.dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await storage.readAccess();
            if (token != null && options.headers['Authorization'] == null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
          onResponse: (res, handler) {
            // "Lotin (amaldagi)": server matni yangi harflarda (ö, ğ, ş, ç) — ekranga amaldagi yozuvda
            if (I18n.lang == AppLang.uzOld && res.requestOptions.responseType == ResponseType.json && res.data != null) {
              res.data = oldLatinJson(res.data);
            }
            handler.next(res);
          },
          onError: (err, handler) async {
            final req = err.requestOptions;
            final isAuthCall = req.path.startsWith('/auth/');
            if (err.response?.statusCode == 401 && !isAuthCall && req.extra['retried'] != true) {
              if (await _refresh()) {
                req.extra['retried'] = true;
                req.headers['Authorization'] = 'Bearer ${await storage.readAccess()}';
                try {
                  return handler.resolve(await this.dio.fetch(req));
                } on DioException catch (e) {
                  return handler.next(e);
                }
              }
              onSessionExpired?.call();
            }
            handler.next(err);
          },
        ));
  }

  final Dio dio;
  final TokenStorage storage;
  final void Function()? onSessionExpired;
  Completer<bool>? _refreshing;

  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    try {
      final rt = await storage.readRefresh();
      if (rt == null) {
        c.complete(false);
      } else {
        final r = await dio.post('/auth/refresh', data: {'refresh_token': rt});
        await storage.save(r.data['access_token'], r.data['refresh_token']);
        c.complete(true);
      }
    } catch (_) {
      await storage.clear();
      c.complete(false);
    } finally {
      _refreshing = null;
    }
    return c.future;
  }
}

/// JSON ichidagi barcha matnlarni amaldagi lotinga o'tkazadi (faqat ö, ğ, ş, ç harflari o'zgaradi — id, havola, email tegilmaydi).
Object? oldLatinJson(Object? v) => switch (v) {
      String s => toOldLatin(s),
      List l => <dynamic>[for (final x in l) oldLatinJson(x)],
      Map m => <String, dynamic>{for (final e in m.entries) '${e.key}': oldLatinJson(e.value)},
      _ => v,
    };

