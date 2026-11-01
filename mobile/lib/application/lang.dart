import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/i18n.dart';
import '../domain/entities/entities.dart';
import 'providers.dart';

/// Ilova tili: qurilmada saqlanadi va (kirgan bo'lsa) profilga yoziladi.
/// Bir akkauntdagi barcha qurilmalarda oxirgi tanlangan til ishlaydi: profildagi tanlov vaqti
/// ([AppUser.languageUpdatedAt]) shu qurilmada oxirgi qo'llangan vaqtdan yangi bo'lsa — o'sha til olinadi.
class LangController extends Notifier<AppLang> {
  static const _key = 'agro_lang';
  static const _atKey = 'agro_lang_at'; // shu qurilmada qo'llangan tanlovning server vaqti
  AppLifecycleListener? _life;

  @override
  AppLang build() {
    // Kirish, profil yangilanishi va ilova qayta ochilganda profildagi til tekshiriladi
    ref.listen<AppUser?>(currentUserProvider, (prev, next) {
      if (next != null && (prev?.id != next.id || prev?.languageUpdatedAt != next.languageUpdatedAt || prev?.language != next.language)) {
        _sync(next);
      }
    }, fireImmediately: true);
    _life ??= AppLifecycleListener(onResume: () {
      ref.read(authProvider.notifier).refreshUser().catchError((_) {});
    });
    ref.onDispose(() {
      _life?.dispose();
      _life = null;
    });
    return I18n.lang; // main() ishga tushishda saqlangan tilni o'qib qo'ygan
  }

  void _apply(AppLang l) {
    if (I18n.lang == l && state == l) return;
    I18n.lang = l;
    state = l;
    // const vidjetlar ham qayta qurilsin (aks holda eski tildagi matn qoladi)
    WidgetsBinding.instance.reassembleApplication();
  }

  Future<void> _sync(AppUser u) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localCode = prefs.getString(_key);
      final localAt = DateTime.tryParse(prefs.getString(_atKey) ?? '');
      final serverAt = u.languageUpdatedAt;
      if (serverAt != null) {
        if (localAt == null || serverAt.isAfter(localAt)) {
          // Boshqa qurilmada yangiroq tanlov — shu yerda ham qo'llanadi
          _apply(AppLang.fromCode(u.language));
          await prefs.setString(_key, u.language);
          await prefs.setString(_atKey, serverAt.toIso8601String());
        }
      } else if (localCode != null) {
        // Profilda hali tanlov yo'q — shu qurilmadagi tanlov profilga yoziladi (boshqalar uni oladi)
        await ref.read(authProvider.notifier).updateProfile({'language': localCode});
      }
    } catch (_) {}
  }

  Future<void> set(AppLang l) async {
    _apply(l);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, l.code);
      // Server vaqti kelguncha hozirgi vaqt: eski server tanlovi bu tanlovni bosib ketmasin
      await prefs.setString(_atKey, DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
    try {
      if (ref.read(currentUserProvider) != null) {
        await ref.read(authProvider.notifier).updateProfile({'language': l.code});
        // Soat farqi bo'lmasin: server vaqtini saqlaymiz
        final at = ref.read(currentUserProvider)?.languageUpdatedAt;
        if (at != null) await (await SharedPreferences.getInstance()).setString(_atKey, at.toIso8601String());
      }
    } catch (_) {}
  }
}

final langProvider = NotifierProvider<LangController, AppLang>(LangController.new);
