import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/stage_protocol.dart';

void main() {
  test('préréglages', () {
    final vameval = StagedTest.vameval.defaultProtocol;
    expect(vameval.startSpeedKmh, 8);
    expect(vameval.incrementKmh, 0.5);
    expect(vameval.markerSpacingM, 20);

    final leger = StagedTest.lucLeger.defaultProtocol;
    expect(leger.startSpeedKmh, 8.5);
    expect(leger.incrementKmh, 0.5);
    expect(leger.stageDuration, const Duration(minutes: 1));
    expect(leger.markerSpacingM, 20);
  });

  test('copyWith : espacement libre, le reste inchangé', () {
    final p = StagedTest.vameval.defaultProtocol.copyWith(
      markerSpacingM: 23.77,
    );
    expect(p.markerSpacingM, 23.77);
    expect(p.startSpeedKmh, 8);
  });

  test('validation', () {
    expect(StagedTest.vameval.defaultProtocol.isValid, isTrue);
    const bad = StageProtocol(
      startSpeedKmh: 0,
      incrementKmh: -0.5,
      stageDuration: Duration.zero,
      markerSpacingM: double.nan,
    );
    expect(bad.validationErrors, hasLength(4));
    expect(bad.isValid, isFalse);
  });

  test('incrément nul autorisé (vitesse constante)', () {
    final p = StagedTest.vameval.defaultProtocol.copyWith(incrementKmh: 0);
    expect(p.isValid, isTrue);
  });

  group('planning Luc Léger', () {
    final schedule = BeepSchedule.generate(
      StagedTest.lucLeger.defaultProtocol,
      duration: const Duration(minutes: 3),
    );
    final lines = schedule.events
        .where((e) => e.kind == BeepKind.marker)
        .toList();

    test('premier demi-tour : 20 m à 8,5 km/h', () {
      expect(lines.first.timeS, closeTo(20 / (8.5 / 3.6), 1e-9));
    });

    test('palier 1 : 7 lignes (141,7 m), palier 2 à 9 km/h', () {
      expect(lines.where((e) => e.stage == 1), hasLength(7));
      expect(schedule.positionAt(61).speedKmh, 9);
      final eighth = lines[7];
      expect(eighth.stage, 2);
      expect(
        eighth.timeS,
        closeTo(60 + (160 - 8.5 / 3.6 * 60) / (9 / 3.6), 1e-9),
      );
    });
  });
}
