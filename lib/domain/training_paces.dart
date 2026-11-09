/// Zone d'entraînement exprimée en pourcentage de VMA.
class TrainingZone {
  const TrainingZone(this.name, this.minPercent, this.maxPercent);

  final String name;
  final double minPercent;
  final double maxPercent;
}

/// Zones par défaut (% VMA).
const defaultTrainingZones = [
  TrainingZone('Endurance fondamentale', 60, 70),
  TrainingZone('Endurance active', 70, 80),
  TrainingZone('Allure marathon', 80, 85),
  TrainingZone('Seuil', 85, 90),
  TrainingZone('VMA longue', 90, 95),
  TrainingZone('VMA courte', 95, 105),
];

/// Allures d'une zone : de la plus lente (min % VMA) à la plus rapide.
class ZonePace {
  const ZonePace({
    required this.zone,
    required this.minSpeedKmh,
    required this.maxSpeedKmh,
  });

  final TrainingZone zone;
  final double minSpeedKmh;
  final double maxSpeedKmh;

  Duration get slowestPace => paceForSpeed(minSpeedKmh);
  Duration get fastestPace => paceForSpeed(maxSpeedKmh);
}

/// Temps au kilomètre pour une vitesse, arrondi à la seconde.
Duration paceForSpeed(double speedKmh) {
  if (speedKmh <= 0) {
    throw ArgumentError.value(speedKmh, 'speedKmh', 'doit être positive');
  }
  return Duration(seconds: (3600 / speedKmh).round());
}

/// « 4:05 » pour 4 min 5 s par kilomètre.
String formatPace(Duration pace) {
  final seconds = (pace.inSeconds % 60).toString().padLeft(2, '0');
  return '${pace.inMinutes}:$seconds';
}

List<ZonePace> trainingPaces(
  double vmaKmh, {
  List<TrainingZone> zones = defaultTrainingZones,
}) => [
  for (final zone in zones)
    ZonePace(
      zone: zone,
      minSpeedKmh: vmaKmh * zone.minPercent / 100,
      maxSpeedKmh: vmaKmh * zone.maxPercent / 100,
    ),
];
