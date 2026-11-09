import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/cadence.dart';

/// Course simulée : un pic d'impact par pas, bruit, échantillonné à 50 Hz.
int feed(
  CadenceDetector detector, {
  required double spm,
  Duration duration = const Duration(seconds: 20),
  double noise = 0.6,
  int seed = 1,
}) {
  final random = Random(seed);
  final stepPeriod = 60 / spm;
  var steps = 0;
  for (var ms = 0; ms < duration.inMilliseconds; ms += 20) {
    final t = ms / 1000;
    final phase = (t % stepPeriod) / stepPeriod;
    // Pic étroit en début de chaque pas, sur un fond de 9,8 (gravité filtrée
    // imparfaitement) + bruit.
    final impact = phase < 0.15 ? 8 * sin(pi * phase / 0.15) : 0.0;
    final z = 9.8 + impact + (random.nextDouble() - 0.5) * noise;
    final x = (random.nextDouble() - 0.5) * noise;
    if (detector.add(Duration(milliseconds: ms), x, 0, z)) steps++;
  }
  return steps;
}

void main() {
  for (final spm in [150.0, 170.0, 180.0, 195.0]) {
    test('course à $spm pas/min : cadence retrouvée à ±3', () {
      final detector = CadenceDetector();
      feed(detector, spm: spm);
      expect(detector.cadence, closeTo(spm, 3));
    });
  }

  test('nombre de pas sur 20 s à 180 pas/min', () {
    final steps = feed(CadenceDetector(), spm: 180);
    expect(steps, inInclusiveRange(58, 61));
  });

  test('immobile (bruit seul) : aucun pas, pas de cadence', () {
    final detector = CadenceDetector();
    final random = Random(3);
    for (var ms = 0; ms < 10000; ms += 20) {
      detector.add(
        Duration(milliseconds: ms),
        (random.nextDouble() - 0.5) * 0.6,
        0,
        9.8 + (random.nextDouble() - 0.5) * 0.6,
      );
    }
    expect(detector.cadence, isNull);
  });

  test('la cadence suit un changement de rythme', () {
    final detector = CadenceDetector();
    feed(detector, spm: 160);
    expect(detector.cadence, closeTo(160, 3));
    detector.reset();
    feed(detector, spm: 185);
    expect(detector.cadence, closeTo(185, 3));
  });

  test('écart à la cible', () {
    expect(cadenceDeviation(172, 180), -8);
    expect(cadenceDeviation(null, 180), isNull);
  });
}
