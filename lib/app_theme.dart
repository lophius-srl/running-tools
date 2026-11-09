import 'package:flutter/material.dart';

/// Palette et thèmes de l'app (tons bleus).
abstract final class AppColors {
  static const navy = Color(0xFF0B2A6F);
  static const blue = Color(0xFF1E63E9);
  static const sky = Color(0xFF38B6FF);
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF3F6FC)
          : scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
