import 'dart:math';

/// Position géographique (degrés).
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Un point brut fourni par le GPS.
class GpsFix {
  const GpsFix({
    required this.time,
    required this.position,
    required this.accuracyM,
  });

  final DateTime time;
  final GeoPoint position;

  /// Rayon d'incertitude horizontale (m).
  final double accuracyM;
}

/// Pourquoi un point a été écarté.
enum FixRejection { inaccurate, outOfOrder, impossibleSpeed }

/// Réglages du filtre, adaptés à la course à pied.
class GpsFilterSettings {
  const GpsFilterSettings({
    this.maxAccuracyM = 25,
    this.maxSpeedMps = 11,
    this.accelerationNoise = 0.5,
    this.minSpeedMps = 1.0,
    this.resetAfterRejections = 5,
  });

  /// Au-delà, le point est trop imprécis.
  final double maxAccuracyM;

  /// ~40 km/h : plus rapide qu'un sprinteur, donc un saut du GPS.
  final double maxSpeedMps;

  /// Accélération plausible (m/s²) du modèle « vitesse constante » du
  /// filtre de Kalman : plus petit = plus lisse, mais suit moins vite.
  final double accelerationNoise;

  /// En dessous, on est arrêté : le bruit ne compte pas dans la distance.
  final double minSpeedMps;

  /// Après autant de vitesses impossibles d'affilée, on repart du GPS
  /// (c'était l'estimation qui était fausse, pas les points).
  final int resetAfterRejections;
}

const _earthRadiusM = 6371000.0;

/// Distance (m) entre deux positions, formule de haversine.
double haversineM(GeoPoint a, GeoPoint b) {
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(rad(a.latitude)) * cos(rad(b.latitude)) * pow(sin(dLon / 2), 2);
  return 2 * _earthRadiusM * asin(sqrt(h));
}

/// Filtre de Kalman sur un axe : position et vitesse.
class _Axis {
  _Axis(this.p, double variance) : p00 = variance;

  double p;
  double v = 0;
  double p00;
  double p01 = 0;
  double p10 = 0;
  double p11 = 16; // vitesse initiale inconnue : ±4 m/s

  double predicted(double dt) => p + v * dt;

  void predict(double dt, double q) {
    p += v * dt;
    final q2 = q * q;
    final n00 = p00 + dt * (p10 + p01) + dt * dt * p11;
    final n01 = p01 + dt * p11;
    final n10 = p10 + dt * p11;
    p00 = n00 + q2 * pow(dt, 4) / 4;
    p01 = n01 + q2 * pow(dt, 3) / 2;
    p10 = n10 + q2 * pow(dt, 3) / 2;
    p11 = p11 + q2 * dt * dt;
  }

  void update(double z, double r) {
    final s = p00 + r;
    final k0 = p00 / s;
    final k1 = p10 / s;
    final y = z - p;
    p += k0 * y;
    v += k1 * y;
    final (o00, o01) = (p00, p01);
    p00 = (1 - k0) * o00;
    p01 = (1 - k0) * o01;
    p10 -= k1 * o00;
    p11 -= k1 * o01;
  }
}

/// Suivi en direct : rejette les points aberrants, lisse la position
/// (filtre de Kalman position + vitesse, la précision du point servant de
/// variance) et cumule la distance. Ne garde aucune trace : seulement
/// l'état courant.
class GpsTracker {
  GpsTracker({this.settings = const GpsFilterSettings()});

  final GpsFilterSettings settings;

  GeoPoint? _origin;
  // Estimation lissée, en mètres autour de l'origine.
  _Axis? _east;
  _Axis? _north;
  double get _x => _east!.p;
  double get _y => _north!.p;
  DateTime? _lastTime;
  var _speedRejections = 0;

  var _distanceM = 0.0;
  double? _accuracyM;
  var _rejected = 0;

  double get distanceM => _distanceM;

  /// Précision du dernier point accepté (m), `null` avant le premier.
  double? get accuracyM => _accuracyM;

  /// Nombre de points écartés.
  int get rejected => _rejected;

  /// Position lissée courante.
  GeoPoint? get position {
    final o = _origin;
    if (o == null || _east == null) return null;
    return GeoPoint(
      o.latitude + _y / _earthRadiusM * 180 / pi,
      o.longitude +
          _x / (_earthRadiusM * cos(o.latitude * pi / 180)) * 180 / pi,
    );
  }

  /// Intègre un point ; renvoie la raison du rejet, ou `null` s'il est pris.
  FixRejection? add(GpsFix fix) {
    final rejection = _check(fix);
    if (rejection != null) {
      _rejected++;
      return rejection;
    }
    final (zx, zy) = _project(fix.position);
    final measureVariance = fix.accuracyM * fix.accuracyM;
    if (_east == null) {
      _reset(zx, zy, measureVariance);
    } else {
      final dt = fix.time.difference(_lastTime!).inMilliseconds / 1000;
      final q = settings.accelerationNoise;
      _east!
        ..predict(dt, q)
        ..update(zx, measureVariance);
      _north!
        ..predict(dt, q)
        ..update(zy, measureVariance);
      _count(dt);
    }
    _lastTime = fix.time;
    _accuracyM = fix.accuracyM;
    return null;
  }

  FixRejection? _check(GpsFix fix) {
    if (fix.accuracyM <= 0 || fix.accuracyM > settings.maxAccuracyM) {
      return FixRejection.inaccurate;
    }
    final last = _lastTime;
    if (last == null) {
      _origin = fix.position;
      return null;
    }
    if (!fix.time.isAfter(last)) return FixRejection.outOfOrder;
    final dt = fix.time.difference(last).inMilliseconds / 1000;
    final (zx, zy) = _project(fix.position);
    final jump = sqrt(
      pow(zx - _east!.predicted(dt), 2) + pow(zy - _north!.predicted(dt), 2),
    );
    // Marge : l'incertitude du point peut expliquer une partie du saut.
    if ((jump - fix.accuracyM) / dt > settings.maxSpeedMps) {
      if (++_speedRejections < settings.resetAfterRejections) {
        return FixRejection.impossibleSpeed;
      }
      _reset(zx, zy, fix.accuracyM * fix.accuracyM);
    }
    _speedRejections = 0;
    return null;
  }

  void _reset(double x, double y, double variance) {
    _east = _Axis(x, variance);
    _north = _Axis(y, variance);
    _speedRejections = 0;
  }

  /// Vitesse lissée (m/s), 0 avant le premier point.
  double get speedMps =>
      _east == null ? 0 : sqrt(pow(_east!.v, 2) + pow(_north!.v, 2));

  /// Distance = vitesse lissée × temps : le zigzag du bruit ne s'ajoute pas.
  void _count(double dt) {
    final speed = speedMps;
    if (speed >= settings.minSpeedMps) _distanceM += speed * dt;
  }

  (double, double) _project(GeoPoint p) {
    final o = _origin!;
    final rad = pi / 180;
    return (
      (p.longitude - o.longitude) * rad * _earthRadiusM * cos(o.latitude * rad),
      (p.latitude - o.latitude) * rad * _earthRadiusM,
    );
  }
}
