import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/test_results.dart';

void main() {
  group('Cooper', () {
    test('2800 m : VMA 14 km/h, VO2max ≈ 51,3', () {
      final r = cooperResult(2800);
      expect(r.vmaKmh, 14);
      expect(r.vo2max, closeTo(51.31, 0.01));
    });

    test('distance nulle refusée', () {
      expect(() => cooperResult(0), throwsArgumentError);
    });
  });

  group('demi-Cooper', () {
    test('1500 m : VMA 15 km/h, VO2max 52,5', () {
      final r = halfCooperResult(1500);
      expect(r.vmaKmh, 15);
      expect(r.vo2max, closeTo(52.5, 1e-9));
    });

    test('distance négative refusée', () {
      expect(() => halfCooperResult(-1), throwsArgumentError);
    });
  });

  group('vitesse retenue (tests par paliers)', () {
    const vameval = StageProtocol.vameval();

    test('dernier palier complet', () {
      expect(reachedSpeedKmh(vameval, completedStages: 14), 14.5);
    });

    test('la fraction est ignorée sans prorata', () {
      expect(
        reachedSpeedKmh(vameval, completedStages: 14, fractionOfNextStage: 0.5),
        14.5,
      );
    });

    test('prorata du palier entamé', () {
      expect(
        reachedSpeedKmh(
          vameval,
          completedStages: 14,
          fractionOfNextStage: 0.5,
          prorata: true,
        ),
        14.75,
      );
    });

    test('aucun palier complet : refusé', () {
      expect(
        () => reachedSpeedKmh(vameval, completedStages: 0),
        throwsArgumentError,
      );
    });

    test('fraction hors de [0, 1[ : refusée', () {
      expect(
        () => reachedSpeedKmh(
          vameval,
          completedStages: 3,
          fractionOfNextStage: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  test('VAMEVAL : VO2max = 3,5 × VMA', () {
    final r = vamevalResult(16);
    expect(r.vmaKmh, 16);
    expect(r.vo2max, 56);
  });

  test('Luc Léger : 12 km/h → VO2max ≈ 50,83, VMA ≈ 14,5', () {
    final r = lucLegerResult(12);
    expect(r.vo2max, closeTo(50.826, 1e-3));
    expect(r.vmaKmh, closeTo(14.52, 0.01));
  });
}
