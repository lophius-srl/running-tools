import 'dart:math';

import '../course_profile.dart';
import '../gps_tracker.dart';
import 'activity.dart';

/// Un point de la sortie nettoyée, en temps de mouvement (pauses retirées).
class ActivityPoint {
  const ActivityPoint({
    required this.timeS,
    required this.distanceM,
    this.elevationM,
    this.heartRate,
    this.cadence,
  });

  /// Temps de mouvement depuis le départ (s).
  final double timeS;
  final double distanceM;
  final double? elevationM;
  final int? heartRate;

  /// Pas par minute (deux pieds).
  final int? cadence;
}

/// Une pause détectée.
typedef ActivityPause = ({double atM, Duration duration});

/// Réglages du nettoyage.
class CleaningSettings {
  const CleaningSettings({
    this.stationarySpeedMps = 0.5,
    this.stationaryWindowS = 5,
    this.minPause = const Duration(seconds: 20),
    this.maxRecordingGap = const Duration(seconds: 10),
    this.minHeartRate = 35,
    this.maxHeartRate = 230,
    this.minStreamShare = 0.5,
  });

  /// En dessous (1,8 km/h, moyenne sur ±[stationaryWindowS]), on est
  /// immobile. Marcher, même lentement en côte, n'est pas une pause.
  final double stationarySpeedMps;
  final double stationaryWindowS;

  /// Un arrêt plus court compte comme du mouvement (feu rouge, lacet).
  final Duration minPause;

  /// Trou plus long dans l'enregistrement : pause de la montre, sauf si on
  /// a avancé pendant ce temps (GPS perdu dans un tunnel).
  final Duration maxRecordingGap;
  final int minHeartRate;
  final int maxHeartRate;

  /// Part des points où une mesure doit exister pour l'analyser.
  final double minStreamShare;
}

/// Sortie prête à analyser : pauses retirées, valeurs aberrantes filtrées,
/// cadence en pas par minute, distance passée par le filtre GPS.
class CleanActivity {
  CleanActivity._({
    required this.name,
    required this.start,
    required this.points,
    required this.pauses,
    required this.elapsed,
    required this.rejectedFixes,
    required this.hasHeartRate,
    required this.hasCadence,
    required this.hasElevation,
  });

  factory CleanActivity.from(
    RawActivity raw, {
    CleaningSettings settings = const CleaningSettings(),
  }) {
    final samples = [...raw.samples]..sort((a, b) => a.time.compareTo(b.time));
    // Distance : celle de la montre (FIT) si présente, sinon le filtre GPS.
    final watchDistance =
        samples.where((s) => s.distanceM != null).length >=
        samples.length * settings.minStreamShare;
    // Seuil d'arrêt du filtre abaissé : la marche lente compte.
    final tracker = GpsTracker(
      settings: const GpsFilterSettings(minSpeedMps: 0.3),
    );
    final distances = <double?>[];
    var rejected = 0;
    double? lastWatch;
    for (final s in samples) {
      if (watchDistance) {
        lastWatch = s.distanceM ?? lastWatch;
        distances.add(lastWatch);
      } else if (s.position case final p?) {
        final r = tracker.add(GpsFix(time: s.time, position: p, accuracyM: 5));
        if (r != null) rejected++;
        distances.add(tracker.distanceM);
      } else {
        distances.add(null);
      }
    }

    // Cadence enregistrée par pied (~85) : on double pour des pas/min.
    final cadences = [
      for (final s in samples)
        if (s.cadence case final c? when c > 0) c,
    ]..sort();
    final perFoot = cadences.isNotEmpty && cadences[cadences.length ~/ 2] < 120;

    final points = <ActivityPoint>[];
    final pauses = <ActivityPause>[];
    final t0 = samples.first.time;
    final seconds = [
      for (final s in samples) s.time.difference(t0).inMilliseconds / 1000,
    ];
    double distanceOf(int i) => distances[i] ?? 0;

    // Immobile : vitesse moyenne sur une fenêtre de ±15 s sous 1,8 km/h.
    final stationary = List.filled(samples.length, false);
    var lo = 0, hi = 0;
    for (var i = 0; i < samples.length; i++) {
      while (seconds[i] - seconds[lo] > settings.stationaryWindowS) {
        lo++;
      }
      while (hi < samples.length - 1 &&
          seconds[hi + 1] - seconds[i] <= settings.stationaryWindowS) {
        hi++;
      }
      final dt = seconds[hi] - seconds[lo];
      stationary[i] =
          dt > 0 &&
          (distanceOf(hi) - distanceOf(lo)) / dt < settings.stationarySpeedMps;
    }

    var moving = 0.0;
    var stopS = 0.0;
    final minPauseS = settings.minPause.inMilliseconds / 1000;
    final maxGapS = settings.maxRecordingGap.inMilliseconds / 1000;

    void addPoint(int i) {
      final s = samples[i];
      final hr = s.heartRate;
      final cad = s.cadence;
      points.add(
        ActivityPoint(
          timeS: moving,
          distanceM: distances[i] ?? (points.lastOrNull?.distanceM ?? 0),
          elevationM: s.elevationM,
          heartRate:
              hr != null &&
                  hr >= settings.minHeartRate &&
                  hr <= settings.maxHeartRate
              ? hr
              : null,
          cadence: cad == null || cad <= 0 ? null : (perFoot ? cad * 2 : cad),
        ),
      );
    }

    void flushStop() {
      if (stopS == 0) return;
      if (stopS >= minPauseS) {
        pauses.add((
          atM: points.last.distanceM,
          duration: Duration(milliseconds: (stopS * 1000).round()),
        ));
      } else {
        moving += stopS;
      }
      stopS = 0;
    }

    addPoint(0);
    for (var i = 1; i < samples.length; i++) {
      final dt = seconds[i] - seconds[i - 1];
      if (dt <= 0) continue;
      final dd = distanceOf(i) - distanceOf(i - 1);
      if (dt > maxGapS && dd < dt * settings.stationarySpeedMps) {
        // Montre en pause : trou sans déplacement.
        flushStop();
        pauses.add((
          atM: points.last.distanceM,
          duration: Duration(milliseconds: (dt * 1000).round()),
        ));
        addPoint(i);
        continue;
      }
      if (stationary[i]) {
        stopS += dt;
        continue;
      }
      flushStop();
      moving += dt;
      addPoint(i);
    }

    bool enough(bool Function(ActivityPoint) has) =>
        points.where(has).length >= points.length * settings.minStreamShare;

    return CleanActivity._(
      name: raw.name,
      start: samples.first.time,
      points: points,
      pauses: pauses,
      elapsed: samples.last.time.difference(samples.first.time),
      rejectedFixes: rejected,
      hasHeartRate: enough((p) => p.heartRate != null),
      hasCadence: enough((p) => p.cadence != null),
      hasElevation: enough((p) => p.elevationM != null),
    );
  }

  final String name;
  final DateTime start;
  final List<ActivityPoint> points;
  final List<ActivityPause> pauses;
  final Duration elapsed;
  final int rejectedFixes;
  final bool hasHeartRate;
  final bool hasCadence;
  final bool hasElevation;

  double get distanceM => points.last.distanceM;
  double get movingS => points.last.timeS;

  Duration get pausedTime =>
      pauses.fold(Duration.zero, (sum, p) => sum + p.duration);

  /// Vitesse moyenne en mouvement (km/h).
  double get averageKmh => movingS == 0 ? 0 : distanceM / movingS * 3.6;

  /// Dénivelé positif et négatif (m) sur les altitudes enregistrées, sans
  /// lissage en distance : seul un écart de [thresholdM] écarte le bruit.
  /// `null` sans altitudes.
  ({double gain, double loss})? elevationChange({double thresholdM = 2}) =>
      hasElevation
      ? elevationGainLoss([
          for (final p in points) ?p.elevationM,
        ], thresholdM: thresholdM)
      : null;

  /// Profil d'altitude lissé (pas de 10 m) pour corriger l'allure de la
  /// pente ; pas pour le dénivelé, que le lissage sous-estime.
  /// `null` sans altitudes.
  CourseProfile? get profile {
    if (!hasElevation || distanceM < 2 * CourseProfile.stepM) return null;
    final withEle = points.where((p) => p.elevationM != null).toList();
    final elevations = <double>[];
    var j = 0;
    for (var d = 0.0; d <= distanceM; d += CourseProfile.stepM) {
      while (j < withEle.length - 2 && withEle[j + 1].distanceM < d) {
        j++;
      }
      final a = withEle[j], b = withEle[min(j + 1, withEle.length - 1)];
      final span = b.distanceM - a.distanceM;
      final f = span <= 0 ? 0.0 : ((d - a.distanceM) / span).clamp(0.0, 1.0);
      elevations.add(a.elevationM! + f * (b.elevationM! - a.elevationM!));
    }
    return CourseProfile(name: name, elevations: smooth(elevations, 10));
  }

  /// Vitesse (m/s) lissée sur ±[windowS] secondes autour de chaque point.
  List<double> smoothedSpeeds({double windowS = 15}) {
    final speeds = <double>[];
    var lo = 0, hi = 0;
    for (var i = 0; i < points.length; i++) {
      final t = points[i].timeS;
      while (points[lo].timeS < t - windowS) {
        lo++;
      }
      while (hi < points.length - 1 && points[hi + 1].timeS <= t + windowS) {
        hi++;
      }
      final dt = points[hi].timeS - points[lo].timeS;
      speeds.add(
        dt <= 0 ? 0 : (points[hi].distanceM - points[lo].distanceM) / dt,
      );
    }
    return speeds;
  }
}
