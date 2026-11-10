import 'dart:math';

import 'clean_activity.dart';

/// Type de séance : change ce qu'on attend de la sortie.
enum SessionType {
  endurance('Endurance'),
  long('Sortie longue'),
  interval('Fractionné'),
  race('Course');

  const SessionType(this.label);
  final String label;
}

/// Proposition automatique, que l'utilisateur peut corriger :
/// - fractionné : au moins 4 blocs d'au moins 30 s nettement plus rapides
///   (> 115 % de la vitesse médiane), séparés par des récupérations ;
/// - course : allure régulière (variation < 8 %) à plus de 85 % de la VMA,
///   sur au moins 5 km (VMA connue) ;
/// - sortie longue : plus de 1 h 30 ou plus de 18 km ;
/// - endurance sinon.
SessionType detectSessionType(CleanActivity activity, {double? vmaKmh}) {
  final speeds = activity.smoothedSpeeds(windowS: 15);
  if (speeds.length < 10) return SessionType.endurance;
  final sorted = [...speeds]..sort();
  final median = sorted[sorted.length ~/ 2];
  if (median <= 0) return SessionType.endurance;

  // Blocs rapides d'au moins 30 s.
  var blocks = 0;
  double? blockStart;
  final points = activity.points;
  for (var i = 0; i < speeds.length; i++) {
    final fast = speeds[i] > median * 1.15;
    if (fast) {
      blockStart ??= points[i].timeS;
    } else if (blockStart != null) {
      if (points[i].timeS - blockStart >= 30) blocks++;
      blockStart = null;
    }
  }
  if (blocks >= 4) return SessionType.interval;

  final km = activity.distanceM / 1000;
  if (vmaKmh != null &&
      km >= 5 &&
      activity.averageKmh >= 0.85 * vmaKmh &&
      coefficientOfVariation(speeds) < 0.08) {
    return SessionType.race;
  }
  if (activity.movingS >= 90 * 60 || km >= 18) return SessionType.long;
  return SessionType.endurance;
}

/// Écart type / moyenne.
double coefficientOfVariation(List<double> values) {
  if (values.isEmpty) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  if (mean == 0) return 0;
  final variance =
      values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
      values.length;
  return sqrt(variance) / mean;
}
