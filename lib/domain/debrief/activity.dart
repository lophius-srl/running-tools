import '../gps_tracker.dart';

/// Un point brut d'une sortie enregistrée (GPX ou FIT). Chaque mesure peut
/// manquer selon la montre et les capteurs.
class ActivitySample {
  const ActivitySample({
    required this.time,
    this.position,
    this.elevationM,
    this.heartRate,
    this.cadence,
    this.distanceM,
  });

  final DateTime time;
  final GeoPoint? position;
  final double? elevationM;
  final int? heartRate;

  /// Pas par minute tel qu'enregistré (parfois par pied : normalisé au
  /// nettoyage).
  final int? cadence;

  /// Distance cumulée calculée par la montre (FIT), si fournie.
  final double? distanceM;
}

/// Sortie brute telle que lue dans le fichier.
class RawActivity {
  const RawActivity({required this.name, required this.samples});

  final String name;
  final List<ActivitySample> samples;
}
