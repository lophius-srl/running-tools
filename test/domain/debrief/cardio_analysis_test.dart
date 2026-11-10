import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/debrief/cardio_analysis.dart';
import 'package:running_tools/domain/debrief/clean_activity.dart';
import 'package:running_tools/domain/debrief/effort_track.dart';
import 'package:running_tools/domain/debrief/gpx_activity.dart';
import 'package:running_tools/domain/debrief/session_type.dart';

import '../../fixtures/activities.dart';

CleanActivity clean(List<FixturePoint> p) =>
    CleanActivity.from(parseGpxActivity(toGpx(p)));

/// Footing d'une heure à 11 km/h (≈ 11 km), FC selon le temps (s).
List<FixturePoint> hour(int Function(int s) hr, {int? Function(int s)? cad}) =>
    scriptedRun(
      km: 11,
      kmhAt: (_) => 11,
      hrAt: (d, s) => hr(s),
      cadAt: cad == null ? (d, s) => 85 : (d, s) => cad(s),
    );

void main() {
  group('dérive cardiaque', () {
    test('FC qui monte à vitesse égale : dérive > 5 %', () {
      final a = clean(hour((s) => 145 + (s > 600 ? (s - 600) ~/ 150 : 0)));
      final drift = cardiacDrift(EffortTrack(a), SessionType.endurance)!;
      expect(drift.percent, greaterThan(5));
      expect(drift.significant, isTrue);
      expect(drift.secondHalfHeartRate, greaterThan(drift.firstHalfHeartRate));
    });

    test('FC stable : pas de dérive', () {
      final a = clean(hour((s) => 148 + s % 3));
      final drift = cardiacDrift(EffortTrack(a), SessionType.endurance)!;
      expect(drift.percent.abs(), lessThan(1.5));
      expect(drift.significant, isFalse);
    });

    test('fractionné, sortie courte ou sans FC : pas d’analyse', () {
      final long = EffortTrack(clean(hour((s) => 150)));
      expect(cardiacDrift(long, SessionType.interval), isNull);
      final short = EffortTrack(
        clean(scriptedRun(km: 5, kmhAt: (_) => 11, hrAt: (d, s) => 150)),
      );
      expect(cardiacDrift(short, SessionType.endurance), isNull);
      final noHr = EffortTrack(clean(scriptedRun(km: 11, kmhAt: (_) => 11)));
      expect(cardiacDrift(noHr, SessionType.endurance), isNull);
    });
  });

  group('fiabilité de la FC', () {
    test('FC normale : fiable', () {
      expect(assessHeartRate(clean(hour((s) => 145 + s % 4))).reliable, isTrue);
    });

    test('sauts brusques', () {
      final q = assessHeartRate(clean(hour((s) => s % 40 < 20 ? 140 : 182)));
      expect(q.issues, contains(HeartRateIssue.spikes));
    });

    test('capteur figé plus d’une minute', () {
      final q = assessHeartRate(
        clean(hour((s) => s > 900 && s < 1000 ? 151 : 145 + s % 4)),
      );
      expect(q.issues, contains(HeartRateIssue.dropout));
    });

    test('FC collée à la cadence (capteur optique)', () {
      // Cadence 85 par pied = 170 pas/min ; FC lue à 170.
      final q = assessHeartRate(
        clean(hour((s) => s < 600 ? 140 + s % 3 : 170, cad: (s) => 85)),
      );
      expect(q.issues, contains(HeartRateIssue.cadenceLock));
    });

    test('FC max observée : un pic isolé ne compte pas', () {
      final a = clean(hour((s) => s == 1200 ? 215 : 160 + s % 3));
      expect(observedMaxHeartRate(a), inInclusiveRange(160, 172));
    });
  });

  group('zones', () {
    test('FC à 79 % de la FC max : tout en Z3', () {
      final zones = heartRateZoneTimes(clean(hour((s) => 150)), 190);
      expect(zones[2].seconds, greaterThan(3500));
      expect(shareFrom(zones, 2), closeTo(1, 0.01));
    });

    test('endurance avec 38 % en Z3 : trop intense', () {
      final a = clean(hour((s) => s < 2230 ? 125 : 150));
      final zones = heartRateZoneTimes(a, 190);
      final m = zoneMismatch(
        type: SessionType.endurance,
        heartRateZones: zones,
      )!;
      expect(m.share, closeTo(0.38, 0.03));
      expect(m.byHeartRate, isTrue);
      expect(
        zoneMismatch(type: SessionType.race, heartRateZones: zones),
        isNull,
      );
    });

    test(
      'zones d’allure : 11 km/h pour 16 de VMA = endurance fondamentale',
      () {
        final zones = paceZoneTimes(EffortTrack(clean(hour((s) => 150))), 16);
        expect(
          zones[1].seconds / zones.fold(0.0, (s, z) => s + z.seconds),
          greaterThan(0.95),
        );
        expect(
          zoneMismatch(type: SessionType.endurance, paceZones: zones),
          isNull,
        );
      },
    );
  });

  group('cadence', () {
    test('chute de 170 à 162 pas/min en fin de sortie', () {
      final a = clean(hour((s) => 150, cad: (s) => s > 2900 ? 81 : 85));
      final c = cadenceReport(a)!;
      expect(c.start, closeTo(170, 0.5));
      expect(c.end, closeTo(162, 1));
      expect(c.significantDrop, isTrue);
    });

    test('marche exclue, cadence stable : pas de chute', () {
      final a = clean(hour((s) => 150, cad: (s) => s % 600 < 30 ? 60 : 86));
      final c = cadenceReport(a)!;
      expect(c.average, closeTo(172, 0.5));
      expect(c.significantDrop, isFalse);
    });

    test('sans cadence : pas d’analyse', () {
      expect(
        cadenceReport(clean(scriptedRun(km: 2, kmhAt: (_) => 11))),
        isNull,
      );
    });
  });
}
