/// Mesure au pas talon-pointe : on pose un pied juste devant l'autre.
class ShoeMeasure {
  ShoeMeasure(this.footLengthM) {
    if (!(footLengthM > 0)) {
      throw ArgumentError.value(footLengthM, 'footLengthM', 'doit être > 0');
    }
  }

  /// Longueur obtenue en comptant [steps] pas sur [distanceM] connus.
  factory ShoeMeasure.calibrated({
    required double distanceM,
    required double steps,
  }) {
    if (!(steps > 0)) {
      throw ArgumentError.value(steps, 'steps', 'doit être > 0');
    }
    return ShoeMeasure(distanceM / steps);
  }

  /// Longueur d'un pas talon-pointe (= longueur de la chaussure).
  final double footLengthM;

  /// Nombre de pas pour couvrir [distanceM] : pas entiers + reste en mètres.
  ({int steps, double remainderM}) stepsFor(double distanceM) {
    // Petite tolérance : 20 m / 0,25 m doit donner 80 pas, pas 79 + 25 cm.
    final steps = (distanceM / footLengthM + 1e-9).floor();
    final remainder = distanceM - steps * footLengthM;
    return (steps: steps, remainderM: remainder < 1e-9 ? 0 : remainder);
  }

  /// Distance couverte par [steps] pas.
  double distanceFor(double steps) => steps * footLengthM;
}
