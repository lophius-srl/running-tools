import 'stage_protocol.dart';

/// Rapport usuel entre VO2max (ml/kg/min) et VMA (km/h).
const vo2maxPerVmaKmh = 3.5;

/// Résultat d'un test : VMA (km/h) et VO2max (ml/kg/min).
class TestResult {
  const TestResult({required this.vmaKmh, required this.vo2max});

  final double vmaKmh;
  final double vo2max;
}

/// Cooper (12 min) : VO2max = (d − 504,9) / 44,73 ; VMA = d / 200.
TestResult cooperResult(double distanceM) {
  _checkDistance(distanceM);
  return TestResult(
    vmaKmh: distanceM / 200,
    vo2max: (distanceM - 504.9) / 44.73,
  );
}

/// Demi-Cooper (6 min) : VMA = d / 100 ; VO2max ≈ 3,5 × VMA.
TestResult halfCooperResult(double distanceM) {
  _checkDistance(distanceM);
  final vma = distanceM / 100;
  return TestResult(vmaKmh: vma, vo2max: vo2maxPerVmaKmh * vma);
}

/// Vitesse retenue pour un test par paliers : celle du dernier palier complet,
/// plus, avec [prorata], la part courue du palier suivant.
double reachedSpeedKmh(
  StageProtocol protocol, {
  required int completedStages,
  double fractionOfNextStage = 0,
  bool prorata = false,
}) {
  if (completedStages < 1) {
    throw ArgumentError.value(
      completedStages,
      'completedStages',
      'au moins un palier complet est nécessaire',
    );
  }
  if (fractionOfNextStage < 0 || fractionOfNextStage >= 1) {
    throw ArgumentError.value(
      fractionOfNextStage,
      'fractionOfNextStage',
      'doit être dans [0, 1[',
    );
  }
  final speed = protocol.speedKmh(completedStages);
  return prorata ? speed + fractionOfNextStage * protocol.incrementKmh : speed;
}

/// VAMEVAL : VMA = vitesse retenue ; VO2max ≈ 3,5 × VMA.
TestResult vamevalResult(double reachedSpeedKmh) => TestResult(
  vmaKmh: reachedSpeedKmh,
  vo2max: vo2maxPerVmaKmh * reachedSpeedKmh,
);

/// Navette Luc Léger (adulte) : VO2max = 5,857 × V − 19,458.
///
/// Les demi-tours rendent la vitesse de navette inférieure à la VMA : la VMA
/// est estimée par VO2max / 3,5.
TestResult lucLegerResult(double reachedSpeedKmh) {
  final vo2max = 5.857 * reachedSpeedKmh - 19.458;
  return TestResult(vmaKmh: vo2max / vo2maxPerVmaKmh, vo2max: vo2max);
}

void _checkDistance(double distanceM) {
  if (distanceM <= 0) {
    throw ArgumentError.value(distanceM, 'distanceM', 'doit être positive');
  }
}
