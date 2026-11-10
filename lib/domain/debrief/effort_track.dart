import 'dart:math';

import '../course_profile.dart';
import '../grade_pace.dart';
import 'clean_activity.dart';

/// Temps et distance « équivalent plat » le long d'une sortie : la base des
/// analyses corrigées de la pente (modèle de l'ADR 0009).
class EffortTrack {
  EffortTrack(this.activity) : profile = activity.profile {
    final p = profile;
    if (p != null) {
      _eqPrefix.add(0);
      for (var i = 0; i < p.elevations.length - 1; i++) {
        _eqPrefix.add(
          _eqPrefix.last + CourseProfile.stepM * gradePaceFactor(p.gradeAt(i)),
        );
      }
    }
    // Distance cumulée jamais décroissante.
    var maxD = 0.0;
    for (final pt in activity.points) {
      maxD = max(maxD, pt.distanceM);
      _distances.add(maxD);
      _times.add(pt.timeS);
    }
  }

  final CleanActivity activity;
  final CourseProfile? profile;
  final _eqPrefix = <double>[];
  final _distances = <double>[];
  final _times = <double>[];

  double get distanceM => _distances.last;
  double get timeS => _times.last;

  /// Distance équivalent plat parcourue à [distanceM].
  double equivalentAt(double distanceM) {
    if (_eqPrefix.isEmpty) return distanceM;
    final x = distanceM / CourseProfile.stepM;
    final i = x.floor().clamp(0, _eqPrefix.length - 1);
    if (i >= _eqPrefix.length - 1) {
      return _eqPrefix.last + (distanceM - i * CourseProfile.stepM);
    }
    return _eqPrefix[i] + (x - i) * (_eqPrefix[i + 1] - _eqPrefix[i]);
  }

  double get equivalentM => equivalentAt(distanceM);

  /// Temps de mouvement (s) au passage de [distanceM].
  double timeAt(double distanceM) {
    if (distanceM <= _distances.first) return _times.first;
    if (distanceM >= _distances.last) return _times.last;
    var lo = 0, hi = _distances.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_distances[mid] < distanceM) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = _distances[hi] - _distances[lo];
    final f = span == 0 ? 0 : (distanceM - _distances[lo]) / span;
    return _times[lo] + f * (_times[hi] - _times[lo]);
  }

  /// Distance (m) parcourue au temps de mouvement [timeS].
  double distanceAtTime(double timeS) {
    if (timeS <= _times.first) return _distances.first;
    if (timeS >= _times.last) return _distances.last;
    var lo = 0, hi = _times.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_times[mid] < timeS) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = _times[hi] - _times[lo];
    final f = span == 0 ? 0 : (timeS - _times[lo]) / span;
    return _distances[lo] + f * (_distances[hi] - _distances[lo]);
  }

  /// Vitesse équivalent plat (m/s) de chaque point, lissée sur ±15 s.
  List<double> gapSpeeds({double windowS = 15}) {
    final raw = activity.smoothedSpeeds(windowS: windowS);
    return [
      for (var i = 0; i < raw.length; i++)
        () {
          final d = _distances[i];
          final eq = equivalentAt(d + 5) - equivalentAt(max(0, d - 5));
          final span = min(d + 5, distanceM) - max(0, d - 5);
          return span <= 0 ? raw[i] : raw[i] * eq / span;
        }(),
    ];
  }

  /// Allure corrigée de la pente (s/km) entre deux distances.
  double gapPaceBetween(double fromM, double toM) {
    final eq = equivalentAt(toM) - equivalentAt(fromM);
    return eq <= 0 ? 0 : (timeAt(toM) - timeAt(fromM)) / eq * 1000;
  }

  /// FC max entre deux distances, `null` sans FC.
  int? peakHeartRate(double fromM, double toM) {
    int? peak;
    final points = activity.points;
    for (var i = 0; i < points.length; i++) {
      if (_distances[i] < fromM || _distances[i] > toM) continue;
      final hr = points[i].heartRate;
      if (hr != null && (peak == null || hr > peak)) peak = hr;
    }
    return peak;
  }
}
