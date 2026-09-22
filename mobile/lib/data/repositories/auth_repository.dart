import '../../domain/entities/entities.dart';
import 'base.dart';

class AuthRepository extends BaseRepository {
  AuthRepository(super.api);

  Future<void> login(String login, String password) => call(() async {
        final r = await dio.post('/auth/login', data: {'login': login.trim(), 'password': password});
        await api.storage.save(r.data['access_token'], r.data['refresh_token']);
      });

  Future<void> register({
    required String fullName,
    required String username,
    String? email,
    String? phone,
    required String password,
    String? region,
  }) =>
      call(() async {
        final r = await dio.post('/auth/register', data: {
          'full_name': fullName.trim(),
          'username': username.trim(),
          if (email != null && email.isNotEmpty) 'email': email.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          'password': password,
          if (region != null && region.isNotEmpty) 'region': region,
        });
        await api.storage.save(r.data['access_token'], r.data['refresh_token']);
      });

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

  Future<String?> forgotPassword(String login) => call(() async {
        final r = await dio.post('/auth/forgot-password', data: {'login': login});
        return r.data['dev_reset_token'] as String?;
      });

  Future<void> resetPassword(String token, String password) =>
      call(() => dio.post('/auth/reset-password', data: {'token': token, 'new_password': password}));
}
