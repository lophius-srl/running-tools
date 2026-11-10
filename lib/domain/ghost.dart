import 'dart:math';

import 'gps_tracker.dart';
import 'training_paces.dart';

/// Un instant de la sortie de référence.
class GhostPoint {
  const GhostPoint({
    required this.timeS,
    required this.distanceM,
    this.position,
  });

  final double timeS;
  final double distanceM;
  final GeoPoint? position;
}

/// Façon de comparer ma course à celle du fantôme.
enum GhostAlignment {
  /// À distance égale, sur n'importe quel parcours.
  distance('Par distance'),

  /// Le long du tracé de référence (même parcours).
  route('Même parcours');

  const GhostAlignment(this.label);
  final String label;
}

/// La sortie de référence : temps et distance (et position si connue).
class Ghost {
  Ghost({required this.name, required List<GhostPoint> points})
    : points = List.unmodifiable(points),
      _pace = null,
      distanceKm = null {
    if (points.length < 2) {
      throw ArgumentError('Un fantôme demande au moins deux points.');
    }
    for (var i = 1; i < points.length; i++) {
      if (points[i].timeS <= points[i - 1].timeS ||
          points[i].distanceM < points[i - 1].distanceM) {
        throw ArgumentError('Points du fantôme non ordonnés.');
      }
    }
  }

  /// Fantôme virtuel à allure constante, sans fin (ou jusqu'à [distanceKm]).
  Ghost.constantPace(Duration pacePerKm, {this.distanceKm})
    : name = 'Allure ${formatPace(pacePerKm)}/km',
      points = const [],
      _pace = pacePerKm.inMilliseconds / 1000 / 1000;

  final String name;
  final List<GhostPoint> points;

  /// Secondes par mètre du fantôme virtuel.
  final double? _pace;

  /// Distance fixe du fantôme virtuel, s'il en a une.
  final double? distanceKm;

  bool get hasRoute =>
      points.isNotEmpty && points.every((p) => p.position != null);

  /// Distance totale, `null` pour un fantôme virtuel sans fin.
  double? get totalDistanceM => _pace != null
      ? (distanceKm == null ? null : distanceKm! * 1000)
      : points.last.distanceM;

  /// Temps total, `null` si sans fin.
  double? get totalTimeS {
    if (_pace case final pace?) {
      final d = totalDistanceM;
      return d == null ? null : d * pace;
    }
    return points.last.timeS - points.first.timeS;
  }

  /// Temps (s) du fantôme pour atteindre [distanceM], `null` au-delà de sa fin.
  double? timeAtDistance(double distanceM) {
    if (_pace case final pace?) {
      final total = totalDistanceM;
      return total != null && distanceM > total ? null : distanceM * pace;
    }
    if (distanceM > points.last.distanceM) return null;
    final i = _lowerBound((p) => p.distanceM >= distanceM);
    if (i == 0) return 0;
    final a = points[i - 1], b = points[i];
    final span = b.distanceM - a.distanceM;
    final f = span == 0 ? 0 : (distanceM - a.distanceM) / span;
    return a.timeS + f * (b.timeS - a.timeS) - points.first.timeS;
  }

  /// Distance (m) du fantôme après [timeS], plafonnée à sa fin.
  double distanceAtTime(double timeS) {
    if (_pace case final pace?) {
      final d = timeS / pace;
      final total = totalDistanceM;
      return total == null ? d : min(d, total);
    }
    final t = timeS + points.first.timeS;
    if (t >= points.last.timeS) return points.last.distanceM;
    final i = _lowerBound((p) => p.timeS >= t);
    if (i == 0) return points.first.distanceM;
    final a = points[i - 1], b = points[i];
    final f = (t - a.timeS) / (b.timeS - a.timeS);
    return a.distanceM + f * (b.distanceM - a.distanceM);
  }

  int _lowerBound(bool Function(GhostPoint) test) {
    var lo = 0, hi = points.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (test(points[mid])) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }
}

/// Écart avec le fantôme à un instant.
class GhostGap {
  const GhostGap({required this.seconds, required this.meters});

  /// > 0 : je suis devant (j'ai mis moins de temps pour la même distance).
  final double seconds;

  /// > 0 : je suis devant de tant de mètres.
  final double meters;

  bool get ahead => meters > 0;
}

/// Écart à l'instant [timeS] où j'ai couvert [distanceM] (le long du tracé
/// de référence en mode « même parcours »).
GhostGap gapAt(
  Ghost ghost, {
  required double timeS,
  required double distanceM,
}) {
  final ghostDistance = ghost.distanceAtTime(timeS);
  final ghostTime = ghost.timeAtDistance(distanceM);
  final meters = distanceM - ghostDistance;
  // Au-delà de la fin du fantôme : temps final comparé au mien.
  final seconds = ghostTime == null
      ? ghost.totalTimeS! - timeS
      : ghostTime - timeS;
  return GhostGap(seconds: seconds, meters: meters);
}

/// Repère ma position le long du tracé de référence (mode « même parcours »).
/// Ne cherche que vers l'avant, dans une fenêtre, pour ne pas sauter à un
/// passage ultérieur du même endroit (boucles, aller-retour).
class RouteMatcher {
  RouteMatcher(this.ghost, {this.maxOffRouteM = 40, this.lookAheadM = 300})
    : assert(ghost.hasRoute);

  final Ghost ghost;

  /// Plus loin du tracé, on est « hors parcours ».
  final double maxOffRouteM;
  final double lookAheadM;

  var _segment = 0;

  /// Distance le long du tracé, `null` si hors parcours.
  double? alongRoute(GeoPoint me) {
    final pts = ghost.points;
    final origin = pts[_segment].position!;
    final limit = pts[_segment].distanceM + lookAheadM;
    double? best;
    var bestOffset = double.infinity;
    var bestSegment = _segment;
    for (var i = _segment; i < pts.length - 1; i++) {
      if (pts[i].distanceM > limit) break;
      final a = _local(origin, pts[i].position!);
      final b = _local(origin, pts[i + 1].position!);
      final p = _local(origin, me);
      final (offset, f) = _project(p, a, b);
      if (offset < bestOffset) {
        bestOffset = offset;
        bestSegment = i;
        best = pts[i].distanceM + f * (pts[i + 1].distanceM - pts[i].distanceM);
      }
    }
    if (bestOffset > maxOffRouteM) return null;
    _segment = bestSegment;
    return best;
  }

  static (double, double) _local(GeoPoint o, GeoPoint p) {
    const r = 6371000.0;
    const rad = pi / 180;
    return (
      (p.longitude - o.longitude) * rad * r * cos(o.latitude * rad),
      (p.latitude - o.latitude) * rad * r,
    );
  }

  /// Distance au segment [a, b] et position relative (0..1) du projeté.
  static (double, double) _project(
    (double, double) p,
    (double, double) a,
    (double, double) b,
  ) {
    final (dx, dy) = (b.$1 - a.$1, b.$2 - a.$2);
    final len2 = dx * dx + dy * dy;
    final f = len2 == 0
        ? 0.0
        : (((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dy) / len2).clamp(0.0, 1.0);
    final (x, y) = (a.$1 + f * dx, a.$2 + f * dy);
    return (sqrt(pow(p.$1 - x, 2) + pow(p.$2 - y, 2)), f);
  }
}
