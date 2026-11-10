import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/debrief/debrief_summary.dart';
import 'package:running_tools/domain/debrief/session_type.dart';
import 'package:running_tools/domain/gps_tracker.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/common/gpx_picker.dart';
import 'package:running_tools/features/debrief/debriefs_page.dart';

import '../../fixtures/activities.dart';
import '../../support/fakes.dart';

/// Fait défiler jusqu'à la section [title], puis l'ouvre.
Future<void> openTile(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    ({String name, Uint8List bytes}) file, {
    FakeHistoryRepository? history,
    FakePreferencesRepository? preferences,
    FakeDebriefRepository? debriefs,
  }) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(
            history: history,
            preferences: preferences,
            debriefs: debriefs,
          ),
          activityFilePickerProvider.overrideWithValue(() async => file),
        ],
        child: const MaterialApp(home: DebriefsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importer une sortie (GPX ou FIT)'));
    await tester.pumpAndSettle();
  }

  testWidgets('GPX Strava : résumé lu, pause, données, type modifiable', (
    tester,
  ) async {
    final gpx = toGpx(easyRun(pauseS: 60));
    await pumpPage(tester, (
      name: 'footing.gpx',
      bytes: Uint8List.fromList(utf8.encode(gpx)),
    ));
    expect(find.text('Footing du dimanche'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4,99 km'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('4,99 km'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sortie longue'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Type détecté : Endurance. Corrige si besoin.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Sortie longue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sortie longue'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Sortie longue'),
    );
    expect(chip.selected, isTrue);
    await tester.scrollUntilVisible(
      find.text('Données de la sortie'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('1 pause retirée'), findsOneWidget);
  });

  testWidgets('FIT sans FC : analyses cardio annoncées masquées', (
    tester,
  ) async {
    await pumpPage(tester, (
      name: 'garmin.fit',
      bytes: toFit(easyRun(km: 2, withHeartRate: false)),
    ));
    expect(find.text('garmin'), findsOneWidget);
    await openTile(tester, 'Données de la sortie');
    await tester.scrollUntilVisible(
      find.text('Les analyses qui en dépendent seront masquées.'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Les analyses qui en dépendent seront masquées.'),
      findsOneWidget,
    );
  });

  testWidgets('fichier illisible : message', (tester) async {
    await pumpPage(tester, (
      name: 'x.gpx',
      bytes: Uint8List.fromList(utf8.encode('pas un gpx')),
    ));
    expect(find.text('Fichier GPX illisible.'), findsOneWidget);
  });

  testWidgets('analyses : allure, relief et VMA', (tester) async {
    final history = FakeHistoryRepository()
      ..records.add(
        TestRecord(
          id: 't',
          date: DateTime(2026, 10, 1),
          kind: TestKind.vameval,
          vmaKmh: 16,
          vo2max: 56,
        ),
      );
    final gpx = toGpx(
      scriptedRun(
        km: 8,
        kmhAt: (d) => d < 3000 ? 13 : 11,
        elevationAt: hillAt,
        hrAt: (d, s) => d > 2000 && d < 3000 ? 178 : 150,
      ),
    );
    await pumpPage(tester, (
      name: 'sortie.gpx',
      bytes: Uint8List.fromList(utf8.encode(gpx)),
    ), history: history);
    // En bref, en haut : les constats les plus importants.
    expect(find.text('En bref'), findsOneWidget);
    expect(find.textContaining('Tu es parti trop vite'), findsOneWidget);
    expect(find.textContaining('tu aurais pu gagner environ'), findsOneWidget);

    await openTile(tester, 'Les côtes');
    await tester.scrollUntilVisible(
      find.textContaining('FC max 178'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('FC max 178'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('de ta VMA (16 km/h)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('de ta VMA (16 km/h)'), findsOneWidget);
  });

  testWidgets('sans test de VMA : invitation', (tester) async {
    final gpx = toGpx(scriptedRun(km: 3, kmhAt: (_) => 11));
    await pumpPage(tester, (
      name: 's.gpx',
      bytes: Uint8List.fromList(utf8.encode(gpx)),
    ));
    await tester.scrollUntilVisible(
      find.text('Ton intensité'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Fais un test de VMA pour comparer ta sortie.'),
      findsOneWidget,
    );
  });

  testWidgets('cardio : dérive, cadence, FC max retenue', (tester) async {
    final prefs = FakePreferencesRepository();
    final gpx = toGpx(
      scriptedRun(
        km: 11,
        kmhAt: (_) => 11,
        hrAt: (d, s) => 145 + (s > 600 ? (s - 600) ~/ 150 : 0) + s % 3,
        cadAt: (d, s) => s > 2900 ? 81 : 85,
      ),
    );
    await pumpPage(tester, (
      name: 'heure.gpx',
      bytes: Uint8List.fromList(utf8.encode(gpx)),
    ), preferences: prefs);
    expect(find.textContaining('Ton cœur a dérivé'), findsOneWidget);
    expect(prefs.maxHr, inInclusiveRange(165, 175));
    await tester.scrollUntilVisible(
      find.text('Ta foulée'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('elle a baissé de'), findsOneWidget);
  });

  testWidgets('FC peu fiable : réserve affichée, FC max non retenue', (
    tester,
  ) async {
    final prefs = FakePreferencesRepository();
    final gpx = toGpx(
      scriptedRun(
        km: 11,
        kmhAt: (_) => 11,
        hrAt: (d, s) => s % 40 < 20 ? 140 : 182,
        cadAt: (d, s) => 85,
      ),
    );
    await pumpPage(tester, (
      name: 'optique.gpx',
      bytes: Uint8List.fromList(utf8.encode(gpx)),
    ), preferences: prefs);
    expect(
      find.text('FC peu fiable sur cette sortie : pas de conclusion cardio.'),
      findsWidgets,
    );
    expect(find.textContaining('Ton cœur a dérivé'), findsNothing);
    expect(prefs.maxHr, isNull);
  });

  testWidgets('note en haut, graphique, débrief gardé et mis à jour', (
    tester,
  ) async {
    final debriefs = FakeDebriefRepository();
    final gpx = toGpx(
      scriptedRun(
        km: 8,
        kmhAt: (d) => d < 3000 ? 13 : 11,
        elevationAt: hillAt,
        hrAt: (d, s) => d > 2000 && d < 3000 ? 178 : 150,
      ),
    );
    await pumpPage(tester, (
      name: 'sortie.gpx',
      bytes: Uint8List.fromList(utf8.encode(gpx)),
    ), debriefs: debriefs);
    expect(find.text('/ 100'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fréquence cardiaque (bpm)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Altitude (m)'), findsOneWidget);
    expect(find.text('Allure (/km)'), findsOneWidget);
    expect(find.text('Fréquence cardiaque (bpm)'), findsOneWidget);
    final saved = debriefs.debriefs.single;
    expect(saved.type, SessionType.endurance);
    expect(saved.findings, isNotEmpty);
    expect(saved.gainableS, greaterThan(0));

    await tester.scrollUntilVisible(
      find.text('Course'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Course'));
    await tester.pumpAndSettle();
    expect(debriefs.debriefs.single.type, SessionType.race);

    // Retour à la liste : le débrief y est.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mes débriefs'), findsOneWidget);
    expect(find.text('Footing du dimanche'), findsOneWidget);
  });

  testWidgets('comparer deux débriefs du même parcours', (tester) async {
    final debriefs = FakeDebriefRepository();
    DebriefSummary d(String id, int day, double movingS, int score) =>
        DebriefSummary(
          id: id,
          date: DateTime(2026, 11, day, 8),
          name: 'Boucle du parc',
          type: SessionType.endurance,
          distanceM: 10000,
          movingS: movingS,
          score: score,
          findings: const ['Tu es parti trop vite.'],
          gapPaceS: movingS / 10,
          start: const GeoPoint(45.75, 4.85),
        );
    debriefs.debriefs.addAll([d('a', 1, 3300, 72), d('b', 8, 3180, 88)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(debriefs: debriefs),
        child: const MaterialApp(home: DebriefsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('88'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Comparer avec une autre sortie'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Comparer avec une autre sortie'));
    await tester.pumpAndSettle();
    expect(find.textContaining('même parcours'), findsOneWidget);
    await tester.tap(find.textContaining('même parcours'));
    await tester.pumpAndSettle();
    expect(
      find.text('Même parcours : la comparaison est parlante.'),
      findsOneWidget,
    );
    expect(find.text('72/100'), findsOneWidget);
    expect(find.text('88/100'), findsOneWidget);
  });
}
