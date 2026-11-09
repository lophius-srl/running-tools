import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/distance_tracker.dart';

/// Marche en ligne droite le long de x, par pas de [step] mètres.
List<MarkerCrossing> walk(
  DistanceTracker tracker, {
  required double to,
  double step = 0.1,
  double from = 0,
  double z = 0,
}) {
  final crossings = <MarkerCrossing>[];
  for (var x = from + step; x <= to + 1e-9; x += step) {
    crossings.addAll(tracker.update(GroundPoint(x, z)));
  }
  return crossings;
}

void main() {
  test('chemin : un repère tous les 20 m, placé au bon endroit', () {
    final tracker = DistanceTracker(spacingM: 20)
      ..start(const GroundPoint(0, 0));
    final crossings = walk(tracker, to: 45);

    expect(crossings.map((c) => c.index), [1, 2]);
    expect(crossings.first.point.x, closeTo(20, 1e-6));
    expect(crossings.last.point.x, closeTo(40, 1e-6));
    expect(tracker.distanceM, closeTo(45, 1e-6));
  });

  test('chemin : suit une courbe (demi-cercle de rayon 10 m)', () {
    final tracker = DistanceTracker(spacingM: 10)
      ..start(const GroundPoint(10, 0));
    const steps = 600;
    for (var i = 1; i <= steps; i++) {
      final a = 3.141592653589793 * i / steps;
      tracker.update(GroundPoint(10 * cos(a), 10 * sin(a)));
    }
    expect(tracker.distanceM, closeTo(31.4159, 0.01));
    expect(tracker.markersCrossed, 3);
  });

  test('chemin : le tremblement sous 5 cm ne gonfle pas la distance', () {
    final tracker = DistanceTracker(spacingM: 20)
      ..start(const GroundPoint(0, 0));
    for (var i = 0; i < 1000; i++) {
      tracker.update(GroundPoint(i.isEven ? 0.02 : -0.02, 0));
    }
    expect(tracker.distanceM, 0);
  });

  test('ligne droite : distance au départ, repère dans l\'axe', () {
    final tracker = DistanceTracker(
      spacingM: 20,
      mode: DistanceMode.straightLine,
    )..start(const GroundPoint(0, 0));
    final crossings = walk(tracker, to: 21, z: 3);

    expect(crossings, hasLength(1));
    expect(crossings.single.point.distanceTo(const GroundPoint(0, 0)), 20);
    expect(tracker.distanceM, closeTo(21.2132, 1e-3));
  });

  test('ligne droite : revenir en arrière ne recompte pas un repère', () {
    final tracker = DistanceTracker(
      spacingM: 20,
      mode: DistanceMode.straightLine,
    )..start(const GroundPoint(0, 0));
    walk(tracker, to: 21);
    for (var x = 21.0; x > 15; x -= 0.1) {
      tracker.update(GroundPoint(x, 0));
    }
    final again = walk(tracker, from: 15, to: 25);
    expect(again, isEmpty);
    expect(tracker.markersCrossed, 1);
  });

  test('un saut isolé du point visé est ignoré', () {
    final tracker = DistanceTracker(spacingM: 20)
      ..start(const GroundPoint(0, 0));
    walk(tracker, to: 5);
    tracker.update(const GroundPoint(30, 0));
    walk(tracker, from: 5, to: 6);
    expect(tracker.distanceM, closeTo(6, 1e-6));
  });

  test('sauts répétés : nouvelle référence, sans compter le saut', () {
    final tracker = DistanceTracker(spacingM: 20)
      ..start(const GroundPoint(0, 0));
    walk(tracker, to: 5);
    for (var i = 0; i < 5; i++) {
      tracker.update(const GroundPoint(30, 0));
    }
    walk(tracker, from: 30, to: 31);
    expect(tracker.distanceM, closeTo(6, 1e-6));
  });

  test('perte de suivi : rien n\'est compté pendant la pause ni au retour', () {
    final tracker = DistanceTracker(spacingM: 20)
      ..start(const GroundPoint(0, 0));
    walk(tracker, to: 5);
    tracker.pause();
    walk(tracker, from: 5, to: 8);
    expect(tracker.distanceM, closeTo(5, 1e-6));

    tracker
      ..resume()
      ..update(const GroundPoint(9, 0));
    walk(tracker, from: 9, to: 10);
    expect(tracker.distanceM, closeTo(6, 1e-6));
  });

  test('sans départ, aucun point n\'est compté', () {
    final tracker = DistanceTracker(spacingM: 20);
    expect(tracker.update(const GroundPoint(5, 0)), isEmpty);
    expect(tracker.distanceM, 0);
  });
}
