import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/fartlek.dart';

void main() {
  const settings = FartlekSettings();

  test('même graine, mêmes réglages : même séance', () {
    final a = FartlekPlan.generate(settings, 424242);
    final b = FartlekPlan.generate(settings, 424242);
    expect(
      a.bursts.map((x) => (x.start, x.duration, x.feel)),
      b.bursts.map((x) => (x.start, x.duration, x.feel)),
    );
  });

  test('graines différentes : séances différentes', () {
    final a = FartlekPlan.generate(settings, 1);
    final b = FartlekPlan.generate(settings, 2);
    expect(
      a.bursts.map((x) => x.start).toList(),
      isNot(b.bursts.map((x) => x.start).toList()),
    );
  });

  for (final seed in [1, 7, 99, 123456, 987654]) {
    test('graine $seed : règles respectées', () {
      final plan = FartlekPlan.generate(settings, seed);
      expect(plan.bursts, isNotEmpty);
      final first = plan.bursts.first;
      // Pas de surprise pendant l'échauffement.
      expect(
        first.start - settings.warmup,
        greaterThanOrEqualTo(settings.minGap),
      );
      for (final b in plan.bursts) {
        expect(
          b.duration.inSeconds,
          inInclusiveRange(
            settings.minBurst.inSeconds,
            settings.maxBurst.inSeconds,
          ),
        );
        expect(b.duration.inSeconds % 5, 0);
        // Pas de surprise pendant le retour au calme.
        expect(b.end, lessThanOrEqualTo(settings.total - settings.cooldown));
        expect(b.feel, isNotNull);
      }
      for (var i = 1; i < plan.bursts.length; i++) {
        final gap = plan.bursts[i].start - plan.bursts[i - 1].end;
        expect(
          gap.inSeconds,
          inInclusiveRange(
            settings.minGap.inSeconds,
            settings.maxGap.inSeconds,
          ),
        );
      }
      expect(
        plan.hardTime,
        plan.bursts.fold(Duration.zero, (s, b) => s + b.duration),
      );
    });
  }

  test('en % VMA : pas d\'intensité au ressenti', () {
    final plan = FartlekPlan.generate(const FartlekSettings(percentVma: 95), 5);
    expect(plan.bursts.every((b) => b.feel == null), isTrue);
  });

  test('phases : échauffement, facile, accélération, calme, fin', () {
    final plan = FartlekPlan.generate(settings, 42);
    final b = plan.bursts.first;
    expect(plan.phaseAt(const Duration(minutes: 5)), FartlekPhase.warmup);
    expect(
      plan.phaseAt(b.start - const Duration(seconds: 1)),
      FartlekPhase.easy,
    );
    expect(plan.phaseAt(b.start), FartlekPhase.burst);
    expect(plan.burstAt(b.start), same(b));
    expect(plan.phaseAt(const Duration(minutes: 37)), FartlekPhase.cooldown);
    expect(plan.phaseAt(const Duration(minutes: 40)), FartlekPhase.done);
  });

  test('réglages invalides refusés', () {
    const bad = FartlekSettings(
      total: Duration(minutes: 10),
      warmup: Duration(minutes: 8),
      cooldown: Duration(minutes: 5),
    );
    expect(bad.isValid, isFalse);
    expect(() => FartlekPlan.generate(bad, 1), throwsArgumentError);
  });

  test('aller-retour JSON des réglages', () {
    const s = FartlekSettings(
      total: Duration(minutes: 50),
      percentVma: 92,
      minBurst: Duration(seconds: 30),
    );
    final back = FartlekSettings.fromJson(s.toJson())!;
    expect(back.total, const Duration(minutes: 50));
    expect(back.percentVma, 92);
    expect(back.minBurst, const Duration(seconds: 30));
  });
}
