import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/club_session.dart';
import 'package:running_tools/domain/stage_protocol.dart';

void main() {
  late ClubSession session;

  setUp(
    () => session = ClubSession(
      test: StagedTest.vameval,
      schedule: BeepSchedule.generate(
        StagedTest.vameval.defaultProtocol,
        duration: const Duration(minutes: 25),
      ),
      names: ['Léa', 'Tom', 'Sam'],
    ),
  );

  test('abandon : palier et fraction enregistrés à l\'instant du tap', () {
    expect(session.dropOut(1, 14 * 60 + 30), isTrue);
    final tom = session.outcomeOf(1)!;
    expect(tom.completedStages, 14);
    expect(tom.fractionOfNextStage, closeTo(0.5, 1e-9));
    expect(session.hasDropped(1), isTrue);
  });

  test('tap avant le départ ou en double : ignoré', () {
    expect(session.dropOut(0, -3), isFalse);
    expect(session.dropOut(0, 600), isTrue);
    expect(session.dropOut(0, 700), isFalse);
    expect(session.outcomeOf(0)!.completedStages, 10);
  });

  test('annulation du dernier abandon', () {
    session
      ..dropOut(0, 600)
      ..dropOut(2, 650);
    expect(session.lastDropOut, 2);
    expect(session.undo(), isTrue);
    expect(session.hasDropped(2), isFalse);
    expect(session.lastDropOut, 0);
  });

  test('classement par vitesse retenue, prorata au choix', () {
    session
      ..dropOut(0, 12 * 60 + 50) // palier 12, 83 % du 13e
      ..dropOut(1, 14 * 60 + 10)
      ..dropOut(2, 12 * 60 + 10);
    expect(session.results(prorata: false).map((r) => r.name), [
      'Tom',
      'Léa',
      'Sam',
    ]);
    final withProrata = session.results(prorata: true);
    expect(withProrata[1].speedKmh, closeTo(13.5 + 0.5 * 50 / 60, 1e-9));
  });

  test('fin du test : les derniers en course ont tenu jusqu\'au bout', () {
    session
      ..dropOut(0, 600)
      ..finishAt(25 * 60 + 2);
    expect(session.allDropped, isTrue);
    expect(session.outcomeOf(1)!.completedStages, 25);
  });

  test('export texte', () {
    session
      ..dropOut(0, 14 * 60 + 10)
      ..dropOut(1, 30);
    expect(
      session.exportText(prorata: false, title: 'Club'),
      'Club\n'
      '1. Léa : palier 14, VMA 14,5 km/h, VO2max 50,8, EF 6:22 /km\n'
      '2. Tom : aucun palier complet',
    );
  });

  test('aucun participant : refusé', () {
    expect(
      () => ClubSession(
        test: StagedTest.vameval,
        schedule: session.schedule,
        names: [],
      ),
      throwsArgumentError,
    );
  });
}
