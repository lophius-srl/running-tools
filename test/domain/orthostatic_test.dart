import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/orthostatic.dart';

void main() {
  const protocol = OrthostaticProtocol();
  final date = DateTime(2026, 11, 10, 7);

  OrthostaticResult result(int lying, int stable, {int day = 1}) =>
      OrthostaticResult(
        date: DateTime(2026, 10, day, 7),
        lyingBpm: lying,
        standingPeakBpm: stable + 15,
        standingStableBpm: stable,
        source: HeartRateSourceKind.manual,
      );

  group('échantillons continus', () {
    // Couché 50, pic 85 au lever, stabilisé 70.
    final samples = <HeartRateSample>[
      for (var s = 0; s < 180; s += 5)
        (time: Duration(seconds: s), bpm: s < 150 ? 56 : 50),
      for (var s = 180; s < 300; s += 5)
        (time: Duration(seconds: s), bpm: s < 195 ? 85 : (s < 270 ? 76 : 70)),
    ];

    test('couché, pic et stabilisé sur les bonnes fenêtres', () {
      final r = OrthostaticResult.fromSamples(
        samples,
        protocol: protocol,
        date: date,
        source: HeartRateSourceKind.bluetooth,
      )!;
      expect(r.lyingBpm, 50);
      expect(r.standingPeakBpm, 85);
      expect(r.standingStableBpm, 70);
      expect(r.delta, 20);
    });

    test('fenêtre sans mesure : pas de résultat', () {
      final partial = samples
          .where((s) => s.time < const Duration(seconds: 240))
          .toList();
      expect(
        OrthostaticResult.fromSamples(
          partial,
          protocol: protocol,
          date: date,
          source: HeartRateSourceKind.health,
        ),
        isNull,
      );
    });
  });

  test('comptage manuel : 15 s × 4', () {
    final r = OrthostaticResult.fromCounts(
      lying15s: 13,
      standingPeak15s: 21,
      standingStable15s: 18,
      date: date,
    );
    expect((r.lyingBpm, r.standingPeakBpm, r.standingStableBpm), (52, 84, 72));
    expect(r.delta, 20);
    expect(r.source, HeartRateSourceKind.manual);
  });

  group('référence personnelle', () {
    final history = [
      result(50, 70, day: 1),
      result(52, 71, day: 8),
      result(49, 68, day: 15),
      result(51, 72, day: 22),
    ];

    test('moins de 3 tests : référence en construction', () {
      final b = OrthostaticBaseline.of(history.take(2).toList());
      expect(b.statusOf(result(70, 110)), FormStatus.building);
    });

    test('dans ma normale', () {
      final b = OrthostaticBaseline.of(history);
      expect(b.meanDelta, closeTo(19.75, 1e-9));
      expect(b.statusOf(result(51, 71)), FormStatus.normal);
    });

    test('écart inhabituel POUR MOI : à surveiller', () {
      final b = OrthostaticBaseline.of(history);
      // Écart 32 alors que ma moyenne est ~20.
      expect(b.statusOf(result(50, 82)), FormStatus.watch);
    });

    test('FC couché inhabituelle : à surveiller même si l\'écart va', () {
      final b = OrthostaticBaseline.of(history);
      expect(b.statusOf(result(62, 82)), FormStatus.watch);
    });

    test('pas de seuil absolu : un écart de 30 peut être normal pour moi', () {
      final b = OrthostaticBaseline.of([
        result(45, 76, day: 1),
        result(46, 74, day: 8),
        result(44, 75, day: 15),
      ]);
      expect(b.statusOf(result(45, 75)), FormStatus.normal);
    });

    test('seuls les 8 tests les plus récents comptent', () {
      final old = [for (var d = 1; d <= 10; d++) result(40, 80, day: d)];
      final recent = [for (var d = 11; d <= 18; d++) result(50, 70, day: d)];
      final b = OrthostaticBaseline.of([...old, ...recent]);
      expect(b.count, 8);
      expect(b.meanDelta, 20);
    });
  });

  test('aller-retour JSON', () {
    final r = result(50, 70);
    final back = OrthostaticResult.fromJson(r.toJson())!;
    expect(back.delta, 20);
    expect(back.source, HeartRateSourceKind.manual);
  });
}
