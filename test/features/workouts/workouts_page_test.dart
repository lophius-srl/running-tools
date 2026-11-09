import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/domain/workout.dart';
import 'package:running_tools/features/workouts/workouts_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeWorkoutRepository workouts;
  late FakeHistoryRepository history;

  setUp(() {
    workouts = FakeWorkoutRepository();
    history = FakeHistoryRepository()
      ..records.add(
        TestRecord(
          id: 'h',
          date: DateTime(2026, 11, 2),
          kind: TestKind.vameval,
          vmaKmh: 16,
          vo2max: 56,
        ),
      );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(workouts: workouts, history: history),
        child: const MaterialApp(home: WorkoutsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openWorkout(WidgetTester tester, String name) async {
    await tester.scrollUntilVisible(
      find.text(name),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('bibliothèque affichée avec les résumés', (tester) async {
    await pumpPage(tester);
    expect(find.text('30/30'), findsOneWidget);
    expect(find.text('8 × 400 m à 100 %'), findsOneWidget);
    expect(find.text('Mes séances'), findsNothing);
  });

  testWidgets('détail : plan calculé avec la VMA du dernier test', (
    tester,
  ) async {
    await pumpPage(tester);
    await openWorkout(tester, '8 × 400 m');
    expect(find.text('16'), findsOneWidget);
    // 400 m à 16 km/h : 1:30,0, soit 3:45 /km.
    expect(find.text('1:30,0 · 3:45 /km'), findsWidgets);
    expect(find.text('Lièvre sonore (bip à chaque repère)'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Couloir 4'));
    await tester.pump();
    expect(find.text('1:30,0 · 3:45 /km'), findsNothing);
    expect(find.text('1:35,0 · 3:45 /km'), findsWidgets);
  });

  testWidgets('dupliquer puis retrouver dans « Mes séances »', (tester) async {
    await pumpPage(tester);
    await openWorkout(tester, '30/30');
    await tester.tap(find.byTooltip('Dupliquer'));
    await tester.pumpAndSettle();
    expect(find.text('30/30 (copie)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Enregistrer'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(workouts.workouts.single.name, '30/30 (copie)');
    expect(workouts.workouts.single.id, startsWith('perso-'));
    expect(find.text('Mes séances'), findsOneWidget);
  });

  testWidgets('séance perso : modifier et supprimer', (tester) async {
    workouts.workouts.add(
      const Workout(
        id: 'perso-1',
        name: 'Mes 300',
        sets: [
          WorkoutSet(reps: 6, effort: Effort.distance(300, percentVma: 100)),
        ],
      ),
    );
    await pumpPage(tester);
    await openWorkout(tester, 'Mes 300');
    expect(find.byTooltip('Modifier'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(workouts.workouts, isEmpty);
    expect(find.text('Mes séances'), findsNothing);
  });

  testWidgets('séance de la bibliothèque : ni modifiable ni supprimable', (
    tester,
  ) async {
    await pumpPage(tester);
    await openWorkout(tester, '45/15');
    expect(find.textContaining('Lièvre sonore'), findsNothing);
    expect(find.byTooltip('Modifier'), findsNothing);
    expect(find.byTooltip('Supprimer'), findsNothing);
  });

  testWidgets('créer une séance depuis zéro', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Mes 600');
    await tester.enterText(find.widgetWithText(TextField, 'Distance'), '600');
    await tester.enterText(find.widgetWithText(TextField, '% VMA'), '95');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Enregistrer'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final saved = workouts.workouts.single;
    expect(saved.name, 'Mes 600');
    expect(saved.sets.single.reps, 6);
    expect(saved.sets.single.effort.distanceM, 600);
    expect(saved.sets.single.effort.percentVma, 95);
    expect(find.text('Mes 600'), findsOneWidget);
  });

  testWidgets('éditeur : distance sans % VMA refusée', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '% VMA'), '');
    await tester.pump();
    expect(find.textContaining('a besoin d’un % VMA'), findsOneWidget);
  });
}
