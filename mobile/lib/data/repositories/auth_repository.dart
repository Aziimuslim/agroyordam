import 'package:dio/dio.dart';

import '../../domain/entities/entities.dart';
import 'base.dart';

class AuthRepository extends BaseRepository {
  AuthRepository(super.api);

  Future<void> login(String login, String password) => call(() async {
        final r = await dio.post('/auth/login', data: {'login': login.trim(), 'password': password});
        await api.storage.save(r.data['access_token'], r.data['refresh_token']);
      });

  /// To'g'ridan-to'g'ri ro'yxatdan o'tish (kod yuborish kanali ulanmaganda). Username server tomonidan yaratiladi.
  Future<void> register({
    required String fullName,
    String? email,
    String? phone,
    required String password,
    String? region,
    String? language,
    bool acceptTerms = false,
  }) =>
      call(() async {
        final r = await dio.post('/auth/register', data: {
          'full_name': fullName.trim(),
          if (email != null && email.isNotEmpty) 'email': email.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          'password': password,
          if (region != null && region.isNotEmpty) 'region': region,
          if (language != null) 'language': language,
          'accept_terms': acceptTerms,
        });
        await api.storage.save(r.data['access_token'], r.data['refresh_token']);
      });

  Future<AuthOptions> options() => call(() async => AuthOptions.fromJson((await dio.get('/auth/options')).data));

  Future<Challenge> challenge({required String purpose, required String channel, required String destination, Map<String, dynamic>? signup}) =>
      call(() async => Challenge.fromJson((await dio.post('/auth/challenges', data: {
            'purpose': purpose,
            'channel': channel,
            'destination': destination,
            if (signup != null) 'signup': signup,
          }))
              .data));

  Future<Challenge> resend(String id) => call(() async => Challenge.fromJson((await dio.post('/auth/challenges/$id/resend')).data));

  /// Kodni tasdiqlaydi. Sessiya bo'lsa tokenlar saqlanadi va null qaytadi; tiklashda recovery token qaytadi.
  Future<String?> verify(String id, String code) => call(() async {
        final d = (await dio.post('/auth/challenges/$id/verify', data: {'code': code})).data as Map;
        if (d['result'] == 'session') {
          await api.storage.save(d['access_token'], d['refresh_token']);
          return null;
        }
        return d['recovery_token'] as String?;
      });

  Future<void> recoveryReset(String token, String password) =>
      call(() => dio.post('/auth/recovery/reset', data: {'recovery_token': token, 'new_password': password}));

  Future<void> logout() async {
    try {
      final rt = await api.storage.readRefresh();
      if (rt != null) await dio.post('/auth/logout', data: {'refresh_token': rt});
    } catch (_) {}
    await api.storage.clear();
  }

  Future<AppUser> me() => call(() async => AppUser.fromJson((await dio.get('/users/me')).data));

  Future<AppUser> updateMe(Map<String, dynamic> data) =>
      call(() async => AppUser.fromJson((await dio.put('/users/me', data: data)).data));

  Future<void> changePassword(String current, String next, {bool logoutOthers = false}) => call(() async => dio.put('/users/me/password', data: {
        'current_password': current,
        'new_password': next,
        'refresh_token': await api.storage.readRefresh(), // shu qurilmadagi seans saqlanadi
        'logout_others': logoutOthers,
      }));

  Future<AppUser> uploadAvatar(List<int> bytes, String filename) => call(() async {
        final png = filename.toLowerCase().endsWith('.png');
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType('image', png ? 'png' : 'jpeg')),
        });
        return AppUser.fromJson((await dio.post('/users/me/avatar', data: form)).data);
      });

  Future<String?> forgotPassword(String login) => call(() async {
        final r = await dio.post('/auth/forgot-password', data: {'login': login});
        return r.data['dev_reset_token'] as String?;
      });

  Future<void> resetPassword(String token, String password) =>
      call(() => dio.post('/auth/reset-password', data: {'token': token, 'new_password': password}));
}
