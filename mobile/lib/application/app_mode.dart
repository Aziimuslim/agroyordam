import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// Agronom ilovani qaysi rejimda ochadi: agronom rejimi (navbat, savollar, bilimlar) yoki dehqon rejimi.
/// Tanlov qurilmada saqlanadi; oddiy foydalanuvchi uchun har doim dehqon rejimi.
class ExpertModeController extends Notifier<bool> {
  static const _key = 'agro_expert_mode';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getBool(_key);
      if (v != null) state = v;
    } catch (_) {}
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      (await SharedPreferences.getInstance()).setBool(_key, on);
    } catch (_) {}
  }
}

final expertModePrefProvider = NotifierProvider<ExpertModeController, bool>(ExpertModeController.new);

/// Agronom rejimi faolmi (rol + tanlov).
final expertModeProvider = Provider<bool>((ref) => (ref.watch(currentUserProvider)?.canReview ?? false) && ref.watch(expertModePrefProvider));
