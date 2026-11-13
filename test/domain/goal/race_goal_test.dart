import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/goal/race_goal.dart';

void main() {
  final goal = RaceGoal(
    id: 'g',
    name: 'Semi de Lyon',
    date: DateTime(2026, 12, 20, 9),
    distanceM: 21097.5,
    targetTime: const Duration(hours: 1, minutes: 45),
  );

  group('phase', () {
    GoalPhase at(DateTime day, {bool needs = false}) =>
        phaseOf(goal, day, needsEvaluation: needs);

    test('loin de la course : S’entraîner, ou Évaluer si VMA à refaire', () {
      expect(at(DateTime(2026, 11, 13)), GoalPhase.train);
      expect(at(DateTime(2026, 11, 13), needs: true), GoalPhase.evaluate);
      expect(at(DateTime(2026, 12, 17, 23)), GoalPhase.train);
    });

    test('Jour J de J-2 au jour de la course, même si VMA ancienne', () {
      expect(at(DateTime(2026, 12, 18, 6)), GoalPhase.raceDay);
      expect(at(DateTime(2026, 12, 20, 23), needs: true), GoalPhase.raceDay);
    });

    test('Analyser dès le lendemain', () {
      expect(at(DateTime(2026, 12, 21)), GoalPhase.analyze);
      expect(at(DateTime(2027, 2, 1)), GoalPhase.analyze);
    });
  });

  test('compte à rebours', () {
    expect(countdownText(goal, DateTime(2026, 11, 16, 22)), 'J-34');
    expect(countdownText(goal, DateTime(2026, 12, 20)), 'Jour J');
    expect(countdownText(goal, DateTime(2026, 12, 22)), 'J+2');
  });

  test('allure et vitesse visées', () {
    // 1 h 45 sur semi : 4'59/km, 12,06 km/h.
    expect(goal.targetPace!.inSeconds, 299);
    expect(targetPaceText(goal), '4:59/km');
    expect(goal.targetKmh, closeTo(12.06, 0.01));
    final noTarget = goal.copyWith(targetTime: () => null);
    expect(noTarget.targetPace, isNull);
  });

  test('aller-retour JSON', () {
    final g = goal.copyWith(courseId: () => 'course-1', archived: true);
    final back = RaceGoal.fromJson(g.toJson())!;
    expect(back.name, 'Semi de Lyon');
    expect(back.targetTime, const Duration(hours: 1, minutes: 45));
    expect(back.courseId, 'course-1');
    expect(back.archived, isTrue);
    expect(back.debriefId, isNull);
  });
}
