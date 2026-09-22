import 'package:flutter/material.dart';

/// Dizayn tokenlari — ilovaning yagona rang manbai.
/// Boshqa hech bir faylda hardcoded hex bo'lmasligi kerak.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.cream,
    required this.cream2,
    required this.card,
    required this.tan,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.dark,
    required this.text,
    required this.muted,
    required this.border,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.gold,
    required this.onGold,
    required this.onDarkMuted,
    required this.tagCare,
    required this.onTagCare,
    required this.tagTreat,
    required this.shadow,
    required this.avatarPalette,
  });

  final Color cream, cream2, card, tan;
  final Color primary, primaryDark, primaryLight;
  final Color dark, text, muted, border;
  final Color success, successBg, danger, dangerBg, gold, onGold, onDarkMuted;
  final Color tagCare, onTagCare, tagTreat, shadow;
  final List<Color> avatarPalette;

  static const light = AppColors(
    cream: Color(0xFFFBF1E0),
    cream2: Color(0xFFF6E7CC),
    card: Color(0xFFFFFFFF),
    tan: Color(0xFFF0DDA8),
    primary: Color(0xFFB25A28),
    primaryDark: Color(0xFF8F4620),
    primaryLight: Color(0xFFF4D9BE),
    dark: Color(0xFF241B14),
    text: Color(0xFF2B2118),
    muted: Color(0xFF8B7E6C),
    border: Color(0xFFEDE0C6),
    success: Color(0xFF4C7A3D),
    successBg: Color(0xFFE1EEDB),
    danger: Color(0xFFB3413A),
    dangerBg: Color(0xFFF5DEDB),
    gold: Color(0xFFE3AA3D),
    onGold: Color(0xFF3A2A0E),
    onDarkMuted: Color(0xFFC9BCA8),
    tagCare: Color(0xFFDCEAD5),
    onTagCare: Color(0xFF3E6B34),
    tagTreat: Color(0xFFF3D9CF),
    shadow: Color(0x14281910),
    avatarPalette: [Color(0xFFB25A28), Color(0xFF3B6EA5), Color(0xFF4C7A3D), Color(0xFF8F4620), Color(0xFF7A5AA6)],
  );

  static const darkTheme = AppColors(
    cream: Color(0xFF1B1712),
    cream2: Color(0xFF221C15),
    card: Color(0xFF2A231B),
    tan: Color(0xFF4A3B22),
    primary: Color(0xFFC8703D),
    primaryDark: Color(0xFFE0A077),
    primaryLight: Color(0xFF3E2A1C),
    dark: Color(0xFF120E0A),
    text: Color(0xFFF2E9DA),
    muted: Color(0xFFB6A98F),
    border: Color(0xFF3A3025),
    success: Color(0xFF7DB36A),
    successBg: Color(0xFF26331F),
    danger: Color(0xFFE0766E),
    dangerBg: Color(0xFF3A2220),
    gold: Color(0xFFE3AA3D),
    onGold: Color(0xFF3A2A0E),
    onDarkMuted: Color(0xFFC9BCA8),
    tagCare: Color(0xFF26331F),
    onTagCare: Color(0xFF9CCB8A),
    tagTreat: Color(0xFF3E2A1C),
    shadow: Color(0x33000000),
    avatarPalette: [Color(0xFFC8703D), Color(0xFF5B8CC5), Color(0xFF6E9E5C), Color(0xFFB0683A), Color(0xFF9A7AC6)],
  );

  /// Sog'liq foizi bo'yicha semantik rang.
  Color health(int pct) => pct >= 70 ? success : (pct >= 45 ? gold : danger);
  Color healthBg(int pct) => pct >= 70 ? successBg : (pct >= 45 ? primaryLight : dangerBg);

  Color avatarFor(String seed) => avatarPalette[seed.hashCode.abs() % avatarPalette.length];

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}
