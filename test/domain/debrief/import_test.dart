import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/debrief/clean_activity.dart';
import 'package:running_tools/domain/debrief/fit_reader.dart';
import 'package:running_tools/domain/debrief/gpx_activity.dart';
import 'package:running_tools/domain/debrief/session_type.dart';

import '../../fixtures/activities.dart';

void main() {
  group('lecture', () {
    test('export Strava : nom, FC et cadence dans les extensions', () {
      final raw = parseGpxActivity(
        File('test/fixtures/strava_export.gpx').readAsStringSync(),
      );
      expect(raw.name, 'Course à pied le matin');
      expect(raw.samples, hasLength(4));
      expect(raw.samples[1].heartRate, 101);
      expect(raw.samples[1].cadence, 82);
      expect(raw.samples[1].elevationM, 170.3);
    });

    test('FIT : records lus, autres messages sautés, temps compressé', () {
      final points = easyRun(km: 1);
      final raw = parseFitActivity(toFit(points), name: 'Garmin');
      expect(raw.samples, hasLength(points.length));
      final first = raw.samples.first;
      expect(first.time, DateTime.utc(2026, 11, 8, 9));
      expect(first.position!.latitude, closeTo(45.75, 1e-4));
      expect(first.elevationM, closeTo(points.first.elevation, 0.2));
      expect(first.heartRate, points.first.hr);
      expect(first.distanceM, isNotNull);
      // Dernier point : horodatage reconstruit depuis l'en-tête compressé.
      expect(
        raw.samples.last.time,
        DateTime.utc(2026, 11, 8, 9).add(Duration(seconds: points.last.second)),
      );
    });

    test('FIT : FC absente (0xFF) lue comme manquante', () {
      final raw = parseFitActivity(
        toFit(easyRun(km: 0.5, withHeartRate: false)),
      );
      expect(raw.samples.every((s) => s.heartRate == null), isTrue);
    });

    test('fichiers illisibles : erreur claire', () {
      expect(() => parseGpxActivity('<<'), throwsFormatException);
      expect(
        () => parseFitActivity(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('nettoyage', () {
    test('footing propre : distance, temps, cadence en pas/min', () {
      final a = CleanActivity.from(parseGpxActivity(toGpx(easyRun())));
      expect(a.distanceM, closeTo(5000, 75));
      expect(a.movingS, closeTo(5000 / (11 / 3.6), 15));
      expect(a.pauses, isEmpty);
      expect(a.hasHeartRate && a.hasCadence && a.hasElevation, isTrue);
      expect(a.points[100].cadence, inInclusiveRange(168, 172));
    });

    test('pause au km 2 détectée et retirée du temps', () {
      final a = CleanActivity.from(
        parseGpxActivity(toGpx(easyRun(pauseS: 90))),
      );
      expect(a.pauses, hasLength(1));
      expect(a.pauses.single.atM, closeTo(2000, 30));
      // Les secondes de ralentissement et de relance restent du mouvement.
      expect(a.pauses.single.duration.inSeconds, closeTo(90, 10));
      expect(a.elapsed.inSeconds - a.movingS, closeTo(90, 10));
    });

    test('marcher n’est pas une pause : 3 min à 4 km/h, 2 min à 2,5 km/h', () {
      final points = scriptedRun(
        km: 4,
        kmhAt: (d) => d > 1500 && d < 1700
            ? 4
            : d > 2500 && d < 2585
            ? 2.5
            : 11,
      );
      final a = CleanActivity.from(parseGpxActivity(toGpx(points)));
      expect(a.pauses, isEmpty);
      expect(a.movingS, closeTo(points.last.second, 3));
    });

    test('GPS perdu en avançant (tunnel) : pas une pause', () {
      final points = scriptedRun(km: 3, kmhAt: (_) => 12);
      final withGap = [
        for (final p in points)
          if (p.second < 400 || p.second > 460) p,
      ];
      final a = CleanActivity.from(parseGpxActivity(toGpx(withGap)));
      expect(a.pauses, isEmpty);
      expect(a.distanceM, closeTo(3000, 40));
    });

    test('trou dans l’enregistrement (pause auto) : compté comme pause', () {
      final points = easyRun(km: 2);
      final shifted = [
        for (final p in points)
          p.second < 300
              ? p
              : FixturePoint(
                  p.second + 120,
                  p.northM,
                  p.elevation,
                  p.hr,
                  p.cad,
                ),
      ];
      final a = CleanActivity.from(parseGpxActivity(toGpx(shifted)));
      expect(a.pauses.single.duration.inSeconds, 121);
    });

    test('FC aberrante écartée ; sans FC ni cadence, pas d’erreur', () {
      final strava = CleanActivity.from(
        parseGpxActivity(
          File('test/fixtures/strava_export.gpx').readAsStringSync(),
        ),
      );
      expect(strava.points.map((p) => p.heartRate), isNot(contains(255)));
      final bare = CleanActivity.from(
        parseGpxActivity(
          toGpx(easyRun(withHeartRate: false, withCadence: false)),
        ),
      );
      expect(bare.hasHeartRate, isFalse);
      expect(bare.hasCadence, isFalse);
      expect(bare.distanceM, greaterThan(4900));
    });

    test('FIT : distance de la montre utilisée', () {
      final a = CleanActivity.from(parseFitActivity(toFit(easyRun(km: 3))));
      expect(a.distanceM, closeTo(3000, 10));
      expect(a.rejectedFixes, 0);
    });

    test('D+ : bosses courtes comptées, bruit de ±1 m ignoré', () {
      // Trois bosses de 8 m sur 80 m chacune, puis la bosse de 60 m.
      double rolling(double d) {
        final bump = d % 400;
        if (d < 1200 && bump < 80) return 200 + 8 * sin(bump / 80 * pi);
        return hillAt(d);
      }

      final a = CleanActivity.from(
        parseGpxActivity(
          toGpx(scriptedRun(km: 6, kmhAt: (_) => 11, elevationAt: rolling)),
        ),
      );
      final c = a.elevationChange()!;
      expect(c.gain, closeTo(3 * 8 + 60, 6));
      expect(c.loss, closeTo(3 * 8 + 60, 6));
      // Le profil lissé, lui, écrase les petites bosses.
      expect(a.profile!.climb().gain, lessThan(c.gain - 10));
    });

    test('profil d’altitude lissé', () {
      final a = CleanActivity.from(parseGpxActivity(toGpx(easyRun(km: 2))));
      final profile = a.profile!;
      expect(profile.distanceM, closeTo(a.distanceM, 10));
      expect(profile.climb().gain, lessThan(5));
    });
  });

  group('type de séance', () {
    CleanActivity run(List<FixturePoint> p) =>
        CleanActivity.from(parseGpxActivity(toGpx(p)));

    test('footing : endurance', () {
      expect(
        detectSessionType(run(easyRun()), vmaKmh: 16),
        SessionType.endurance,
      );
    });

    test('20 km : sortie longue', () {
      expect(detectSessionType(run(easyRun(km: 20))), SessionType.long);
    });

    test('allure régulière à 90 % de VMA sur 10 km : course', () {
      expect(
        detectSessionType(run(easyRun(km: 10, kmh: 14.4)), vmaKmh: 16),
        SessionType.race,
      );
    });

    test('8 × (1 min vite, 1 min lent) : fractionné', () {
      final points = <FixturePoint>[];
      var d = 0.0;
      for (var s = 0; s < 20 * 60; s++) {
        final fast = s >= 180 && (s - 180) ~/ 60 % 2 == 0 && s < 180 + 16 * 60;
        d += (fast ? 16 : 9) / 3.6;
        points.add(FixturePoint(s, d, 200, 150, 85));
      }
      expect(detectSessionType(run(points), vmaKmh: 17), SessionType.interval);
    });
  });
}
