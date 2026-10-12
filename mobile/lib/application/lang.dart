import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/i18n.dart';
import 'providers.dart';

/// Ilova tili: qurilmada saqlanadi va (kirgan bo'lsa) profilga yoziladi.
class LangController extends Notifier<AppLang> {
  static const _key = 'agro_lang';

  @override
  AppLang build() => I18n.lang; // main() ishga tushishda saqlangan tilni o'qib qo'ygan

  void _apply(AppLang l) {
    I18n.lang = l;
    state = l;
    // const vidjetlar ham qayta qurilsin (aks holda eski tildagi matn qoladi)
    WidgetsBinding.instance.reassembleApplication();
  }

  Future<void> set(AppLang l) async {
    _apply(l);
    try {
      (await SharedPreferences.getInstance()).setString(_key, l.code);
    } catch (_) {}
    try {
      if (ref.read(currentUserProvider) != null) await ref.read(authProvider.notifier).updateProfile({'language': l.code});
    } catch (_) {}
  }
}

final langProvider = NotifierProvider<LangController, AppLang>(LangController.new);
