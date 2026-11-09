import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/workout.dart';
import 'package:running_tools/domain/workout_library.dart';
import 'package:running_tools/domain/workout_plan.dart';

Workout byId(String id) => workoutLibrary.firstWhere((w) => w.id == id);

void main() {
  test('8 × 400 m à 100 % pour VMA 15, couloir 1', () {
    final plan = WorkoutPlan.compute(
      byId('lib-8x400'),
      vmaKmh: 15,
      markerSpacingM: 20,
    );
    final efforts = plan.efforts.toList();
    expect(efforts, hasLength(8));
    expect(efforts.first.duration, const Duration(seconds: 96));
    expect(efforts.first.markerSplits, hasLength(20));
    expect(
      efforts.first.markerSplits.first,
      const Duration(milliseconds: 4800),
    );
    expect(efforts.first.markerSplits.last, const Duration(seconds: 96));
    expect(efforts.first.lapTime, const Duration(seconds: 96));
    // 8 × 96 s + 7 récupérations de 90 s (pas après la dernière).
    expect(plan.totalDuration, const Duration(seconds: 8 * 96 + 7 * 90));
    expect(plan.steps.last, isA<EffortStep>());
  });

  test('couloir 3 : temps allongés de 414,70 / 400', () {
    final plan = WorkoutPlan.compute(
      byId('lib-8x400'),
      vmaKmh: 15,
      markerSpacingM: 20,
      lane: 3,
    );
    expect(
      plan.efforts.first.duration.inMilliseconds / 1000,
      closeTo(414.70 / (15 / 3.6), 0.01),
    );
  });

  test('30/30 : distance estimée pour 30 s à 100 % de 15 km/h', () {
    final plan = WorkoutPlan.compute(
      byId('lib-30-30'),
      vmaKmh: 15,
      markerSpacingM: 20,
    );
    final first = plan.efforts.first;
    expect(first.duration, const Duration(seconds: 30));
    expect(first.distanceM, closeTo(125, 1e-9));
    expect(first.markerSplits, isEmpty);
    expect(plan.totalDuration, const Duration(seconds: 10 * 30 + 9 * 30));
  });

  test('côtes : pas d\'allure cible', () {
    final plan = WorkoutPlan.compute(
      byId('lib-cotes'),
      vmaKmh: 15,
      markerSpacingM: 20,
    );
    expect(plan.efforts.first.speedKmh, isNull);
    expect(plan.efforts.first.distanceM, isNull);
    expect(plan.efforts.first.lapTime, isNull);
  });

  test('récupération en distance : trot à 50 % VMA', () {
    const workout = Workout(
      id: 'x',
      name: 'x',
      sets: [
        WorkoutSet(
          reps: 2,
          effort: Effort.distance(400, percentVma: 100),
          recovery: Recovery.distance(200),
        ),
      ],
    );
    final plan = WorkoutPlan.compute(workout, vmaKmh: 15, markerSpacingM: 20);
    final rest = plan.steps.whereType<RecoveryStep>().single;
    expect(rest.duration, const Duration(seconds: 96)); // 200 m à 7,5 km/h
  });

  test('étape en cours selon le temps écoulé', () {
    final plan = WorkoutPlan.compute(
      byId('lib-8x400'),
      vmaKmh: 15,
      markerSpacingM: 20,
    );
    expect((plan.stepAt(const Duration(seconds: 10))! as EffortStep).index, 1);
    expect(plan.stepAt(const Duration(seconds: 100)), isA<RecoveryStep>());
    expect((plan.stepAt(const Duration(seconds: 190))! as EffortStep).index, 2);
    expect(plan.stepAt(plan.totalDuration), isNull);
  });

  test('VMA ou espacement invalides refusés', () {
    expect(
      () =>
          WorkoutPlan.compute(byId('lib-8x400'), vmaKmh: 0, markerSpacingM: 20),
      throwsArgumentError,
    );
    expect(
      () =>
          WorkoutPlan.compute(byId('lib-8x400'), vmaKmh: 15, markerSpacingM: 0),
      throwsArgumentError,
    );
  });
}
