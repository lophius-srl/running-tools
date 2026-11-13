import 'package:flutter/material.dart';

/// Palette et thèmes de l'app (tons bleus).
abstract final class AppColors {
  static const navy = Color(0xFF0B2A6F);
  static const blue = Color(0xFF1E63E9);
  static const sky = Color(0xFF38B6FF);
}

/// Dégradés : un seul pour la marque, partout dans l'app.
abstract final class AppGradients {
  /// Cartes et pictogrammes.
  static const brand = [AppColors.navy, AppColors.blue];

  /// En-têtes de page.
  static const header = [AppColors.navy, AppColors.blue, AppColors.sky];
}

/// Arrondis communs.
abstract final class AppRadius {
  /// Bas des en-têtes de page.
  static const header = 28.0;

  /// Cartes.
  static const card = 20.0;

  /// Tuiles, boutons, pastilles de chiffres.
  static const tile = 14.0;

  /// Badges, ruban de zones.
  static const chip = 10.0;
}

/// Espacements communs.
abstract final class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: brightness,
      // Garde un bleu vif plutôt que la version adoucie par défaut.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF3F6FC)
          : scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }
}
