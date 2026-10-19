import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ko'rinish sozlamalari (TZ S31): matn o'lchami va harakat. Qurilmada saqlanadi, chiqishda o'chirilmaydi.
class DisplayPrefs {
  const DisplayPrefs({this.largeText = false, this.reduceMotion = false});

  /// Katta matn — tizim shkalasiga qo'shimcha 1.15x.
  final bool largeText;

  /// Kamaytirilgan harakat; aks holda tizimga mos.
  final bool reduceMotion;

  double get textFactor => largeText ? 1.15 : 1.0;
  DisplayPrefs copyWith({bool? largeText, bool? reduceMotion}) =>
      DisplayPrefs(largeText: largeText ?? this.largeText, reduceMotion: reduceMotion ?? this.reduceMotion);
  @override
  bool operator ==(Object other) => other is DisplayPrefs && other.largeText == largeText && other.reduceMotion == reduceMotion;
  @override
  int get hashCode => Object.hash(largeText, reduceMotion);
}

class DisplayPrefsController extends Notifier<DisplayPrefs> {
  static const _text = 'agro_large_text', _motion = 'agro_reduce_motion';

  /// main() da birinchi kadrdan oldin o'qiladi (matn o'lchami va harakat sakramaydi).
  static DisplayPrefs? initial;

  static DisplayPrefs read(SharedPreferences p) => DisplayPrefs(largeText: p.getBool(_text) ?? false, reduceMotion: p.getBool(_motion) ?? false);

  @override
  DisplayPrefs build() {
    if (initial != null) return initial!;
    _load();
    return const DisplayPrefs();
  }

  Future<void> _load() async {
    try {
      state = read(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  Future<void> set(DisplayPrefs v) async {
    state = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_text, v.largeText);
      await p.setBool(_motion, v.reduceMotion);
    } catch (_) {}
  }
}

final displayPrefsProvider = NotifierProvider<DisplayPrefsController, DisplayPrefs>(DisplayPrefsController.new);

/// Nochiziqli matn shkalasi (Android 14 kabi): oddiy matn (≤ 16 px) to'liq kattalashadi, yirik sarlavhalar
/// kamroq — 30 px sarlavha 200% da ~1.5x. Shunda katta shriftda ham sarlavha so'z o'rtasidan bo'linmaydi (TZ QA14/DM07).
class NonlinearTextScaler extends TextScaler {
  const NonlinearTextScaler(this.factor);
  final double factor;

  @override
  double scale(double fontSize) {
    if (factor <= 1) return fontSize * factor;
    // 16 px gacha — to'liq; 16→32 px oralig'ida qo'shimcha kattalashish yarmiga tushadi
    final t = ((fontSize - 16) / 16).clamp(0.0, 1.0);
    final f = 1 + (factor - 1) * (1 - 0.5 * t);
    return fontSize * f;
  }

  // ignore: deprecated_member_use
  @override
  double get textScaleFactor => factor;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = double.infinity}) =>
      NonlinearTextScaler(factor.clamp(minScaleFactor, maxScaleFactor).toDouble());

  @override
  bool operator ==(Object other) => other is NonlinearTextScaler && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;
}

/// MaterialApp.builder uchun: matn shkalasi va kamaytirilgan harakatni butun ilovaga qo'llaydi.
Widget applyDisplayPrefs(BuildContext context, DisplayPrefs prefs, Widget? child) {
  final mq = MediaQuery.of(context);
  // Tizim shkalasi × ilovadagi "Katta matn"; 2x dan oshmaydi
  final factor = (mq.textScaler.scale(14) / 14 * prefs.textFactor).clamp(1.0, 2.0).toDouble();
  return MediaQuery(
    data: mq.copyWith(
      textScaler: factor == 1.0 ? mq.textScaler : NonlinearTextScaler(factor),
      disableAnimations: mq.disableAnimations || prefs.reduceMotion,
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
