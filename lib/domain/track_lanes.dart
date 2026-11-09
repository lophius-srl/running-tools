import 'dart:math';

/// Géométrie d'une piste d'athlétisme et distance réelle par couloir.
///
/// Piste standard World Athletics de 400 m : deux lignes droites de 84,39 m
/// et deux virages de rayon 36,50 m au bord intérieur (la lice), couloirs de
/// 1,22 m (ligne de droite comprise). La ligne de course est mesurée à 30 cm
/// de la lice en couloir 1, et à 20 cm de la ligne intérieure ensuite.
/// Voir docs/adr/0006-correcteur-de-couloir.md.
class TrackGeometry {
  const TrackGeometry({
    this.straightM = 84.39,
    this.kerbRadiusM = 36.50,
    this.laneWidthM = 1.22,
    this.lane1OffsetM = 0.30,
    this.otherLanesOffsetM = 0.20,
    this.lanes = 8,
  });

  static const standard = TrackGeometry();

  final double straightM;
  final double kerbRadiusM;
  final double laneWidthM;
  final double lane1OffsetM;
  final double otherLanesOffsetM;
  final int lanes;

  /// Rayon de la ligne de course dans les virages pour le couloir [lane].
  double measureRadiusM(int lane) {
    _checkLane(lane);
    return lane == 1
        ? kerbRadiusM + lane1OffsetM
        : kerbRadiusM + laneWidthM * (lane - 1) + otherLanesOffsetM;
  }

  /// Longueur d'un tour complet dans le couloir [lane].
  double lapLengthM(int lane) => 2 * straightM + 2 * pi * measureRadiusM(lane);

  /// Rapport entre la distance courue en couloir [lane] et en couloir 1.
  ///
  /// Exact pour des tours complets ; pour une fraction de tour c'est une
  /// moyenne (seuls les virages s'allongent).
  double laneFactor(int lane) => lapLengthM(lane) / lapLengthM(1);

  /// Distance réellement courue pour [nominalM] mètres comptés en couloir 1.
  double realDistanceM(double nominalM, int lane) =>
      nominalM * laneFactor(lane);

  /// Temps pour couvrir [nominalM] (comptés en couloir 1) dans le couloir
  /// [lane] à [speedKmh].
  Duration splitFor(double nominalM, int lane, double speedKmh) {
    if (!(speedKmh > 0)) {
      throw ArgumentError.value(speedKmh, 'speedKmh', 'doit être > 0');
    }
    final seconds = realDistanceM(nominalM, lane) / (speedKmh / 3.6);
    return Duration(microseconds: (seconds * 1e6).round());
  }

  /// Vitesse réelle quand [nominalM] (comptés en couloir 1) ont été courus
  /// en [time] dans le couloir [lane].
  double realSpeedKmh(double nominalM, int lane, Duration time) {
    if (time <= Duration.zero) {
      throw ArgumentError.value(time, 'time', 'doit être > 0');
    }
    return realDistanceM(nominalM, lane) / (time.inMicroseconds / 1e6) * 3.6;
  }

  void _checkLane(int lane) {
    if (lane < 1 || lane > lanes) {
      throw RangeError.range(lane, 1, lanes, 'lane');
    }
  }
}
