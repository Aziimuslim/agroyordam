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
    required this.olive,
    required this.onOlive,
    required this.oliveSoft,
    required this.onOliveSoft,
    required this.focus,
    required this.scrim,
    required this.inputSurface,
    required this.onPrimary,
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

  /// Tabiiy Agro: tanlangan tab/filtr/segment (zaytun) va uning ustidagi matn; yumshoq zaytun fon.
  final Color olive, onOlive, oliveSoft, onOliveSoft;

  /// Fokus konturi (2 px), modal orqa fon pardasi, kiritish maydoni sirti.
  final Color focus, scrim, inputSurface;

  /// Asosiy amal (terrakota) ustidagi matn: light — oq, dark — to'q (TZ 13.2).
  final Color onPrimary;

  // Tabiiy Agro (TZ v1.1, 13.2-bo'lim) — foydalanuvchi ilovasi. Tarixiy nomlar → semantik ma'no:
  // cream=background, card=surface, cream2=surfaceRaised, primary=primaryAction (terrakota),
  // dark=ajratilgan sirt (zaytun), olive=selectionFill, text/muted=textPrimary/Secondary.
  static const light = AppColors(
    cream: Color(0xFFFBF6EA),
    cream2: Color(0xFFF5F1E7),
    card: Color(0xFFFFFFFF),
    tan: Color(0xFFEFE8D6),
    primary: Color(0xFFAF5032), // TZ #B95636 → krem fonda kichik matn 4.5:1 bo'lishi uchun biroz to'qroq
    primaryDark: Color(0xFF8E3E22),
    primaryLight: Color(0xFFF7E5DA),
    dark: Color(0xFF515C2D),
    text: Color(0xFF20251B),
    muted: Color(0xFF606557),
    border: Color(0xFFDEDCCD),
    success: Color(0xFF28603D),
    successBg: Color(0xFFE2EEDB),
    danger: Color(0xFFB3261E),
    dangerBg: Color(0xFFFBE3DE),
    gold: Color(0xFFD9A21B),
    onGold: Color(0xFF2E2200),
    onDark: Color(0xFFFFFFFF),
    onDarkMuted: Color(0xFFDDE3C8),
    tagCare: Color(0xFFE9ECD8),
    onTagCare: Color(0xFF3F4822),
    tagTreat: Color(0xFFFCEBD5),
    shadow: Color(0x1420251B),
    avatarPalette: [Color(0xFF515C2D), Color(0xFFB95636), Color(0xFF7A5A1E), Color(0xFF3F6B4E), Color(0xFF6B5B8C)],
    accentSoft: Color(0xFFF8ECCF),
    warning: Color(0xFF8A4B08),
    warningBg: Color(0xFFFCEBD5),
    info: Color(0xFF2F5E8C),
    infoBg: Color(0xFFE4EDF6),
    subtle: Color(0xFF6B6F60),
    expert: Color(0xFF8A5A2B),
    expertBg: Color(0xFFF3E6D6),
    onExpert: Color(0xFFFFFFFF),
    lineStrong: Color(0xFF8E8B76),
    olive: Color(0xFF515C2D),
    onOlive: Color(0xFFFFFFFF),
    oliveSoft: Color(0xFFE9ECD8),
    onOliveSoft: Color(0xFF3F4822),
    focus: Color(0xFF515C2D),
    scrim: Color(0x8C000000),
    inputSurface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
  );

  static const darkTheme = AppColors(
    cream: Color(0xFF101912),
    cream2: Color(0xFF1D2C21),
    card: Color(0xFF142018),
    tan: Color(0xFF223127),
    primary: Color(0xFFC96843),
    primaryDark: Color(0xFFF3B28C),
    primaryLight: Color(0xFF3A2219),
    dark: Color(0xFF8D9D63),
    text: Color(0xFFF3EEDD),
    muted: Color(0xFFC1C7B4),
    border: Color(0xFF3A493C),
    success: Color(0xFFB9D68A),
    successBg: Color(0xFF243520),
    danger: Color(0xFFFFB4AB),
    dangerBg: Color(0xFF41201B),
    gold: Color(0xFFE8B84A),
    onGold: Color(0xFF2E2200),
    onDark: Color(0xFF101912),
    onDarkMuted: Color(0xFF2A3519),
    tagCare: Color(0xFF2B3820),
    onTagCare: Color(0xFFCFDDA8),
    tagTreat: Color(0xFF3A2A12),
    shadow: Color(0x59000000),
    avatarPalette: [Color(0xFF8D9D63), Color(0xFFC96843), Color(0xFFC9A55A), Color(0xFF6FA084), Color(0xFF9F8FC4)],
    accentSoft: Color(0xFF3A2F14),
    warning: Color(0xFFFFD18A),
    warningBg: Color(0xFF3A2A12),
    info: Color(0xFFA9C8EC),
    infoBg: Color(0xFF1A2836),
    subtle: Color(0xFF9DA391),
    expert: Color(0xFFE0B07A),
    expertBg: Color(0xFF33241A),
    onExpert: Color(0xFF241505),
    lineStrong: Color(0xFF6F7F6D),
    olive: Color(0xFF8D9D63),
    onOlive: Color(0xFF101912),
    oliveSoft: Color(0xFF2B3820),
    onOliveSoft: Color(0xFFCFDDA8),
    focus: Color(0xFFF3B28C),
    scrim: Color(0xA6000000),
    inputSurface: Color(0xFF223127),
    onPrimary: Color(0xFF101912),
  );

  // Agronom rejimi (Yashil dala 2.0) — bu bosqichda o'zgarmaydi; /expert yo'llarida shu mavzu qo'llanadi.
  static const legacyLight = AppColors(
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
    olive: Color(0xFF1D6B43),
    onOlive: Color(0xFFFFFFFF),
    oliveSoft: Color(0xFFDCEFE2),
    onOliveSoft: Color(0xFF0F3D27),
    focus: Color(0xFF1D6B43),
    scrim: Color(0x8C000000),
    inputSurface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
  );

  static const legacyDark = AppColors(
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
    olive: Color(0xFF5CC08B),
    onOlive: Color(0xFF0C1611),
    oliveSoft: Color(0xFF173A28),
    onOliveSoft: Color(0xFFA7E3C4),
    focus: Color(0xFF5CC08B),
    scrim: Color(0xA6000000),
    inputSurface: Color(0xFF13211A),
    onPrimary: Color(0xFF13211A),
  );


  /// Sog'liq foizi bo'yicha semantik rang.
  Color health(int pct) => pct >= 70 ? success : (pct >= 45 ? warning : danger);
  Color healthBg(int pct) => pct >= 70 ? successBg : (pct >= 45 ? warningBg : dangerBg);

  Color avatarFor(String seed) => avatarPalette[seed.hashCode.abs() % avatarPalette.length];

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    // Mavzu almashganda ranglar silliq o'tadi (TZ 13.3: 150–200 ms), joylashuv sakramaydi
    if (other is! AppColors) return this;
    final o = other;
    return AppColors(
      cream: Color.lerp(cream, o.cream, t)!,
      cream2: Color.lerp(cream2, o.cream2, t)!,
      card: Color.lerp(card, o.card, t)!,
      tan: Color.lerp(tan, o.tan, t)!,
      primary: Color.lerp(primary, o.primary, t)!,
      primaryDark: Color.lerp(primaryDark, o.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, o.primaryLight, t)!,
      dark: Color.lerp(dark, o.dark, t)!,
      text: Color.lerp(text, o.text, t)!,
      muted: Color.lerp(muted, o.muted, t)!,
      border: Color.lerp(border, o.border, t)!,
      success: Color.lerp(success, o.success, t)!,
      successBg: Color.lerp(successBg, o.successBg, t)!,
      danger: Color.lerp(danger, o.danger, t)!,
      dangerBg: Color.lerp(dangerBg, o.dangerBg, t)!,
      gold: Color.lerp(gold, o.gold, t)!,
      onGold: Color.lerp(onGold, o.onGold, t)!,
      onDark: Color.lerp(onDark, o.onDark, t)!,
      onDarkMuted: Color.lerp(onDarkMuted, o.onDarkMuted, t)!,
      tagCare: Color.lerp(tagCare, o.tagCare, t)!,
      onTagCare: Color.lerp(onTagCare, o.onTagCare, t)!,
      tagTreat: Color.lerp(tagTreat, o.tagTreat, t)!,
      shadow: Color.lerp(shadow, o.shadow, t)!,
      avatarPalette: t < 0.5 ? avatarPalette : o.avatarPalette,
      accentSoft: Color.lerp(accentSoft, o.accentSoft, t)!,
      warning: Color.lerp(warning, o.warning, t)!,
      warningBg: Color.lerp(warningBg, o.warningBg, t)!,
      info: Color.lerp(info, o.info, t)!,
      infoBg: Color.lerp(infoBg, o.infoBg, t)!,
      subtle: Color.lerp(subtle, o.subtle, t)!,
      expert: Color.lerp(expert, o.expert, t)!,
      expertBg: Color.lerp(expertBg, o.expertBg, t)!,
      onExpert: Color.lerp(onExpert, o.onExpert, t)!,
      lineStrong: Color.lerp(lineStrong, o.lineStrong, t)!,
      olive: Color.lerp(olive, o.olive, t)!,
      onOlive: Color.lerp(onOlive, o.onOlive, t)!,
      oliveSoft: Color.lerp(oliveSoft, o.oliveSoft, t)!,
      onOliveSoft: Color.lerp(onOliveSoft, o.onOliveSoft, t)!,
      focus: Color.lerp(focus, o.focus, t)!,
      scrim: Color.lerp(scrim, o.scrim, t)!,
      inputSurface: Color.lerp(inputSurface, o.inputSurface, t)!,
      onPrimary: Color.lerp(onPrimary, o.onPrimary, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}
