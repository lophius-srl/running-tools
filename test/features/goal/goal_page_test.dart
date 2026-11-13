import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/goal/race_goal.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/goal/goal_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeGoalRepository goals;
  late FakeHistoryRepository history;

  setUp(() {
    goals = FakeGoalRepository();
    history = FakeHistoryRepository()
      ..records.add(
        TestRecord(
          id: 't',
          date: DateTime.now().subtract(const Duration(days: 7)),
          kind: TestKind.vameval,
          vmaKmh: 15,
          vo2max: 52.5,
        ),
      );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(goals: goals, history: history),
        child: const MaterialApp(home: GoalPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mode libre, puis objectif créé : compte à rebours, étape', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('mode libre'), findsOneWidget);
    await tester.tap(find.text('Fixer un objectif'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goal-name')), 'Semi de Lyon');
    await tester.tap(find.text('Semi'));
    await tester.enterText(find.byKey(const Key('goal-target')), '1:45:00');
    await tester.pump();
    expect(find.text('Allure 4:59/km'), findsOneWidget);
    // Pas de date : pas d'enregistrement possible.
    final save = find.widgetWithText(FilledButton, 'Enregistrer');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('Choisir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final goal = goals.goals.single;
    expect(goal.name, 'Semi de Lyon');
    expect(goal.distanceM, 21097.5);
    expect(goal.targetTime, const Duration(hours: 1, minutes: 45));
    expect(find.text('Semi de Lyon'), findsOneWidget);
    expect(find.text('Étape : S’entraîner'), findsOneWidget);
    expect(find.textContaining('J-'), findsOneWidget);
  });

  testWidgets('course dans 2 jours : étape Course ; archiver', (tester) async {
    goals.goals.add(
      RaceGoal(
        id: 'g',
        name: '10 km de Paris',
        date: DateTime.now().add(const Duration(days: 2)),
        distanceM: 10000,
      ),
    );
    await pump(tester);
    expect(find.text('Étape : Course'), findsOneWidget);
    expect(find.text('J-2'), findsOneWidget);
    await tester.tap(find.textContaining('Archiver'));
    await tester.pumpAndSettle();
    expect(goals.goals.single.archived, isTrue);
    expect(find.textContaining('mode libre'), findsOneWidget);
    expect(find.text('Objectifs passés'), findsOneWidget);
  });

  testWidgets('VMA ancienne : étape Évaluer', (tester) async {
    history.records
      ..clear()
      ..add(
        TestRecord(
          id: 't',
          date: DateTime.now().subtract(const Duration(days: 80)),
          kind: TestKind.cooper,
          vmaKmh: 15,
          vo2max: 52.5,
        ),
      );
    goals.goals.add(
      RaceGoal(
        id: 'g',
        name: 'Marathon',
        date: DateTime.now().add(const Duration(days: 90)),
        distanceM: 42195,
      ),
    );
    await pump(tester);
    expect(find.text('Étape : Évaluer'), findsOneWidget);
  });
}
