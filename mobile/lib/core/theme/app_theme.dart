import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';

/// Yashil dala 2.0: radius-sm·md·lg·xl·pill.
class AppRadius {
  static const xl = 28.0;
  static const lg = 20.0;
  static const md = 14.0;
  static const sm = 10.0;
  static const pill = 999.0;
}

class AppTheme {
  /// Onest — lotin va kirill (rus tili qo'shilganda shrift o'zgarmaydi).
  static const font = 'Onest';

  static ThemeData build(AppColors c, Brightness b) {
    final base = ThemeData(brightness: b, useMaterial3: true, fontFamily: font);
    final text = base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: font);
    return base.copyWith(
      scaffoldBackgroundColor: c.cream,
      // Web/desktop'da ham mobil zichlik (Figma o'lchamlari: tugma 52px, maydon 50px)
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: ColorScheme.fromSeed(seedColor: c.primary, brightness: b).copyWith(
        primary: c.primary,
        onPrimary: c.card,
        surface: c.card,
        onSurface: c.text,
        error: c.danger,
      ),
      extensions: [c],
      textTheme: text.copyWith(
        // Yashil dala 2.0 tipografiyasi: display 32/38, title-lg 24/30, title 20/26, title-sm 17/22,
        // body-lg 17/26 (tavsiya matni), body 15/22, label 16/20, caption 13/18. O'qiladigan matn 13px dan kichik emas.
        displaySmall: text.displaySmall?.copyWith(fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w800, letterSpacing: -0.64),
        headlineMedium: text.headlineMedium?.copyWith(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800, letterSpacing: -0.24),
        headlineSmall: text.headlineSmall?.copyWith(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700),
        titleLarge: text.titleLarge?.copyWith(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontSize: 15.5, height: 21 / 15.5, fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 26 / 17, fontWeight: FontWeight.w400),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400),
        bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: c.muted),
        labelLarge: text.labelLarge?.copyWith(fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w700),
        labelSmall: text.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.96, color: c.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        hintStyle: TextStyle(color: c.subtle, fontSize: 16, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.lineStrong, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.lineStrong, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.danger, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.danger, width: 1.8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.dark,
        contentTextStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600, color: c.onDark, fontSize: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: c.lineStrong, width: 2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        showDragHandle: true,
        dragHandleColor: c.border,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.card),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      // Oldinga/orqaga — gorizontal siljish (Motion). iOS'da tizimning orqaga surish imo-ishorasi saqlanadi.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: SharedAxisPageTransitionsBuilder(),
        TargetPlatform.macOS: SharedAxisPageTransitionsBuilder(),
        TargetPlatform.windows: SharedAxisPageTransitionsBuilder(),
      }),
    );
  }

  static final light = build(AppColors.light, Brightness.light);
  static final dark = build(AppColors.darkTheme, Brightness.dark);
}
