import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/course_profile.dart';
import 'package:running_tools/domain/debrief/clean_activity.dart';
import 'package:running_tools/domain/debrief/effort_track.dart';
import 'package:running_tools/domain/debrief/gpx_activity.dart';
import 'package:running_tools/domain/debrief/pacing_analysis.dart';
import 'package:running_tools/domain/debrief/session_type.dart';
import 'package:running_tools/features/debrief/debrief_text.dart';

import '../../fixtures/activities.dart';

EffortTrack track(List<FixturePoint> p) =>
    EffortTrack(CleanActivity.from(parseGpxActivity(toGpx(p))));

void main() {
  test('durées dites simplement', () {
    expect(spokenDuration(35), '35 s');
    expect(spokenDuration(124), '2 min 04');
    expect(spokenDuration(-120), '2 min');
  });

  test('sortie régulière : un seul constat, positif', () {
    final t = track(scriptedRun(km: 8, kmhAt: (_) => 11));
    final f = keyFindings(
      pacing: PacingAnalysis.of(t, SessionType.endurance),
      hills: hillReports(t),
      vma: compareToVma(t, SessionType.endurance, 16),
      type: SessionType.endurance,
    );
    expect(f.single.positive, isTrue);
  });

  test('3 constats au plus, le plus coûteux d’abord', () {
    final t = track(
      scriptedRun(
        km: 8,
        kmhAt: (d) => d < 3000 ? 13.5 : 11,
        elevationAt: hillAt,
        hrAt: (d, s) => d > 2000 && d < 3000 ? 180 : 150,
      ),
    );
    final f = keyFindings(
      pacing: PacingAnalysis.of(t, SessionType.endurance),
      hills: hillReports(t),
      vma: compareToVma(t, SessionType.endurance, 14),
      type: SessionType.endurance,
    );
    expect(f.length, lessThanOrEqualTo(3));
    // Trop rapide pour une endurance à 14 km/h de VMA : en tête.
    expect(f.first.text, startsWith('Trop rapide pour une endurance'));
    expect(f.any((x) => x.text.contains('côte du km 2 (FC 180)')), isTrue);
    for (var i = 1; i < f.length; i++) {
      expect(f[i].impactS, lessThanOrEqualTo(f[i - 1].impactS));
    }
  });

  test('fractionné : pas de reproche d’allure', () {
    final t = track(scriptedRun(km: 8, kmhAt: (d) => d < 3000 ? 13.5 : 11));
    final f = keyFindings(
      pacing: PacingAnalysis.of(t, SessionType.interval),
      hills: const [],
      vma: null,
      type: SessionType.interval,
    );
    expect(f.single.positive, isTrue);
    expect(gainableText(null), isNull);
  });

  test('phrases des sections', () {
    const climb = HillReport(
      section: CourseSection(kind: SectionKind.climb, from: 200, to: 300),
      gain: 57,
      loss: 0,
      timeS: 300,
      expectedS: 400,
      peakHeartRate: 178,
      afterSlowdownS: 44,
    );
    expect(
      hillLine(climb),
      'Côte du km 2 au km 3 (+57 m) : tu as poussé fort, FC max 178, et tu '
      'as ralenti ensuite (+44 s/km sur 2 km).',
    );
    expect(
      vmaLine(null, 16, SessionType.endurance),
      'Pas de comparaison pour le fractionné.',
    );
    expect(gainableText(2), startsWith('Effort bien réparti'));
    expect(
      gainableText(124),
      'En gardant le même effort du début à la fin, tu aurais pu gagner '
      'environ 2 min 04 (estimation).',
    );
  });
}
