import 'dart:math';

import '../course_profile.dart';
import 'effort_track.dart';

/// Un point du graphique du débrief.
typedef SeriesPoint = ({
  double km,
  double? elevationM,
  double paceS,
  double? heartRate,
});

/// Série tous les [stepM] mètres : altitude lissée, allure sur une fenêtre
/// de ±[windowM] (gomme le bruit GPS), FC moyenne sur la même fenêtre.
List<SeriesPoint> debriefSeries(
  EffortTrack track, {
  double stepM = 50,
  double windowM = 100,
}) {
  final d = track.distanceM;
  final profile = track.profile;
  final points = track.activity.points;
  final series = <SeriesPoint>[];
  var lo = 0, hi = 0;
  for (var x = 0.0; x <= d; x += stepM) {
    final from = max(0.0, x - windowM), to = min(d, x + windowM);
    final dt = track.timeAt(to) - track.timeAt(from);
    final pace = to - from <= 0 ? 0.0 : dt / (to - from) * 1000;
    while (lo < points.length - 1 && points[lo].distanceM < from) {
      lo++;
    }
    while (hi < points.length - 1 && points[hi + 1].distanceM <= to) {
      hi++;
    }
    var sum = 0, n = 0;
    for (var i = lo; i <= hi; i++) {
      if (points[i].heartRate case final hr?) {
        sum += hr;
        n++;
      }
    }
    double? elevation;
    if (profile != null) {
      final i = (x / CourseProfile.stepM).round().clamp(
        0,
        profile.elevations.length - 1,
      );
      elevation = profile.elevations[i];
    }
    series.add((
      km: x / 1000,
      elevationM: elevation,
      paceS: pace,
      heartRate: n == 0 ? null : sum / n,
    ));
  }
  return series;
}
