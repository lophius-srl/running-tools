import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/goal/next_action.dart';
import 'package:running_tools/domain/goal/race_goal.dart';

void main() {
  final today = DateTime(2026, 11, 13);
  final goal = RaceGoal(
    id: 'g',
    name: 'Semi de Lyon',
    date: DateTime(2026, 12, 20),
    distanceM: 21097.5,
  );
  final freshVma = DateTime(2026, 11, 1);

  NextActionKind kind({
    RaceGoal? g,
    GoalPhase? phase,
    DateTime? vma,
    DateTime? ortho,
    ({int done, int total})? checklist,
  }) => nextAction(
    ActionContext(
      today: today,
      goal: g,
      phase: phase,
      vmaDate: vma,
      lastOrthostatic: ortho,
      checklist: checklist,
    ),
  ).kind;

  test('pas de VMA : un test, avant tout', () {
    expect(kind(g: goal, phase: GoalPhase.train), NextActionKind.testVma);
  });

  test('VMA ancienne : la refaire ; titre avec les semaines', () {
    final a = nextAction(
      ActionContext(
        today: today,
        goal: goal,
        phase: GoalPhase.evaluate,
        vmaDate: DateTime(2026, 9, 11),
        lastOrthostatic: today,
      ),
    );
    expect(a.kind, NextActionKind.testVma);
    expect(a.title, 'Ta VMA date de 9 semaines');
  });

  test('sans objectif : en fixer un', () {
    expect(kind(vma: freshVma), NextActionKind.setGoal);
  });

  test('pas de mesure de forme depuis 7 jours, sinon la séance', () {
    expect(
      kind(g: goal, phase: GoalPhase.train, vma: freshVma),
      NextActionKind.orthostatic,
    );
    expect(
      kind(
        g: goal,
        phase: GoalPhase.train,
        vma: freshVma,
        ortho: DateTime(2026, 11, 10),
      ),
      NextActionKind.workout,
    );
  });

  test('Jour J : la checklist, puis le plan de course', () {
    final soon = goal.copyWith(date: DateTime(2026, 11, 15));
    final a = nextAction(
      ActionContext(
        today: today,
        goal: soon,
        phase: GoalPhase.raceDay,
        vmaDate: DateTime(2026, 8, 1),
        checklist: (done: 3, total: 12),
      ),
    );
    expect(a.kind, NextActionKind.checklist);
    expect(a.title, 'Course dans 2 jours : ta checklist');
    expect(a.detail, '3 sur 12 déjà prêts.');
    expect(
      kind(
        g: soon,
        phase: GoalPhase.raceDay,
        vma: freshVma,
        checklist: (done: 12, total: 12),
      ),
      NextActionKind.racePlan,
    );
  });

  test('après la course : le débrief, puis un nouvel objectif', () {
    final past = goal.copyWith(date: DateTime(2026, 11, 9));
    expect(
      kind(g: past, phase: GoalPhase.analyze, vma: freshVma),
      NextActionKind.debrief,
    );
    expect(
      kind(
        g: past.copyWith(debriefId: () => 'd1'),
        phase: GoalPhase.analyze,
        vma: freshVma,
      ),
      NextActionKind.newGoal,
    );
  });
}
