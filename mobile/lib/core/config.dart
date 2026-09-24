import 'package:flutter/foundation.dart';

class AppConfig {
  static const appName = 'AgroYordam';
  static const version = '0.1.2';

  static const _apiOverride = String.fromEnvironment('API_URL');
  static const prefsKey = 'agro_server_url';

  /// Foydalanuvchi ilova ichida kiritgan server manzili (masalan, telefonda http://192.168.1.10:8000).
  static String? runtimeOverride;

  /// Backend manzili:
  /// - `--dart-define=API_URL=...` berilsa — o'sha;
  /// - web release (nginx orqasida) — joriy origin;
  /// - Android emulyator — 10.0.2.2; boshqa hollarda — localhost.
  static String get apiUrl {
    if (runtimeOverride != null && runtimeOverride!.isNotEmpty) return runtimeOverride!;
    if (_apiOverride.isNotEmpty) return _apiOverride;
    if (kIsWeb) return kReleaseMode ? Uri.base.origin : 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  static String get wsUrl => apiUrl.replaceFirst(RegExp('^http'), 'ws');

  /// Nisbiy media yo'lini (`/media/...`) to'liq URL'ga aylantiradi.
  static String? mediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$apiUrl$path';
  }
}
