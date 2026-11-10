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
    this.stopSpeedMps = 1.0,
    this.minPause = const Duration(seconds: 10),
    this.minHeartRate = 35,
    this.maxHeartRate = 230,
    this.minStreamShare = 0.5,
  });

  /// En dessous, on est arrêté (marche lente comprise).
  final double stopSpeedMps;

  /// Un arrêt plus court compte comme du mouvement (feu rouge, demi-tour).
  final Duration minPause;
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
    final tracker = GpsTracker();
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
    var moving = 0.0;
    // Arrêt en cours : début (index) et durée, pas encore décidé.
    int? stopStart;
    var stopS = 0.0;
    final minPauseS = settings.minPause.inMilliseconds / 1000;

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

    addPoint(0);
    for (var i = 1; i < samples.length; i++) {
      final dt =
          samples[i].time.difference(samples[i - 1].time).inMilliseconds / 1000;
      final dd = (distances[i] ?? 0) - (distances[i - 1] ?? 0);
      if (dt <= 0) continue;
      if (dt > minPauseS) {
        // Trou dans l'enregistrement (pause automatique de la montre).
        pauses.add((
          atM: points.last.distanceM,
          duration: Duration(milliseconds: (dt * 1000).round()),
        ));
        addPoint(i);
        continue;
      }
      if (dd / dt < settings.stopSpeedMps) {
        stopStart ??= i;
        stopS += dt;
        continue;
      }
      if (stopStart != null) {
        if (stopS >= minPauseS) {
          pauses.add((
            atM: points.last.distanceM,
            duration: Duration(milliseconds: (stopS * 1000).round()),
          ));
        } else {
          // Arrêt bref : compté comme du mouvement.
          moving += stopS;
        }
        stopStart = null;
        stopS = 0;
      }
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

  /// Profil d'altitude lissé (pas de 10 m), `null` sans altitudes.
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
