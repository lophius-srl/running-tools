import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/app.dart';
import 'package:running_tools/features/home/home_entry.dart';

import '../../support/fakes.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    // Taille d'un iPhone 15 Pro.
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: fakeOverrides(), child: const RunningToolsApp()),
    );
  }

  testWidgets('l\'accueil propose les 4 tests et les 2 outils', (tester) async {
    await pumpApp(tester);
    for (final entry in HomeEntry.values) {
      await tester.scrollUntilVisible(find.text(entry.label), 100);
      expect(find.text(entry.label), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('Historique'), 100);
    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun test enregistré'), findsOneWidget);
  });

  testWidgets('Mise en place : terrain puis test, réglages pré-remplis', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Mise en place'), 100);
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
