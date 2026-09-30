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
    required this.onDark,
    required this.onDarkMuted,
    required this.tagCare,
    required this.onTagCare,
    required this.tagTreat,
    required this.shadow,
    required this.avatarPalette,
    required this.accentSoft,
    required this.warning,
    required this.warningBg,
    required this.info,
    required this.infoBg,
    required this.subtle,
  });

  final Color cream, cream2, card, tan;
  final Color primary, primaryDark, primaryLight;
  final Color dark, text, muted, border;
  final Color success, successBg, danger, dangerBg, gold, onGold, onDarkMuted;

  /// `dark` — ajratilgan (to'q) sirt: asosiy tugmalar, "Obunam"/"Jamoat" kartalari, Premium kartasi, snackbar.
  /// `onDark` — shu sirt ustidagi matn/ikonka rangi. Ikkala mavzuda ham kontrast yetarli bo'lishi shart.
  final Color onDark;
  final Color tagCare, onTagCare, tagTreat, shadow;
  final List<Color> avatarPalette;

  /// Dizayn tizimi "Yashil dala" (Figma: AgroYordam — Dizayn tizimi): accent-soft, warning, info, text/tertiary.
  final Color accentSoft, warning, warningBg, info, infoBg, subtle;

  // Nomlar tarixiy (cream/tan/gold...), qiymatlar — Figma'dagi "Yashil dala" tokenlari:
  // cream=bg/canvas, cream2=bg/surface-muted, card=bg/surface, primaryDark=brand/primary-deep,
  // primaryLight=brand/primary-soft, gold=brand/accent, dark=ajratilgan to'q sirt.
  static const light = AppColors(
    cream: Color(0xFFF3F6F1),
    cream2: Color(0xFFE8F0E4),
    card: Color(0xFFFFFFFF),
    tan: Color(0xFFE3EDDF),
    primary: Color(0xFF1D6B43),
    primaryDark: Color(0xFF0F3D27),
    primaryLight: Color(0xFFDCEFE2),
    dark: Color(0xFF0F3D27),
    text: Color(0xFF0F2419),
    muted: Color(0xFF5C6E64),
    border: Color(0xFFDDE6DA),
    success: Color(0xFF1D6B43),
    successBg: Color(0xFFDCEFE2),
    danger: Color(0xFFC8382E),
    dangerBg: Color(0xFFFBE2DF),
    gold: Color(0xFFF4B63E),
    onGold: Color(0xFF3A2A00),
    onDark: Color(0xFFFFFFFF),
    onDarkMuted: Color(0xFFB9D3C3),
    tagCare: Color(0xFFDCEFE2),
    onTagCare: Color(0xFF1D6B43),
    tagTreat: Color(0xFFFDF1D2),
    shadow: Color(0x140F2419),
    avatarPalette: [Color(0xFF1D6B43), Color(0xFF2F6FA3), Color(0xFFA86B00), Color(0xFF0F3D27), Color(0xFF7A5AA6)],
    accentSoft: Color(0xFFFDF1D2),
    warning: Color(0xFFA86B00),
    warningBg: Color(0xFFFDF1D2),
    info: Color(0xFF2F6FA3),
    infoBg: Color(0xFFE2EEF8),
    subtle: Color(0xFF8A9A91),
  );

  static const darkTheme = AppColors(
    cream: Color(0xFF0E1712),
    cream2: Color(0xFF1E2C24),
    card: Color(0xFF16211B),
    tan: Color(0xFF243429),
    primary: Color(0xFF4CB782),
    primaryDark: Color(0xFFA7E3C4),
    primaryLight: Color(0xFF1C3A2A),
    dark: Color(0xFF245A3E),
    text: Color(0xFFEAF2EC),
    muted: Color(0xFF9FB2A7),
    border: Color(0xFF2A3A31),
    success: Color(0xFF4CB782),
    successBg: Color(0xFF1C3A2A),
    danger: Color(0xFFF07A6E),
    dangerBg: Color(0xFF3A1C19),
    gold: Color(0xFFF4B63E),
    onGold: Color(0xFF2A1E00),
    onDark: Color(0xFFF1F7F3),
    onDarkMuted: Color(0xFFC6DDD0),
    tagCare: Color(0xFF1C3A2A),
    onTagCare: Color(0xFF9CD6B6),
    tagTreat: Color(0xFF3A2E10),
    shadow: Color(0x40000000),
    avatarPalette: [Color(0xFF3FA070), Color(0xFF5B8CC5), Color(0xFFC99A2E), Color(0xFF2E7D55), Color(0xFF9A7AC6)],
    accentSoft: Color(0xFF3A2E10),
    warning: Color(0xFFF0B44C),
    warningBg: Color(0xFF3A2E10),
    info: Color(0xFF7DB6E6),
    infoBg: Color(0xFF16283A),
    subtle: Color(0xFF6F8378),
  );

  /// Sog'liq foizi bo'yicha semantik rang.
  Color health(int pct) => pct >= 70 ? success : (pct >= 45 ? warning : danger);
  Color healthBg(int pct) => pct >= 70 ? successBg : (pct >= 45 ? warningBg : dangerBg);

  Color avatarFor(String seed) => avatarPalette[seed.hashCode.abs() % avatarPalette.length];

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}
