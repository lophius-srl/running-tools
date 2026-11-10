import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/debrief/cardio_analysis.dart';
import 'package:running_tools/domain/debrief/clean_activity.dart';
import 'package:running_tools/domain/debrief/debrief_score.dart';
import 'package:running_tools/domain/debrief/debrief_summary.dart';
import 'package:running_tools/domain/debrief/effort_track.dart';
import 'package:running_tools/domain/debrief/gpx_activity.dart';
import 'package:running_tools/domain/debrief/pacing_analysis.dart';
import 'package:running_tools/domain/debrief/session_type.dart';
import 'package:running_tools/domain/gps_tracker.dart';

import '../../fixtures/activities.dart';

DebriefScore scoreOf(
  List<FixturePoint> points, {
  SessionType type = SessionType.endurance,
  ({double share, bool byHeartRate})? zones,
}) {
  final a = CleanActivity.from(parseGpxActivity(toGpx(points)));
  final t = EffortTrack(a);
  return debriefScore(
    pacing: PacingAnalysis.of(t, type),
    hills: hillReports(t),
    type: type,
    movingS: a.movingS,
    zones: zones,
    drift: cardiacDrift(t, type),
    cadence: cadenceReport(a),
  );
}

void main() {
  group('note', () {
    test('sortie régulière : très bien gérée', () {
      final s = scoreOf(scriptedRun(km: 10, kmhAt: (_) => 11));
      expect(s.value, greaterThanOrEqualTo(95));
      expect(s.label, 'Très bien gérée');
    });

    test('départ trop rapide puis ralentissement : note plus basse', () {
      final s = scoreOf(
        scriptedRun(km: 10, kmhAt: (d) => d < 3000 ? 13.5 : 10.5),
      );
      expect(s.value, lessThan(85));
      expect(
        s.penalties.keys,
        containsAll(['Départ rapide', 'Ralentissement']),
      );
      for (final p in s.penalties.values) {
        expect(p, lessThanOrEqualTo(20));
      }
    });

    test('endurance trop intense : pénalité plafonnée à 20', () {
      final s = scoreOf(
        scriptedRun(km: 8, kmhAt: (_) => 11),
        zones: (share: 0.9, byHeartRate: true),
      );
      expect(s.penalties['Trop intense'], 20);
      expect(s.value, 80);
    });

    test('fractionné : les variations d’allure ne coûtent rien', () {
      final s = scoreOf(
        scriptedRun(km: 10, kmhAt: (d) => d < 3000 ? 13.5 : 10.5),
        type: SessionType.interval,
      );
      expect(s.penalties, isEmpty);
      expect(s.value, 100);
    });
  });

  group('historique', () {
    DebriefSummary summary(String id, GeoPoint start, double km) =>
        DebriefSummary(
          id: id,
          date: DateTime(2026, 11, 8),
          name: 'Boucle du parc',
          type: SessionType.endurance,
          distanceM: km * 1000,
          movingS: km * 330,
          score: 82,
          findings: const ['Tu es parti trop vite.'],
          gainableS: 34,
          averageHeartRate: 151,
          start: start,
        );

    test('aller-retour JSON', () {
      final s = summary('d1', const GeoPoint(45.75, 4.85), 10);
      final back = DebriefSummary.fromJson(s.toJson())!;
      expect(back.score, 82);
      expect(back.findings.single, 'Tu es parti trop vite.');
      expect(back.gainableS, 34);
      expect(back.driftPercent, isNull);
      expect(back.start!.latitude, 45.75);
      expect(back.paceS, closeTo(330, 1e-9));
    });

    test('même parcours : départ proche et distance à 5 % près', () {
      final a = summary('a', const GeoPoint(45.75, 4.85), 10);
      final near = summary('b', const GeoPoint(45.7512, 4.85), 10.3);
      final far = summary('c', const GeoPoint(45.76, 4.85), 10);
      final longer = summary('d', const GeoPoint(45.75, 4.85), 12);
      expect(sameRoute(a, near), isTrue);
      expect(sameRoute(a, far), isFalse);
      expect(sameRoute(a, longer), isFalse);
    });
  });
}
