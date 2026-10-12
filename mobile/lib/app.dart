import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/lang.dart';
import 'application/theme_mode.dart';
import 'core/config.dart';
import 'core/i18n/i18n.dart';
import 'core/theme/app_theme.dart';
import 'presentation/router.dart';

class AgroYordamApp extends ConsumerWidget {
  const AgroYordamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      // Qoraqalpoq va kirill uchun Material o'zbekcha matnlaridan foydalanadi
      locale: Locale(switch (lang) { AppLang.ru => 'ru', AppLang.en => 'en', _ => 'uz' }),
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
