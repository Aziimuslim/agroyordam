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
    required this.expert,
    required this.expertBg,
    required this.onExpert,
    required this.lineStrong,
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

  /// Yashil dala 2.0: agronom roli rangi (tuproq) — "Agronom javobi", agronom rejimi, "Agronomga yuborish".
  final Color expert, expertBg, onExpert;

  /// Kiritish maydonlari va katakchalar chegarasi (sirt ustida 3:1 kontrast).
  final Color lineStrong;

  // Nomlar tarixiy (cream/tan/gold...), qiymatlar — "Yashil dala 2.0" tokenlari (docs/redesign/tokens.json):
  // cream=bg/canvas, cream2=bg/surface-muted, card=bg/surface, primaryDark=brand/primary-deep,
  // primaryLight=brand/primary-soft, gold=brand/accent, dark=ajratilgan to'q sirt.
  static const light = AppColors(
    cream: Color(0xFFF4F7F2),
    cream2: Color(0xFFEAF1E6),
    card: Color(0xFFFFFFFF),
    tan: Color(0xFFE3ECDF),
    primary: Color(0xFF1D6B43),
    primaryDark: Color(0xFF0F3D27),
    primaryLight: Color(0xFFDCEFE2),
    dark: Color(0xFF0F3D27),
    text: Color(0xFF0F2419),
    muted: Color(0xFF55685D),
    border: Color(0xFFDCE5D8),
    success: Color(0xFF1F7A4D),
    successBg: Color(0xFFDDF1E5),
    danger: Color(0xFFB8322A),
    dangerBg: Color(0xFFFBE3E0),
    gold: Color(0xFFF2B33D),
    onGold: Color(0xFF3A2A00),
    onDark: Color(0xFFFFFFFF),
    onDarkMuted: Color(0xFFB9D3C3),
    tagCare: Color(0xFFDCEFE2),
    onTagCare: Color(0xFF1D6B43),
    tagTreat: Color(0xFFFDF1D2),
    shadow: Color(0x140F2419),
    avatarPalette: [Color(0xFF1D6B43), Color(0xFF2F6FA3), Color(0xFFA86B00), Color(0xFF0F3D27), Color(0xFF7A5AA6)],
    accentSoft: Color(0xFFFDF1D2),
    warning: Color(0xFF9A4A06),
    warningBg: Color(0xFFFDEBD3),
    info: Color(0xFF1F5FAD),
    infoBg: Color(0xFFE3EEFB),
    subtle: Color(0xFF66796E),
    expert: Color(0xFF8A5A2B),
    expertBg: Color(0xFFF3E6D6),
    onExpert: Color(0xFFFFFFFF),
    lineStrong: Color(0xFF7A8F80),
  );

  static const darkTheme = AppColors(
    cream: Color(0xFF0C1611),
    cream2: Color(0xFF1A2B22),
    card: Color(0xFF13211A),
    tan: Color(0xFF213328),
    primary: Color(0xFF5CC08B),
    primaryDark: Color(0xFFA7E3C4),
    primaryLight: Color(0xFF173A28),
    dark: Color(0xFF123A27),
    text: Color(0xFFE7F0EA),
    muted: Color(0xFF9FB4A8),
    border: Color(0xFF2A3D32),
    success: Color(0xFF6FD39C),
    successBg: Color(0xFF163626),
    danger: Color(0xFFFF8A7F),
    dangerBg: Color(0xFF3D1A17),
    gold: Color(0xFFF2B33D),
    onGold: Color(0xFF3A2A00),
    onDark: Color(0xFFE7F0EA),
    onDarkMuted: Color(0xFF9FC4AE),
    tagCare: Color(0xFF173A28),
    onTagCare: Color(0xFF9CD6B6),
    tagTreat: Color(0xFF3A2D10),
    shadow: Color(0x40000000),
    avatarPalette: [Color(0xFF3FA070), Color(0xFF5B8CC5), Color(0xFFC99A2E), Color(0xFF2E7D55), Color(0xFF9A7AC6)],
    accentSoft: Color(0xFF3A2D10),
    warning: Color(0xFFF5A524),
    warningBg: Color(0xFF3B2810),
    info: Color(0xFF8DB8F5),
    infoBg: Color(0xFF15263D),
    subtle: Color(0xFF879D90),
    expert: Color(0xFFE0B07A),
    expertBg: Color(0xFF33241A),
    onExpert: Color(0xFF241505),
    lineStrong: Color(0xFF6E8A79),
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
