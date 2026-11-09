import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/track_lanes.dart';

void main() {
  const track = TrackGeometry.standard;

  test('valeurs de contrôle : couloirs 1, 2 et 8', () {
    expect(track.lapLengthM(1), closeTo(400.00, 0.005));
    expect(track.lapLengthM(2), closeTo(407.04, 0.005));
    expect(track.lapLengthM(8), closeTo(453.03, 0.005));
  });

  test('du couloir 2 au 8, chaque couloir ajoute 2π × 1,22 ≈ 7,67 m', () {
    for (var lane = 2; lane < 8; lane++) {
      expect(
        track.lapLengthM(lane + 1) - track.lapLengthM(lane),
        closeTo(7.665, 0.001),
      );
    }
    // Du 1 au 2 : seulement 7,04 m (mesure à 30 cm puis 20 cm).
    expect(track.lapLengthM(2) - track.lapLengthM(1), closeTo(7.04, 0.005));
  });

  test('allure → temps : 400 m à 15 km/h', () {
    // Couloir 1 : 96 s ; couloir 4 : 422,37 m soit 101,37 s.
    expect(track.splitFor(400, 1, 15).inMilliseconds, 96000);
    expect(
      track.splitFor(400, 4, 15).inMilliseconds / 1000,
      closeTo(101.37, 0.01),
    );
  });

  test('temps → allure réelle : 400 m en 1:36 au couloir 3', () {
    final speed = track.realSpeedKmh(400, 3, const Duration(seconds: 96));
    expect(speed, closeTo(414.70 / 96 * 3.6, 1e-3));
    expect(speed, greaterThan(15));
  });

  test('aller-retour allure → temps → allure', () {
    for (var lane = 1; lane <= 8; lane++) {
      final split = track.splitFor(1000, lane, 16.5);
      expect(track.realSpeedKmh(1000, lane, split), closeTo(16.5, 1e-6));
    }
  });

  test('couloir hors piste ou valeurs impossibles refusés', () {
    expect(() => track.lapLengthM(0), throwsRangeError);
    expect(() => track.lapLengthM(9), throwsRangeError);
    expect(() => track.splitFor(400, 1, 0), throwsArgumentError);
    expect(
      () => track.realSpeedKmh(400, 1, Duration.zero),
      throwsArgumentError,
    );
  });
}
