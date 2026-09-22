import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';

void main() {
  usePathUrlStrategy();
  // Web: push() bilan ochilgan sahifalar ham manzil satrida ko'rinadi (yangilanganda saqlanadi)
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(ProviderScope(
    retry: (retryCount, error) => null, // xatoda avtomatik qayta so'ramaymiz — foydalanuvchi "Qayta urinish" bosadi
    child: const AgroYordamApp(),
  ));
}
