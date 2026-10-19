import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'application/display_prefs.dart';
import 'application/lang.dart';
import 'application/theme_mode.dart';
import 'core/config.dart';
import 'core/i18n/i18n.dart';
import 'core/theme/app_theme.dart';
import 'presentation/router.dart';

class AgroYordamApp extends ConsumerStatefulWidget {
  const AgroYordamApp({super.key});
  @override
  ConsumerState<AgroYordamApp> createState() => _AgroYordamAppState();
}

class _AgroYordamAppState extends ConsumerState<AgroYordamApp> {
  // Agronom rejimi (/expert...) bu bosqichda eski "Yashil dala" mavzusida qoladi (TZ: agronom paneli keyingi bosqich)
  bool _expert = false;
  GoRouter? _router;

  void _onRoute() {
    final expert = _router!.routerDelegate.currentConfiguration.uri.path.startsWith('/expert');
    if (expert == _expert) return;
    // Router build paytida xabar berishi mumkin — mavzuni keyingi kadrda almashtiramiz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _expert != expert) setState(() => _expert = expert);
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final router = ref.watch(routerProvider);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router..routerDelegate.addListener(_onRoute);
    }
    return _app(lang, ref, router, _expert);
  }

  Widget _app(AppLang lang, WidgetRef ref, GoRouter router, bool expert) {
    final prefs = ref.watch(displayPrefsProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: expert ? AppTheme.legacyLight : AppTheme.light,
      darkTheme: expert ? AppTheme.legacyDark : AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // TZ 13.3: mavzu almashishi 150–200 ms rang o'tishi
      themeAnimationDuration: Duration(milliseconds: prefs.reduceMotion ? 0 : 180),
      routerConfig: router,
      builder: (context, child) => applyDisplayPrefs(context, prefs, child),
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
