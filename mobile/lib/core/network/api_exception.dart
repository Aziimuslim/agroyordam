import 'package:dio/dio.dart';
import '../i18n/i18n.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.retryAfter, this.attemptsLeft});
  final String message;
  final int? statusCode;

  /// 429 javobidagi Retry-After (soniya) — tugma shuncha vaqt o'chiq turadi (TZ S33/S35).
  final int? retryAfter;

  /// Kod tekshiruvida qolgan urinishlar (X-Attempts-Left).
  final int? attemptsLeft;

  bool get isPaymentRequired => statusCode == 402;
  bool get isUnauthorized => statusCode == 401;

  factory ApiException.from(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final data = e.response?.data;
      String? msg;
      if (data is Map && data['detail'] != null) {
        final d = data['detail'];
        if (d is String) {
          msg = tr(d); // server xabarlari ham lug'atda bo'lsa tarjima qilinadi
        } else if (d is List && d.isNotEmpty && d.first is Map) {
          msg = (d.first as Map)['msg']?.toString().replaceFirst('Value error, ', '');
        }
      }
      if (msg == null) {
        switch (e.type) {
          case DioExceptionType.connectionError:
          case DioExceptionType.connectionTimeout:
            msg = tr("Server bilan aloqa yo'q. Internetni tekshiring.");
          case DioExceptionType.receiveTimeout:
            msg = tr("Server javob bermadi. Qayta urinib ko'ring.");
          default:
            msg = trf('Xatolik yuz berdi ({0})', [e.response?.statusCode ?? '-']);
        }
      }
      final h = e.response?.headers;
      return ApiException(
        msg,
        statusCode: e.response?.statusCode,
        retryAfter: int.tryParse(h?.value('retry-after') ?? ''),
        attemptsLeft: int.tryParse(h?.value('x-attempts-left') ?? ''),
      );
    }
    return ApiException(e.toString());
  }

  @override
  String toString() => message;
}
