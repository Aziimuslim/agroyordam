import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Figma "Dimensions" kolleksiyasi: radius/sm·md·lg·xl.
class AppRadius {
  static const xl = 28.0;
  static const lg = 20.0;
  static const md = 14.0;
  static const sm = 10.0;
  static const pill = 999.0;
}

class AppTheme {
  static const font = 'PlusJakartaSans';

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
        // Figma text styles: Display 28/34, H1 24/30, H2 20/26, H3 17/24, Body 15·14·13, Label, Caption
        displaySmall: text.displaySmall?.copyWith(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800, letterSpacing: -0.56),
        headlineMedium: text.headlineMedium?.copyWith(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800, letterSpacing: -0.36),
        headlineSmall: text.headlineSmall?.copyWith(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w800, letterSpacing: -0.2),
        titleLarge: text.titleLarge?.copyWith(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w500),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500),
        bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: c.muted),
        labelLarge: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        labelSmall: text.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        hintStyle: TextStyle(color: c.subtle, fontSize: 14.5, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.border, width: 1.2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.border, width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.danger, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: c.danger, width: 1.8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.dark,
        contentTextStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700, color: c.onDark, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: c.border, width: 2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        showDragHandle: true,
        dragHandleColor: c.border,
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
