import 'measurement_method.dart';

/// Terrains dont une ligne donne directement un espacement de repères.
enum StandardField {
  football('Football', 'Profondeur de la surface de réparation', 16.5),
  handball('Handball', 'Largeur du terrain', 20),
  rugby('Rugby', 'De la ligne de but à la ligne des 22 m', 22),
  tennis('Tennis', 'Longueur du court (ligne de fond à ligne de fond)', 23.77);

  const StandardField(this.label, this.howTo, this.spacingM);

  final String label;

  /// Quelle distance mesure-t-on sur ce terrain.
  final String howTo;
  final double spacingM;
}

/// Espacement retenu dans l'assistant de mise en place, et comment.
class SpacingChoice {
  const SpacingChoice(this.spacingM, this.method, {this.source});

  final double spacingM;
  final MeasurementMethod method;

  /// Précision affichée (ex. « Tennis »).
  final String? source;
}
