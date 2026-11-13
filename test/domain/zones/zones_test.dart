import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/zones/zone_inputs.dart';
import 'package:running_tools/domain/zones/zones.dart';

void main() {
  group('ZoneService', () {
    final ref = ZoneService.compute(
      vmaKmh: 11.9,
      maxHeartRate: 203,
      restHeartRate: 80,
    );

    test(
      'référence : VMA 11,9, FC max 203, repos 80 → Z2 8\'24–6\'43, 154–169',
      () {
        final z2 = ref[ZoneId.z2];
        expect(formatZonePace(z2.slowestPace!), "8'24");
        expect(formatZonePace(z2.fastestPace!), "6'43");
        expect(z2.minBpm, 154);
        expect(z2.maxBpm, 169);
        expect(paceRange(z2), "8'24–6'43");
        expect(bpmRange(z2), '154–169');
      },
    );

    test('zones contiguës, Z1 ouverte en bas', () {
      expect(ref[ZoneId.z1].minKmh, isNull);
      expect(ref[ZoneId.z1].minBpm, isNull);
      expect(paceRange(ref[ZoneId.z1]), startsWith('> '));
      for (var i = 1; i < 5; i++) {
        expect(ref.zones[i].minKmh, ref.zones[i - 1].maxKmh);
        expect(ref.zones[i].minBpm, ref.zones[i - 1].maxBpm);
      }
      expect(ref[ZoneId.z5].maxBpm, 203);
      expect(ref[ZoneId.z5].maxKmh, closeTo(11.9 * 1.05, 1e-9));
    });

    test('zone d’une vitesse et d’une FC', () {
      expect(ref.zoneForSpeed(8), ZoneId.z2);
      expect(ref.zoneForSpeed(10.5), ZoneId.z4);
      expect(ref.zoneForSpeed(20), ZoneId.z5);
      expect(ref.zoneForHeartRate(160), ZoneId.z2);
      expect(ref.zoneForHeartRate(195), ZoneId.z5);
    });

    test('sans FC : allures seules ; sans VMA : FC seules', () {
      final pace = ZoneService.compute(vmaKmh: 12);
      expect(pace.hasPace, isTrue);
      expect(pace.hasHeartRate, isFalse);
      expect(pace.zoneForHeartRate(150), isNull);
      final hr = ZoneService.compute(maxHeartRate: 190, restHeartRate: 50);
      expect(hr.hasPace, isFalse);
      expect(hr[ZoneId.z2].maxBpm, (50 + 0.72 * 140).round());
    });

    test('bornes ajustées en % et en bpm, jamais écrasées', () {
      final settings = const ZoneSettings()
          .withPaceUpper(1, 72)
          .withHeartRateUpperBpm(1, 165);
      final z = ZoneService.compute(
        vmaKmh: 11.9,
        maxHeartRate: 203,
        restHeartRate: 80,
        settings: settings,
      );
      expect(z[ZoneId.z2].maxKmh, closeTo(11.9 * 0.72, 1e-9));
      expect(z[ZoneId.z3].minKmh, closeTo(11.9 * 0.72, 1e-9));
      expect(z[ZoneId.z2].maxBpm, 165);
      expect(z[ZoneId.z3].minBpm, 165);
      // Nouvelles entrées : la borne en bpm reste.
      final again = ZoneService.compute(
        vmaKmh: 13,
        maxHeartRate: 195,
        restHeartRate: 55,
        settings: settings,
      );
      expect(again[ZoneId.z2].maxBpm, 165);
      expect(settings.isDefault, isFalse);
      expect(const ZoneSettings().isDefault, isTrue);
    });

    test('réglages : aller-retour JSON, invalides ignorés', () {
      final s = const ZoneSettings()
          .withHeartRateUpper(2, 80)
          .withHeartRateUpperBpm(0, 130);
      final back = ZoneSettings.fromJson(s.toJson());
      expect(back.heartRateUpper[2], 80);
      expect(back.heartRateUpperBpm[0], 130);
      final broken = const ZoneSettings().withPaceUpper(1, 50);
      expect(broken.isValid, isFalse);
      expect(ZoneSettings.fromJson(broken.toJson()).isDefault, isTrue);
    });

    test('différences entre deux versions', () {
      final next = ZoneService.compute(
        vmaKmh: 12.5,
        maxHeartRate: 203,
        restHeartRate: 80,
      );
      final changes = diffZones(ref, next);
      expect(changes, hasLength(5));
      expect(changes[1].text, startsWith("Z2 : 8'24–6'43 → "));
      expect(changes[1].text, isNot(contains('bpm')));
      expect(diffZones(ref, ref), isEmpty);
      expect(ref.sameAs(ZoneSet.fromJson(ref.toJson())!), isTrue);
    });
  });

  group('entrées', () {
    final now = DateTime(2026, 11, 13);

    test('VMA : dernier test, sauf saisie plus récente', () {
      final test = (vmaKmh: 14.5, date: DateTime(2026, 10, 1), kind: 'VAMEVAL');
      final fromTest = resolveVma(latestTest: test)!;
      expect(fromTest.source, InputSource.test);
      expect(fromTest.detail, 'VAMEVAL');
      final manual = resolveVma(
        manual: (value: 15.0, date: DateTime(2026, 10, 20)),
        latestTest: test,
      )!;
      expect(manual.source, InputSource.manual);
      // Un nouveau test après la saisie reprend la main.
      final newer = resolveVma(
        manual: (value: 15.0, date: DateTime(2026, 9, 1)),
        latestTest: test,
      )!;
      expect(newer.source, InputSource.test);
    });

    test('FC max : saisie > relevée > 220 − âge', () {
      final observed = (value: 188, date: DateTime(2026, 10, 3));
      expect(
        resolveMaxHeartRate(
          manual: (value: 195, date: now),
          observed: observed,
          now: now,
        )!.value,
        195,
      );
      final obs = resolveMaxHeartRate(
        observed: observed,
        birthYear: 1985,
        now: now,
      )!;
      expect((obs.value, obs.source), (188, InputSource.observed));
      final est = resolveMaxHeartRate(birthYear: 1985, now: now)!;
      expect((est.value, est.source), (179, InputSource.estimated));
      expect(maxHeartRateReminder(est), contains('peu fiable'));
      expect(resolveMaxHeartRate(now: now), isNull);
    });

    test('FC de repos : moyenne des 5 dernières mesures couché', () {
      final measures = [
        for (var i = 0; i < 7; i++)
          (bpm: 50 + i, date: DateTime(2026, 11, 1 + i)),
      ];
      final rest = resolveRestHeartRate(lyingMeasures: measures)!;
      // Les 5 plus récentes : 52 à 56.
      expect(rest.value, 54);
      expect(rest.count, 5);
      expect(rest.date, DateTime(2026, 11, 7));
      expect(rest.source, InputSource.orthostatic);
      final manual = resolveRestHeartRate(
        manual: (value: 48, date: DateTime(2026, 11, 10)),
        lyingMeasures: measures,
      )!;
      expect(manual.value, 48);
    });

    test('rappels quand c’est ancien', () {
      final old = ProfileValue(
        value: 14.0,
        source: InputSource.test,
        date: DateTime(2026, 9, 1),
      );
      expect(
        vmaReminder(old, now),
        'Ta VMA date de 10 semaines : refais un test.',
      );
      expect(
        vmaReminder(
          ProfileValue(value: 14.0, source: InputSource.test, date: now),
          now,
        ),
        isNull,
      );
      expect(vmaReminder(null, now), isNotNull);
      expect(restHeartRateReminder(null, now), isNotNull);
    });
  });
}
