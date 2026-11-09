import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/shoe_measure.dart';

void main() {
  test('pas pour un espacement : entiers + reste', () {
    final shoe = ShoeMeasure(0.295);
    final r = shoe.stepsFor(20);
    expect(r.steps, 67);
    expect(r.remainderM, closeTo(0.235, 1e-9));
  });

  test('division exacte : pas de reste parasite', () {
    final r = ShoeMeasure(0.25).stepsFor(20);
    expect(r.steps, 80);
    expect(r.remainderM, 0);
  });

  test('inverse : distance pour un nombre de pas', () {
    expect(ShoeMeasure(0.295).distanceFor(80), closeTo(23.6, 1e-9));
  });

  test('calibrage sur une distance connue', () {
    final shoe = ShoeMeasure.calibrated(distanceM: 10, steps: 34);
    expect(shoe.footLengthM, closeTo(0.2941, 1e-4));
  });

  test('valeurs impossibles refusées', () {
    expect(() => ShoeMeasure(0), throwsArgumentError);
    expect(
      () => ShoeMeasure.calibrated(distanceM: 10, steps: 0),
      throwsArgumentError,
    );
  });
}
