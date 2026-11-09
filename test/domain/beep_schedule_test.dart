import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/stage_protocol.dart';

void main() {
  const vameval = StageProtocol.vameval();
  final schedule = BeepSchedule.generate(
    vameval,
    duration: const Duration(minutes: 15),
  );

  List<BeepEvent> ofKind(BeepKind kind) =>
      schedule.events.where((e) => e.kind == kind).toList();

  test('palier 1 à 8 km/h et 20 m : un bip toutes les 9 s', () {
    final firstMarkers = ofKind(BeepKind.marker).take(6).map((e) => e.timeS);
    expect(firstMarkers, [9, 18, 27, 36, 45, 54].map((t) => closeTo(t, 1e-9)));
  });

  test('le changement de palier tombe au milieu d\'un intervalle', () {
    final change = ofKind(BeepKind.stageChange).first;
    expect(change.timeS, 60);
    expect(change.stage, 2);
    expect(change.distanceM, closeTo(133.333, 1e-3));

    // 140 m atteints à 8,5 km/h après 133,33 m.
    final seventh = ofKind(BeepKind.marker)[6];
    expect(seventh.distanceM, 140);
    expect(seventh.timeS, closeTo(60 + (140 - 400 / 3) / (8.5 / 3.6), 1e-9));
  });

  test('intervalles constants dans un palier, sans dérive', () {
    final stage10 = ofKind(BeepKind.marker)
        .where((e) => e.stage == 10)
        .toList();
    final expected = 20 / (vameval.speedKmh(10) / 3.6);
    for (var i = 1; i < stage10.length; i++) {
      expect(stage10[i].timeS - stage10[i - 1].timeS, closeTo(expected, 1e-9));
    }
  });

  test('15 min de VAMEVAL : 15 paliers, jusqu\'à 15 km/h', () {
    expect(ofKind(BeepKind.stageChange), hasLength(14));
    expect(schedule.stageCount, 15);
    expect(schedule.positionAt(899).speedKmh, 15);
    expect(schedule.events.first.kind, BeepKind.start);
    expect(schedule.events.last.kind, BeepKind.end);
    expect(schedule.events.last.timeS, 900);
  });

  test(
    'repères : multiples de l\'espacement, chronologiques, sans doublon',
    () {
      final markers = ofKind(BeepKind.marker);
      for (var i = 0; i < markers.length; i++) {
        expect(markers[i].distanceM, closeTo(20.0 * (i + 1), 1e-9));
        if (i > 0) expect(markers[i].timeS, greaterThan(markers[i - 1].timeS));
      }
      final total = schedule.positionAt(900).distanceM;
      expect(markers, hasLength((total / 20).floor()));
    },
  );

  test('repère pile sur un changement de palier : compté une seule fois', () {
    // 12 km/h pendant 60 s = 200 m, multiple exact de 20 m.
    const protocol = StageProtocol(
      startSpeedKmh: 12,
      incrementKmh: 1,
      stageDuration: Duration(minutes: 1),
      markerSpacingM: 20,
    );
    final s = BeepSchedule.generate(
      protocol,
      duration: const Duration(minutes: 3),
    );
    final at200 = s.events.where(
      (e) => e.kind == BeepKind.marker && (e.distanceM - 200).abs() < 1e-6,
    );
    expect(at200, hasLength(1));
    expect(at200.single.timeS, closeTo(60, 1e-9));
  });

  test('espacement libre (23,77 m)', () {
    final s = BeepSchedule.generate(
      const StageProtocol.vameval(markerSpacingM: 23.77),
      duration: const Duration(minutes: 2),
    );
    final first = s.events.firstWhere((e) => e.kind == BeepKind.marker);
    expect(first.timeS, closeTo(23.77 / (8 / 3.6), 1e-9));
  });

  test('positionAt : palier et fraction', () {
    final p = schedule.positionAt(90);
    expect(p.stage, 2);
    expect(p.speedKmh, 8.5);
    expect(p.fractionOfStage, closeTo(0.5, 1e-9));
    expect(p.distanceM, closeTo(400 / 3 + 30 * 8.5 / 3.6, 1e-9));

    final end = schedule.positionAt(900);
    expect(end.stage, 15);
    expect(end.fractionOfStage, 1);
  });
}
