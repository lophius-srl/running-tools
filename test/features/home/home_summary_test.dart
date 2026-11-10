import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/checklist.dart';
import 'package:running_tools/domain/orthostatic.dart';
import 'package:running_tools/features/home/home_summary.dart';

void main() {
  final now = DateTime(2026, 11, 10, 18);

  RaceChecklist race(String id, DateTime date) =>
      RaceChecklist(id: id, raceName: id, raceDate: date, items: const []);

  OrthostaticResult ortho(int day, int stable) => OrthostaticResult(
    date: DateTime(2026, 11, day, 7),
    lyingBpm: 50,
    standingPeakBpm: stable + 15,
    standingStableBpm: stable,
    source: HeartRateSourceKind.manual,
  );

  test('prochaine course : la plus proche à venir, aujourd’hui compris', () {
    final s = HomeSummary.from(
      tests: const [],
      orthostatic: const [],
      races: [
        race('passée', DateTime(2026, 11, 2)),
        race('lointaine', DateTime(2026, 12, 20)),
        race('ce matin', DateTime(2026, 11, 10, 9)),
      ],
      now: now,
    );
    expect(s.nextRace!.id, 'ce matin');
    expect(s.lastTest, isNull);
    expect(s.form, isNull);
  });

  test('forme : dernier test comparé aux précédents', () {
    final s = HomeSummary.from(
      tests: const [],
      // Du plus récent au plus ancien.
      orthostatic: [ortho(10, 90), ortho(7, 70), ortho(4, 71), ortho(1, 69)],
      races: const [],
      now: now,
    );
    expect(s.form!.result.delta, 40);
    expect(s.form!.status, FormStatus.watch);
  });

  test('textes de date', () {
    expect(agoText(DateTime(2026, 11, 10, 6), now), 'aujourd’hui');
    expect(agoText(DateTime(2026, 11, 9, 23), now), 'hier');
    expect(agoText(DateTime(2026, 10, 29), now), 'il y a 12 j');
    expect(untilText(DateTime(2026, 11, 11), now), 'demain');
    expect(untilText(DateTime(2026, 11, 19), now), 'dans 9 j');
  });
}
