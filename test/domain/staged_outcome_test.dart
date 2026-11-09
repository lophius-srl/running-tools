import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_outcome.dart';

void main() {
  final schedule = BeepSchedule.generate(
    StagedTest.vameval.defaultProtocol,
    duration: const Duration(minutes: 25),
  );
  StagedOutcome at(double t, [StagedTest test = StagedTest.vameval]) =>
      StagedOutcome.at(test, schedule, t);

  test('décroché pendant l\'intro : aucun résultat', () {
    final o = at(-4);
    expect(o.hasResult, isFalse);
    expect(o.result(prorata: true), isNull);
    expect(o.distanceM, 0);
  });

  test('décroché pendant le palier 1 : aucun palier complet', () {
    expect(at(45).hasResult, isFalse);
  });

  test('pile au changement de palier : palier 1 complet, 0 % du suivant', () {
    final o = at(60);
    expect(o.completedStages, 1);
    expect(o.fractionOfNextStage, 0);
    expect(o.result(prorata: false)!.vmaKmh, 8);
  });

  test('milieu du palier 2 : prorata optionnel', () {
    final o = at(90);
    expect(o.completedStages, 1);
    expect(o.fractionOfNextStage, closeTo(0.5, 1e-9));
    expect(o.result(prorata: false)!.vmaKmh, 8);
    expect(o.result(prorata: true)!.vmaKmh, closeTo(8.25, 1e-9));
  });

  test('VAMEVAL palier 14 complet : VMA 14,5', () {
    final o = at(14 * 60 + 10);
    expect(o.completedStages, 14);
    expect(o.result(prorata: false)!.vmaKmh, 14.5);
    expect(o.result(prorata: false)!.vo2max, closeTo(50.75, 1e-9));
  });

  test('piste terminée : dernier palier complet', () {
    final o = at(25 * 60 + 3);
    expect(o.completedStages, 25);
    expect(o.fractionOfNextStage, 0);
    expect(o.result(prorata: true)!.vmaKmh, 20);
  });

  test('Luc Léger : formule de Léger sur la vitesse retenue', () {
    final leger = BeepSchedule.generate(
      StagedTest.lucLeger.defaultProtocol,
      duration: const Duration(minutes: 20),
    );
    // 8 paliers complets : 8,5 + 7 × 0,5 = 12 km/h.
    final o = StagedOutcome.at(StagedTest.lucLeger, leger, 8 * 60 + 5);
    expect(o.result(prorata: false)!.vo2max, closeTo(50.826, 1e-3));
  });
}
