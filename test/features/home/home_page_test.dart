import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/app.dart';
import 'package:running_tools/domain/checklist.dart';
import 'package:running_tools/domain/orthostatic.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/home/home_entry.dart';

import '../../support/fakes.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    FakeHistoryRepository? history,
    FakeOrthostaticRepository? orthostatic,
    FakeChecklistRepository? checklists,
  }) async {
    // Taille d'un iPhone 15 Pro.
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          history: history,
          orthostatic: orthostatic,
          checklists: checklists,
        ),
        child: const RunningToolsApp(),
      ),
    );
  }

  Future<void> openTab(WidgetTester tester, HomeTab tab) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(tab.label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chaque entrée est dans un onglet, et s\'y affiche', (
    tester,
  ) async {
    final all = [for (final t in HomeTab.values) ...t.entries];
    expect(all.toSet(), HomeEntry.values.toSet());
    expect(all, hasLength(HomeEntry.values.length), reason: 'sans doublon');
    await pumpApp(tester);
    for (final tab in HomeTab.values) {
      await openTab(tester, tab);
      for (final entry in tab.entries) {
        await tester.scrollUntilVisible(
          find.text(entry.label),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(entry.label), findsOneWidget, reason: entry.label);
      }
    }
  });

  testWidgets('un appui ouvre l\'écran correspondant', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(find.text('VAMEVAL'), 100);
    await tester.tap(find.text('VAMEVAL'));
    await tester.pumpAndSettle();

    expect(find.text('Réglages du test'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('VAMEVAL'), findsOneWidget);
  });

  testWidgets('Cooper ouvre directement le chrono', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Cooper'));
    await tester.pumpAndSettle();
    expect(find.text('Départ dans 10 s'), findsOneWidget);
  });

  testWidgets('Historique ouvre la liste des tests', (tester) async {
    await pumpApp(tester);
    await openTab(tester, HomeTab.me);
    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun test enregistré'), findsOneWidget);
  });

  testWidgets('Mise en place : terrain puis test, réglages pré-remplis', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Mise en place'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mise en place'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terrain normé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rugby'));
    await tester.pumpAndSettle();

    expect(
      find.text('Repères tous les 22 m : pour quel test ?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Navette Luc Léger'));
    await tester.pumpAndSettle();

    expect(find.text('Réglages du test'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
  });

  testWidgets('résumé : VMA, forme, prochaine course', (tester) async {
    final now = DateTime.now();
    final history = FakeHistoryRepository()
      ..records.add(
        TestRecord(
          id: 't1',
          date: now.subtract(const Duration(days: 12)),
          kind: TestKind.vameval,
          vmaKmh: 16.5,
          vo2max: 57.75,
        ),
      );
    final orthostatic = FakeOrthostaticRepository()
      ..results.add(
        OrthostaticResult(
          date: now,
          lyingBpm: 50,
          standingPeakBpm: 85,
          standingStableBpm: 70,
          source: HeartRateSourceKind.manual,
        ),
      );
    final checklists = FakeChecklistRepository()
      ..raceList.add(
        RaceChecklist(
          id: 'r1',
          raceName: 'Semi de Lyon',
          raceDate: now.add(const Duration(days: 9)),
          items: const [
            ChecklistItem(label: 'Dossard', checked: true),
            ChecklistItem(label: 'Gel'),
          ],
        ),
      );
    await pumpApp(
      tester,
      history: history,
      orthostatic: orthostatic,
      checklists: checklists,
    );
    await tester.pumpAndSettle();
    expect(find.text('VMA 16,5 km/h · il y a 12 j'), findsOneWidget);
    expect(find.text('Forme : référence en cours'), findsOneWidget);

    await openTab(tester, HomeTab.raceDay);
    expect(find.text('Semi de Lyon'), findsOneWidget);
    expect(find.text('Prochaine course · dans 9 j'), findsOneWidget);
    expect(find.text('Checklist : 1/2'), findsOneWidget);

    await openTab(tester, HomeTab.me);
    expect(find.text('Dernière VMA'), findsOneWidget);
    expect(find.text('16,5 km/h'), findsOneWidget);
    expect(find.text('+20 bpm'), findsOneWidget);
  });

  testWidgets('sans données : invitation à faire un test', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('Pas encore de VMA'), findsOneWidget);
    expect(find.textContaining('Prochaine course'), findsNothing);
  });
}
