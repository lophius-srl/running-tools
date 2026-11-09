import 'dart:math';

/// Point au sol (plan horizontal), en mètres.
class GroundPoint {
  const GroundPoint(this.x, this.z);

  final double x;
  final double z;

  double distanceTo(GroundPoint other) =>
      sqrt(pow(other.x - x, 2) + pow(other.z - z, 2));

  /// Point situé à la fraction [t] du segment vers [other].
  GroundPoint lerp(GroundPoint other, double t) =>
      GroundPoint(x + (other.x - x) * t, z + (other.z - z) * t);
}

enum DistanceMode {
  /// Distance à vol d'oiseau depuis le départ (navette, ligne droite).
  straightLine,

  /// Longueur du chemin parcouru (piste courbe).
  path,
}

/// Un repère franchi : le N-ième multiple de l'espacement.
class MarkerCrossing {
  const MarkerCrossing(this.index, this.distanceM, this.point);

  final int index;
  final double distanceM;
  final GroundPoint point;
}

/// Mesure une distance au sol à partir d'une suite de points visés, et signale
/// chaque repère franchi tous les [spacingM] mètres.
class DistanceTracker {
  DistanceTracker({
    required this.spacingM,
    this.mode = DistanceMode.path,
    this.minStepM = 0.05,
    this.maxStepM = 1.5,
    this.jumpsBeforeReanchor = 5,
  });

  final double spacingM;
  final DistanceMode mode;

  /// En dessous, le déplacement est considéré comme du tremblement.
  final double minStepM;

  /// Au-dessus, le point est un saut aberrant du point visé : ignoré.
  final double maxStepM;

  /// Nombre de sauts consécutifs avant d'accepter la nouvelle position
  /// (sans compter la distance du saut).
  final int jumpsBeforeReanchor;

  GroundPoint? _start;
  GroundPoint? _last;
  var _distance = 0.0;
  var _markersCrossed = 0;
  var _consecutiveJumps = 0;
  var _paused = false;

  bool get isStarted => _start != null;
  bool get isPaused => _paused;
  double get distanceM => _distance;
  int get markersCrossed => _markersCrossed;

  void start(GroundPoint point) {
    _start = point;
    _last = point;
    _distance = 0;
    _markersCrossed = 0;
    _consecutiveJumps = 0;
    _paused = false;
  }

  /// Suivi perdu : les points reçus sont ignorés jusqu'à [resume].
  void pause() => _paused = true;

  /// Suivi retrouvé : le prochain point devient la référence, sans ajouter le
  /// déplacement survenu pendant la perte.
  void resume() {
    if (!_paused) return;
    _paused = false;
    _last = null;
  }

  /// Intègre un nouveau point visé ; renvoie les repères franchis.
  List<MarkerCrossing> update(GroundPoint point) {
    final start = _start;
    if (start == null || _paused) return const [];
    final last = _last;
    if (last == null) {
      _last = point;
      return const [];
    }

    final step = last.distanceTo(point);
    if (step > maxStepM) {
      if (++_consecutiveJumps >= jumpsBeforeReanchor) {
        _last = point;
        _consecutiveJumps = 0;
      }
      return const [];
    }
    _consecutiveJumps = 0;

    return switch (mode) {
      DistanceMode.path => _updatePath(last, point, step),
      DistanceMode.straightLine => _updateStraight(start, point),
    };
  }

  List<MarkerCrossing> _updatePath(
    GroundPoint last,
    GroundPoint point,
    double step,
  ) {
    if (step < minStepM) return const [];
    final before = _distance;
    _distance += step;
    _last = point;
    final crossings = <MarkerCrossing>[];
    while ((_markersCrossed + 1) * spacingM <= _distance) {
      _markersCrossed++;
      final markerDistance = _markersCrossed * spacingM;
      final t = (markerDistance - before) / step;
      crossings.add(
        MarkerCrossing(_markersCrossed, markerDistance, last.lerp(point, t)),
      );
    }
    return crossings;
  }

  List<MarkerCrossing> _updateStraight(GroundPoint start, GroundPoint point) {
    _last = point;
    final distance = start.distanceTo(point);
    _distance = distance;
    final crossings = <MarkerCrossing>[];
    while ((_markersCrossed + 1) * spacingM <= distance) {
      _markersCrossed++;
      final markerDistance = _markersCrossed * spacingM;
      crossings.add(
        MarkerCrossing(
          _markersCrossed,
          markerDistance,
          start.lerp(point, markerDistance / distance),
        ),
      );
    }
    return crossings;
  }
}
