import 'dart:collection';
import 'dart:math';

/// Détection de pas à partir de l'accéléromètre (accélération sans gravité).
///
/// À chaque appui, la norme de l'accélération présente un pic. On retire la
/// moyenne glissante, puis on compte les pics au-dessus d'un seuil, séparés
/// d'au moins [minStepInterval] (240 pas/min au maximum).
class CadenceDetector {
  CadenceDetector({
    this.threshold = 2.0,
    this.minStepInterval = const Duration(milliseconds: 250),
    this.window = const Duration(seconds: 10),
    this.meanWindow = const Duration(seconds: 2),
  });

  /// Seuil au-dessus de la moyenne (m/s²).
  final double threshold;
  final Duration minStepInterval;

  /// Fenêtre sur laquelle la cadence est calculée.
  final Duration window;

  /// Fenêtre de la moyenne glissante retirée au signal.
  final Duration meanWindow;

  final _recent = Queue<(Duration, double)>();
  var _sum = 0.0;
  final _steps = Queue<Duration>();
  double? _previous;
  var _rising = false;

  /// Ajoute un échantillon à [time] ; renvoie `true` si un pas est détecté.
  bool add(Duration time, double x, double y, double z) {
    final magnitude = sqrt(x * x + y * y + z * z);
    _recent.add((time, magnitude));
    _sum += magnitude;
    while (_recent.isNotEmpty && time - _recent.first.$1 > meanWindow) {
      _sum -= _recent.removeFirst().$2;
    }
    final value = magnitude - _sum / _recent.length;

    var step = false;
    final previous = _previous;
    if (previous != null) {
      // Pic : le signal montait et redescend, au-dessus du seuil.
      if (_rising && value < previous && previous > threshold) {
        final last = _steps.isEmpty ? null : _steps.last;
        if (last == null || time - last >= minStepInterval) {
          _steps.add(time);
          step = true;
        }
      }
      _rising = value > previous;
    }
    _previous = value;
    while (_steps.isNotEmpty && time - _steps.first > window) {
      _steps.removeFirst();
    }
    return step;
  }

  /// Pas par minute sur la fenêtre ; `null` tant qu'il y a moins de 4 pas.
  double? get cadence {
    if (_steps.length < 4) return null;
    final span = _steps.last - _steps.first;
    if (span <= Duration.zero) return null;
    return (_steps.length - 1) / (span.inMicroseconds / 6e7);
  }

  void reset() {
    _recent.clear();
    _sum = 0;
    _steps.clear();
    _previous = null;
    _rising = false;
  }
}

/// Écart entre la cadence mesurée et la cible, en pas/min (positif = trop
/// rapide) ; `null` sans mesure.
double? cadenceDeviation(double? measured, int target) =>
    measured == null ? null : measured - target;
