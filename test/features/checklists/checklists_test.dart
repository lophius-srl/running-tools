import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/checklist.dart';
import 'package:running_tools/features/checklists/checklists_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeChecklistRepository repo;
  late FakeReminderScheduler reminders;

  setUp(() {
    repo = FakeChecklistRepository();
    reminders = FakeReminderScheduler();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(checklists: repo, reminders: reminders),
        child: const MaterialApp(home: ChecklistsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('créer une course depuis le modèle Trail, avec rappel', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Trail'), findsOneWidget);
    await tester.tap(find.text('Nouvelle course'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nom de la course'),
      'Trail des Crêtes',
    );
    await tester.tap(find.text('Course sur route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trail').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer la checklist'));
    await tester.pumpAndSettle();

    final race = repo.raceList.single;
    expect(race.raceName, 'Trail des Crêtes');
    expect(race.items.where((i) => i.mandatory), hasLength(8));
    expect(find.text('0/12 prêts'), findsOneWidget);
    expect(
      find.text('8 élément(s) obligatoire(s) manquant(s)'),
      findsOneWidget,
    );

    // Rappel la veille à 20 h.
    final scheduled = reminders.scheduled[reminderNotificationId(race.id)]!;
    expect(scheduled.payload, race.id);
    final eve = race.raceDate.subtract(const Duration(days: 1));
    expect(scheduled.at, DateTime(eve.year, eve.month, eve.day, 20));
  });

  testWidgets('cocher, ajouter, tout décocher, supprimer', (tester) async {
    repo.raceList.add(
      RaceChecklist.fromTemplate(
        builtInTemplates[2],
        id: 'r1',
        raceName: 'Test VMA',
        raceDate: DateTime.now().add(const Duration(days: 3)),
        reminder: (hour: 20, minute: 0),
      ),
    );
    await pumpPage(tester);
    expect(find.text('0/7'), findsOneWidget);
    await tester.tap(find.text('Test VMA'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Décamètre'));
    await tester.tap(find.text('Eau'));
    await tester.pumpAndSettle();
    expect(find.text('2/7 prêts'), findsOneWidget);

    await scrollTo(
      tester,
      find.widgetWithText(TextField, 'Ajouter un élément'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ajouter un élément'),
      'Bandeau',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.raceList.single.items.last.label, 'Bandeau');

    await scrollTo(tester, find.text('Tout décocher'));
    await tester.tap(find.text('Tout décocher'));
    await tester.pumpAndSettle();
    expect(repo.raceList.single.checkedCount, 0);

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(repo.raceList, isEmpty);
    expect(reminders.scheduled, isEmpty);
  });

  testWidgets('dupliquer un modèle fourni en modèle perso', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Sortie longue'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Supprimer'), findsNothing);
    await tester.tap(find.text('Enregistrer comme mon modèle'));
    await tester.pumpAndSettle();
    expect(repo.customTemplates.single.name, 'Sortie longue (perso)');
    expect(find.text('Sortie longue (perso)'), findsOneWidget);
  });

  testWidgets('notifications refusées : message, checklist créée', (
    tester,
  ) async {
    reminders.granted = false;
    await pumpPage(tester);
    await tester.tap(find.text('Nouvelle course'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nom de la course'),
      '10 km',
    );
    await tester.pump();
    await tester.tap(find.text('Créer la checklist'));
    await tester.pumpAndSettle();
    expect(repo.raceList, hasLength(1));
    expect(
      find.text('Rappel non programmé : notifications refusées.'),
      findsOneWidget,
    );
  });
}
