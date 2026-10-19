import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'application/display_prefs.dart';
import 'application/theme_mode.dart';
import 'core/config.dart';
import 'core/i18n/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    AppConfig.runtimeOverride = prefs.getString(AppConfig.prefsKey);
    I18n.lang = AppLang.fromCode(prefs.getString('agro_lang')); // birinchi kadrdanoq tanlangan tilda
    // Mavzu va ko'rinish ham birinchi kadrdan (TZ DM01: noto'g'ri mavzu chaqnashi yo'q)
    ThemeModeController.initial = ThemeModeController.parse(prefs.getString(ThemeModeController.key));
    DisplayPrefsController.initial = DisplayPrefsController.read(prefs);
  } catch (_) {}
  usePathUrlStrategy();
  // Web: push() bilan ochilgan sahifalar ham manzil satrida ko'rinadi (yangilanganda saqlanadi)
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(ProviderScope(
    retry: (retryCount, error) => null, // xatoda avtomatik qayta so'ramaymiz — foydalanuvchi "Qayta urinish" bosadi
    child: const AgroYordamApp(),
  ));
}
