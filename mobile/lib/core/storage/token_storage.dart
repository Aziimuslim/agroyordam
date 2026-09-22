import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStorage {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save(String access, String refresh);
  Future<void> clear();
}

/// Tokenlar flutter_secure_storage'da (Keychain / Keystore / web'da shifrlangan storage).
class SecureTokenStorage implements TokenStorage {
  static const _a = 'agro_access', _r = 'agro_refresh';
  final _s = const FlutterSecureStorage();

  @override
  Future<String?> readAccess() => _s.read(key: _a);
  @override
  Future<String?> readRefresh() => _s.read(key: _r);
  @override
  Future<void> save(String access, String refresh) async {
    await _s.write(key: _a, value: access);
    await _s.write(key: _r, value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: _a);
    await _s.delete(key: _r);
  }
}

class MemoryTokenStorage implements TokenStorage {
  String? access, refresh;
  @override
  Future<String?> readAccess() async => access;
  @override
  Future<String?> readRefresh() async => refresh;
  @override
  Future<void> save(String a, String r) async {
    access = a;
    refresh = r;
  }

  @override
  Future<void> clear() async => access = refresh = null;
}
