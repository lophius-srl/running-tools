import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/course_profile.dart';
import 'package:running_tools/domain/debrief/activity.dart';
import 'package:running_tools/domain/debrief/clean_activity.dart';
import 'package:running_tools/domain/debrief/effort_track.dart';
import 'package:running_tools/domain/debrief/gpx_activity.dart';
import 'package:running_tools/domain/debrief/pacing_analysis.dart';
import 'package:running_tools/domain/debrief/session_type.dart';
import 'package:running_tools/domain/grade_pace.dart';

import '../../fixtures/activities.dart';

EffortTrack track(List<FixturePoint> points) =>
    EffortTrack(CleanActivity.from(parseGpxActivity(toGpx(points))));

/// Vitesse à effort constant sur le relief : la vitesse plat divisée par le
/// facteur de pente du modèle.
double Function(double) equalEffort(double flatKmh) => (d) {
  final grade = (hillAt(d + 5) - hillAt(d - 5)) / 10;
  return flatKmh / gradePaceFactor(grade);
};

void main() {
  group('splits et régularité', () {
    final even = track(scriptedRun(km: 10, kmhAt: (_) => 12));
    final pacing = PacingAnalysis.of(even, SessionType.endurance);

    test('10 splits de 5:00/km, sans écart', () {
      expect(pacing.splits, hasLength(10));
      expect(pacing.splits.first.index, 1);
      for (final s in pacing.splits) {
        expect(s.paceS, closeTo(300, 6));
      }
      expect(pacing.irregularity!, lessThan(0.02));
      expect(pacing.splitDeltaS.abs(), lessThan(10));
      expect(pacing.fastStartPercent!.abs(), lessThan(2));
    });

    test('allure régulière : rien à gagner', () {
      expect(pacing.gainableS!, lessThan(5));
    });

    test('départ trop rapide : repéré, split positif, temps gagnable', () {
      final t = track(
        scriptedRun(km: 10, kmhAt: (d) => d < 3000 ? 13.5 : 11.2),
      );
      final p = PacingAnalysis.of(t, SessionType.race);
      expect(p.fastStartPercent!, greaterThan(10));
      expect(p.splitDeltaS, greaterThan(60));
      expect(p.irregularity!, greaterThan(0.05));
      // Estimation prudente : quelques secondes, pas des minutes.
      expect(p.gainableS!, inInclusiveRange(3, 40));
    });

    test('fractionné : pas de temps gagnable', () {
      expect(PacingAnalysis.of(even, SessionType.interval).gainableS, isNull);
    });
  });

  group('relief', () {
    test('effort régulier sur la bosse : rien à gagner, rien de perdu', () {
      final t = track(
        scriptedRun(km: 6, kmhAt: equalEffort(12), elevationAt: hillAt),
      );
      final p = PacingAnalysis.of(t, SessionType.endurance);
      expect(p.gainableS!, lessThan(8));
      final hills = hillReports(t);
      expect(hills.map((h) => h.section.kind), [
        SectionKind.climb,
        SectionKind.descent,
      ]);
      for (final h in hills) {
        expect(h.lostS.abs(), lessThan(10));
      }
      // Les splits bruts varient, l'allure corrigée non.
      expect(p.splits[2].paceS, greaterThan(p.splits[0].paceS + 30));
      expect(p.irregularity!, lessThan(0.03));
    });

    test('même vitesse partout : montée trop forcée, descente trop lente', () {
      final t = track(
        scriptedRun(
          km: 6,
          kmhAt: (_) => 12,
          elevationAt: hillAt,
          hrAt: (d, s) => d > 2000 && d < 3000 ? 175 : 150,
        ),
      );
      final p = PacingAnalysis.of(t, SessionType.endurance);
      final [climb, descent] = hillReports(t);
      expect(climb.lostS, lessThan(-20));
      expect(descent.lostS, greaterThan(5));
      expect(climb.peakHeartRate, 175);
      expect(climb.gain, closeTo(57, 5));
      expect(p.gainableS!, greaterThan(5));
    });

    test('sans altitude : pas de sections, allure brute', () {
      final raw = parseGpxActivity(toGpx(scriptedRun(km: 3, kmhAt: (_) => 12)));
      final noEle = CleanActivity.from(
        RawActivity(
          name: raw.name,
          samples: [
            for (final s in raw.samples)
              ActivitySample(time: s.time, position: s.position),
          ],
        ),
      );
      final t = EffortTrack(noEle);
      expect(t.profile, isNull);
      expect(hillReports(t), isEmpty);
      expect(t.equivalentM, closeTo(t.distanceM, 1e-9));
    });
  });

  group('VMA', () {
    test('footing à 70 % de VMA : dans la plage', () {
      final t = track(scriptedRun(km: 8, kmhAt: (_) => 11.2));
      final v = compareToVma(t, SessionType.endurance, 16)!;
      expect(v.percent, closeTo(70, 2));
      expect(v.verdict, VmaVerdict.inRange);
    });

    test(
      'footing à 85 % : trop vite ; course de 10 km à 85 % : dans la plage',
      () {
        final t = track(scriptedRun(km: 10, kmhAt: (_) => 13.6));
        expect(
          compareToVma(t, SessionType.endurance, 16)!.verdict,
          VmaVerdict.fast,
        );
        final race = compareToVma(t, SessionType.race, 16)!;
        expect(race.expected.low, 84);
        expect(race.verdict, VmaVerdict.inRange);
      },
    );

    test('fractionné : pas de comparaison', () {
      final t = track(scriptedRun(km: 3, kmhAt: (_) => 12));
      expect(compareToVma(t, SessionType.interval, 16), isNull);
    });
  });
}
