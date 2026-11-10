import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/ghost.dart';
import 'package:running_tools/domain/gps_tracker.dart';

/// Point à [eastM] / [northM] mètres d'une origine lyonnaise.
GeoPoint at(double eastM, double northM) => GeoPoint(
  45.75 + northM / 6371000 * 180 / pi,
  4.85 + eastM / (6371000 * cos(45.75 * pi / 180)) * 180 / pi,
);

void main() {
  // Référence : 1 km en 300 s (5'00/km), plein nord, un point toutes les 10 s.
  final reference = Ghost(
    name: 'Sortie du 2 novembre',
    points: [
      for (var t = 0; t <= 300; t += 10)
        GhostPoint(
          timeS: t.toDouble(),
          distanceM: t * 10 / 3,
          position: at(0, t * 10 / 3),
        ),
    ],
  );

  group('fantôme enregistré', () {
    test('interpolation temps ↔ distance', () {
      expect(reference.timeAtDistance(500), closeTo(150, 1e-9));
      expect(reference.distanceAtTime(75), closeTo(250, 1e-9));
      expect(reference.timeAtDistance(1001), isNull);
      expect(reference.distanceAtTime(400), 1000);
      expect(reference.totalTimeS, 300);
      expect(reference.hasRoute, isTrue);
    });

    test('heure de départ quelconque : temps relatifs', () {
      final g = Ghost(
        name: 'x',
        points: const [
          GhostPoint(timeS: 1000, distanceM: 0),
          GhostPoint(timeS: 1100, distanceM: 400),
        ],
      );
      expect(g.timeAtDistance(200), 50);
      expect(g.distanceAtTime(50), 200);
      expect(g.totalTimeS, 100);
    });

    test('points désordonnés refusés', () {
      expect(
        () => Ghost(
          name: 'x',
          points: const [
            GhostPoint(timeS: 10, distanceM: 0),
            GhostPoint(timeS: 5, distanceM: 10),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('écart', () {
    test('plus rapide : devant, en secondes et en mètres', () {
      // 500 m en 140 s au lieu de 150 s.
      final gap = gapAt(reference, timeS: 140, distanceM: 500);
      expect(gap.seconds, closeTo(10, 1e-9));
      expect(gap.meters, closeTo(500 - 140 * 10 / 3, 1e-9));
      expect(gap.ahead, isTrue);
    });

    test('plus lent : derrière', () {
      final gap = gapAt(reference, timeS: 160, distanceM: 500);
      expect(gap.seconds, closeTo(-10, 1e-9));
      expect(gap.ahead, isFalse);
    });

    test('fantôme arrivé : comparaison au temps final', () {
      // À 990 m, le fantôme y était à 297 s.
      final before = gapAt(reference, timeS: 320, distanceM: 990);
      expect(before.seconds, closeTo(-23, 1e-9));
      expect(before.meters, closeTo(-10, 1e-9));
      // Au-delà de ses 1 000 m : son temps final (300 s).
      final after = gapAt(reference, timeS: 320, distanceM: 1005);
      expect(after.seconds, -20);
    });
  });

  group('fantôme virtuel', () {
    final virtual = Ghost.constantPace(const Duration(minutes: 5));

    test('allure constante, sans fin', () {
      expect(virtual.name, 'Allure 5:00/km');
      expect(virtual.timeAtDistance(10000), closeTo(3000, 1e-9));
      expect(virtual.distanceAtTime(60), closeTo(200, 1e-9));
      expect(virtual.totalDistanceM, isNull);
      expect(virtual.hasRoute, isFalse);
    });

    test('distance fixe', () {
      final tenK = Ghost.constantPace(
        const Duration(minutes: 4, seconds: 30),
        distanceKm: 10,
      );
      expect(tenK.totalTimeS, closeTo(2700, 1e-9));
      expect(tenK.distanceAtTime(3000), 10000);
      expect(tenK.timeAtDistance(10001), isNull);
    });
  });

  group('même parcours', () {
    test('position projetée sur le tracé', () {
      final m = RouteMatcher(reference);
      // 8 m à l'est du tracé, à 250 m du départ.
      expect(m.alongRoute(at(8, 250)), closeTo(250, 0.5));
      expect(m.alongRoute(at(-5, 400)), closeTo(400, 0.5));
    });

    test('hors parcours : null', () {
      final m = RouteMatcher(reference);
      expect(m.alongRoute(at(100, 200)), isNull);
    });

    test('aller-retour : pas de saut au passage du retour', () {
      // Aller 500 m au nord puis retour par le même chemin.
      final outAndBack = Ghost(
        name: 'aller-retour',
        points: [
          for (var d = 0; d <= 1000; d += 20)
            GhostPoint(
              timeS: d * 0.3,
              distanceM: d.toDouble(),
              position: at(0, d <= 500 ? d.toDouble() : 1000.0 - d),
            ),
        ],
      );
      final m = RouteMatcher(outAndBack);
      // À l'aller, à 100 m du départ : c'est 100, pas 900.
      expect(m.alongRoute(at(2, 100)), closeTo(100, 0.5));
      for (var d = 120; d <= 500; d += 40) {
        m.alongRoute(at(2, d.toDouble()));
      }
      // Au retour, au même endroit : c'est 900.
      for (var d = 460; d >= 100; d -= 40) {
        m.alongRoute(at(2, d.toDouble()));
      }
      expect(m.alongRoute(at(2, 100)), closeTo(900, 0.5));
    });
  });
}
