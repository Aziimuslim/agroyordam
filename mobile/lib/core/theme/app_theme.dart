import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppRadius {
  static const lg = 22.0;
  static const md = 16.0;
  static const sm = 12.0;
  static const pill = 999.0;
}

class AppTheme {
  static const font = 'Nunito';

  static ThemeData build(AppColors c, Brightness b) {
    final base = ThemeData(brightness: b, useMaterial3: true, fontFamily: font);
    final text = base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: font);
    return base.copyWith(
      scaffoldBackgroundColor: c.cream,
      colorScheme: ColorScheme.fromSeed(seedColor: c.primary, brightness: b).copyWith(
        primary: c.primary,
        onPrimary: c.card,
        surface: c.card,
        onSurface: c.text,
        error: c.danger,
      ),
      extensions: [c],
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.2),
        headlineSmall: text.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
        titleLarge: text.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
        titleSmall: text.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 14.5, height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 13.5, height: 1.45),
        bodySmall: text.bodySmall?.copyWith(fontSize: 12.5, color: c.muted),
        labelLarge: text.labelLarge?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.cream2,
        hintStyle: TextStyle(color: c.muted, fontSize: 14.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: c.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: c.danger)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.dark,
        contentTextStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700, color: c.card, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.card),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static final light = build(AppColors.light, Brightness.light);
  static final dark = build(AppColors.darkTheme, Brightness.dark);
}
