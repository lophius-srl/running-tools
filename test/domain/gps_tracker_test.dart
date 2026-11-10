import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/gps_tracker.dart';

/// Trace simulée : départ à Lyon, cap au nord-est, bruit gaussien.
List<GpsFix> simulate({
  required double speedMps,
  required int seconds,
  double noiseM = 0,
  double accuracyM = 5,
  int seed = 1,
}) {
  const start = GeoPoint(45.75, 4.85);
  final random = Random(seed);
  double gauss() =>
      sqrt(-2 * log(1 - random.nextDouble())) *
      cos(2 * pi * random.nextDouble());
  final t0 = DateTime(2026, 11, 10, 8);
  return [
    for (var s = 0; s <= seconds; s++)
      GpsFix(
        time: t0.add(Duration(seconds: s)),
        position: offset(
          start,
          speedMps * s / sqrt2 + noiseM * gauss(),
          speedMps * s / sqrt2 + noiseM * gauss(),
        ),
        accuracyM: accuracyM,
      ),
  ];
}

GeoPoint offset(GeoPoint p, double eastM, double northM) => GeoPoint(
  p.latitude + northM / 6371000 * 180 / pi,
  p.longitude + eastM / (6371000 * cos(p.latitude * pi / 180)) * 180 / pi,
);

double run(List<GpsFix> fixes, [GpsTracker? tracker]) {
  final t = tracker ?? GpsTracker();
  fixes.forEach(t.add);
  return t.distanceM;
}

void main() {
  test('haversine : 1° de latitude ≈ 111,2 km', () {
    expect(
      haversineM(const GeoPoint(45, 4), const GeoPoint(46, 4)),
      closeTo(111195, 10),
    );
  });

  test('trace propre : distance exacte', () {
    // 10 min à 12 km/h = 2 000 m.
    final d = run(simulate(speedMps: 10 / 3, seconds: 600));
    expect(d, closeTo(2000, 10));
  });

  for (final seed in [1, 2, 3]) {
    test('trace bruitée (±4 m, graine $seed) : à 3 % près', () {
      final d = run(
        simulate(speedMps: 10 / 3, seconds: 600, noiseM: 4, seed: seed),
      );
      expect(d, closeTo(2000, 60));
    });
  }

  test('immobile 5 min avec un bruit sévère : distance quasi nulle', () {
    final d = run(simulate(speedMps: 0, seconds: 300, noiseM: 4));
    expect(d, lessThan(40));
  });

  test('footing lent (8 km/h) bruité : compté entièrement', () {
    final d = run(simulate(speedMps: 8 / 3.6, seconds: 600, noiseM: 3));
    expect(d, closeTo(8000 / 6, 40));
  });

  test('point imprécis écarté', () {
    final t = GpsTracker();
    final fixes = simulate(speedMps: 3, seconds: 10);
    t.add(fixes[0]);
    final bad = GpsFix(
      time: fixes[1].time,
      position: fixes[1].position,
      accuracyM: 65,
    );
    expect(t.add(bad), FixRejection.inaccurate);
    expect(t.rejected, 1);
    expect(t.accuracyM, 5);
  });

  test('point en retard ou en double écarté', () {
    final t = GpsTracker();
    final fixes = simulate(speedMps: 3, seconds: 10);
    t.add(fixes[2]);
    expect(t.add(fixes[1]), FixRejection.outOfOrder);
    expect(t.add(fixes[2]), FixRejection.outOfOrder);
  });

  test('saut isolé de 500 m : écarté, distance intacte', () {
    final fixes = simulate(speedMps: 10 / 3, seconds: 120);
    final p = fixes[60];
    fixes[60] = GpsFix(
      time: p.time,
      position: offset(p.position, 500, 0),
      accuracyM: 5,
    );
    final t = GpsTracker();
    final d = run(fixes, t);
    expect(t.rejected, 1);
    expect(d, closeTo(400, 10));
  });

  test('premier point faux : on repart du GPS sans compter le saut', () {
    final fixes = simulate(speedMps: 3, seconds: 100);
    final wrong = GpsFix(
      time: fixes[0].time.subtract(const Duration(seconds: 1)),
      position: offset(fixes[0].position, 2000, 0),
      accuracyM: 20,
    );
    final t = GpsTracker();
    final d = run([wrong, ...fixes], t);
    expect(t.rejected, 4);
    // Les 5 premières secondes sont perdues, le reste est compté.
    expect(d, closeTo(300 - 5 * 3, 10));
  });

  test('position lissée exposée', () {
    final t = GpsTracker();
    expect(t.position, isNull);
    final fixes = simulate(speedMps: 3, seconds: 60);
    fixes.forEach(t.add);
    expect(haversineM(t.position!, fixes.last.position), lessThan(5));
  });

  test('trou de 2 min sans bouger : la vitesse d’avant n’est pas comptée', () {
    final fixes = simulate(speedMps: 3, seconds: 60);
    final last = fixes.last;
    final t = GpsTracker();
    fixes.forEach(t.add);
    final before = t.distanceM;
    t.add(
      GpsFix(
        time: last.time.add(const Duration(minutes: 2)),
        position: last.position,
        accuracyM: 5,
      ),
    );
    expect(t.distanceM - before, lessThan(10));
  });
}
