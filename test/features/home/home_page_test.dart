import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/app.dart';
import 'package:running_tools/domain/debrief/debrief_summary.dart';
import 'package:running_tools/domain/debrief/session_type.dart';
import 'package:running_tools/domain/goal/race_goal.dart';
import 'package:running_tools/domain/orthostatic.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/home/home_entry.dart';

import '../../support/fakes.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    FakeHistoryRepository? history,
    FakeOrthostaticRepository? orthostatic,
    FakeGoalRepository? goals,
    FakeDebriefRepository? debriefs,
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
          goals: goals,
          debriefs: debriefs,
        ),
        child: const RunningToolsApp(),
      ),
    );
    await tester.pumpAndSettle();
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

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  TestRecord vameval(int daysAgo, double vma) => TestRecord(
    id: 't',
    date: DateTime.now().subtract(Duration(days: daysAgo)),
    kind: TestKind.vameval,
    vmaKmh: vma,
    vo2max: vma * 3.5,
  );

  testWidgets('chaque écran a sa place, une seule fois, et s’y affiche', (
    tester,
  ) async {
    final all = [
      for (final s in JourneyStage.values) ...s.entries,
      ...HomeTab.meEntries,
      ...HomeTab.toolbox,
    ];
    expect(all.toSet(), HomeEntry.values.toSet());
    expect(all, hasLength(HomeEntry.values.length), reason: 'sans doublon');

    await pumpApp(tester);
    await openTab(tester, HomeTab.journey);
    for (final stage in JourneyStage.values) {
      for (final entry in stage.entries) {
        await scrollTo(tester, find.text(entry.label));
        expect(find.text(entry.label), findsOneWidget, reason: entry.label);
      }
    }
    await openTab(tester, HomeTab.me);
    for (final entry in HomeTab.toolbox) {
      await scrollTo(tester, find.text(entry.label));
      expect(find.text(entry.label), findsOneWidget, reason: entry.label);
    }
  });

  testWidgets('mode libre : prochaine action « test de VMA » → le parcours', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Pas encore d’objectif'), findsOneWidget);
    expect(find.text('Fais un test de VMA'), findsOneWidget);
    await tester.tap(find.text('Fais un test de VMA'));
    await tester.pumpAndSettle();
    expect(find.text('Ma prépa'), findsWidgets);
    expect(find.text('Tu es ici'), findsOneWidget);
    expect(find.text('Où j’en suis ?'), findsOneWidget);
  });

  testWidgets('tableau de bord : chiffres, objectif, zones, forme, débrief', (
    tester,
  ) async {
    final now = DateTime.now();
    await pumpApp(
      tester,
      history: FakeHistoryRepository()..records.add(vameval(12, 15.5)),
      orthostatic: FakeOrthostaticRepository()
        ..results.add(
          OrthostaticResult(
            date: now,
            lyingBpm: 52,
            standingPeakBpm: 85,
            standingStableBpm: 72,
            source: HeartRateSourceKind.manual,
          ),
        ),
      goals: FakeGoalRepository()
        ..goals.add(
          RaceGoal(
            id: 'g',
            name: 'Semi de Lyon',
            date: now.add(const Duration(days: 34)),
            distanceM: 21097.5,
            targetTime: const Duration(hours: 1, minutes: 35),
          ),
        ),
      debriefs: FakeDebriefRepository()
        ..debriefs.add(
          DebriefSummary(
            id: 'd',
            date: now.subtract(const Duration(days: 2)),
            name: 'Sortie longue',
            type: SessionType.long,
            distanceM: 16000,
            movingS: 5400,
            score: 82,
            findings: const ['Tu es parti trop vite.'],
          ),
        ),
    );
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('15,5 km/h'), findsOneWidget);
    expect(find.text('52 bpm'), findsOneWidget);
    expect(find.text('Semi de Lyon'), findsOneWidget);
    expect(find.text('J-34'), findsOneWidget);
    expect(find.text('Séance du jour'), findsOneWidget);
    await scrollTo(tester, find.text('Mes zones'));
    expect(find.text('Allure objectif 4:30/km'), findsOneWidget);
    await scrollTo(tester, find.text('Dernier débrief'));
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Tu es parti trop vite.'), findsOneWidget);
  });

  testWidgets('un appui ouvre l’écran correspondant', (tester) async {
    await pumpApp(tester);
    await openTab(tester, HomeTab.journey);
    await tester.tap(find.text('VAMEVAL'));
    await tester.pumpAndSettle();
    expect(find.text('Réglages du test'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('VAMEVAL'), findsOneWidget);
  });

  testWidgets('Cooper ouvre directement le chrono', (tester) async {
    await pumpApp(tester);
    await openTab(tester, HomeTab.journey);
    await tester.tap(find.text('Cooper'));
    await tester.pumpAndSettle();
    expect(find.text('Départ dans 10 s'), findsOneWidget);
  });

  testWidgets('Moi > Mes résultats ouvre l’historique', (tester) async {
    await pumpApp(tester);
    await openTab(tester, HomeTab.me);
    await tester.tap(find.text('Mes résultats'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun test enregistré'), findsOneWidget);
  });

  testWidgets('Mise en place : terrain puis test, réglages pré-remplis', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, HomeTab.journey);
    await scrollTo(tester, find.text('Mise en place'));
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
}
