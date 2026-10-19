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

  @override
  DisplayPrefs build() {
    _load();
    return const DisplayPrefs();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = DisplayPrefs(largeText: p.getBool(_text) ?? false, reduceMotion: p.getBool(_motion) ?? false);
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

/// MaterialApp.builder uchun: matn shkalasi va kamaytirilgan harakatni butun ilovaga qo'llaydi.
Widget applyDisplayPrefs(BuildContext context, DisplayPrefs prefs, Widget? child) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: prefs.largeText ? TextScaler.linear(mq.textScaler.scale(1) * prefs.textFactor) : mq.textScaler,
      disableAnimations: mq.disableAnimations || prefs.reduceMotion,
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
