import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  static const key = 'agro_theme_mode';
  static const _key = key;

  /// main() da birinchi kadrdan oldin o'qiladi — noto'g'ri mavzu chaqnashi bo'lmaydi (TZ DM01).
  static ThemeMode? initial;

  static ThemeMode parse(String? v) => ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);

  @override
  ThemeMode build() {
    if (initial != null) return initial!;
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      if (v != null) state = parse(v);
    } catch (_) {}
  }

  Future<void> cycle() => set(switch (state) { ThemeMode.system => ThemeMode.light, ThemeMode.light => ThemeMode.dark, _ => ThemeMode.system });

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      (await SharedPreferences.getInstance()).setString(_key, state.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
