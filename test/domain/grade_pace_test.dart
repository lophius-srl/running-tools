import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/course_profile.dart';
import 'package:running_tools/domain/grade_pace.dart';

CourseProfile profile(double Function(double d) ele, double lengthM) =>
    CourseProfile(
      name: 'test',
      elevations: [
        for (var d = 0.0; d <= lengthM; d += CourseProfile.stepM) ele(d),
      ],
    );

void main() {
  test('modèle de pente : plat = 1, montée plus lente, descente un peu', () {
    expect(gradePaceFactor(0), 1);
    expect(minettiCost(0), 3.6);
    // +5 % : ~ +29 % (Minetti) ; −5 % : ~ −8 %.
    expect(gradePaceFactor(0.05), closeTo(1.29, 0.02));
    expect(gradePaceFactor(-0.05), closeTo(0.92, 0.01));
    // Au-delà de −10 %, plus de gain.
    expect(gradePaceFactor(-0.20), gradePaceFactor(-0.10));
    // Monotone en montée.
    for (var g = 0.0; g < 0.3; g += 0.01) {
      expect(gradePaceFactor(g + 0.01), greaterThan(gradePaceFactor(g)));
    }
  });

  test('parcours plat : allure de base partout', () {
    final p = profile((_) => 100, 10000);
    final plan = CoursePlan.fromFlatPace(
      p,
      splitSections(p),
      const Duration(minutes: 5),
    );
    expect(plan.totalS, closeTo(3000, 1e-6));
    expect(plan.paced.single.pace, const Duration(minutes: 5));
    expect(plan.paceBand.first.$1, 1);
    expect(plan.paceBand.first.$2, closeTo(300, 1e-6));
    expect(plan.paceBand.last.$1, 10);
  });

  test('objectif de temps tenu, montée plus lente que la descente', () {
    double hill(double d) {
      if (d <= 2000) return 200;
      if (d <= 3000) return 200 + (d - 2000) * 0.06;
      if (d <= 4000) return 260 - (d - 3000) * 0.06;
      return 200;
    }

    final p = profile(hill, 5000);
    final plan = CoursePlan.fromTarget(
      p,
      splitSections(p),
      const Duration(minutes: 25),
    );
    expect(plan.totalS, closeTo(1500, 1e-6));
    expect(plan.paced.last.splitS, closeTo(1500, 1e-6));
    final [flat, climb, descent, _] = plan.paced;
    expect(climb.pace, greaterThan(flat.pace));
    expect(descent.pace, lessThan(flat.pace));
    expect(climb.gain, closeTo(60, 2));
    // La base sur le plat est plus rapide que 5:00/km (les bosses coûtent).
    expect(plan.flatPace, lessThan(const Duration(minutes: 5)));
  });

  test('temps de passage croissants', () {
    final p = profile((d) => 100 + 20 * sin(d / 500), 8000);
    final plan = CoursePlan.fromFlatPace(
      p,
      splitSections(p),
      const Duration(minutes: 4, seconds: 30),
    );
    final band = plan.paceBand;
    for (var i = 1; i < band.length; i++) {
      expect(band[i].$2, greaterThan(band[i - 1].$2));
    }
  });
}
