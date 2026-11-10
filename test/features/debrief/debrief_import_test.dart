import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/common/gpx_picker.dart';
import 'package:running_tools/features/debrief/debriefs_page.dart';

import '../../fixtures/activities.dart';
import '../../support/fakes.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    ({String name, Uint8List bytes}) file, {
    FakeHistoryRepository? history,
  }) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(history: history),
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
    expect(find.text('4,99 km'), findsOneWidget);
    expect(find.textContaining('1 ·'), findsOneWidget);
    expect(
      find.text('Détecté : Endurance. Corrige si besoin.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Sortie longue'));
    await tester.pump();
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Sortie longue'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('FIT sans FC : analyses cardio annoncées masquées', (
    tester,
  ) async {
    await pumpPage(tester, (
      name: 'garmin.fit',
      bytes: toFit(easyRun(km: 2, withHeartRate: false)),
    ));
    expect(find.text('garmin'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Allure'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Split positif'), findsOneWidget);
    expect(find.textContaining('Départ rapide'), findsOneWidget);
    expect(
      find.textContaining('Temps gagnable estimé : environ'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Relief'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Relief'));
    await tester.pumpAndSettle();
    expect(find.textContaining('FC max 178'), findsOneWidget);
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
      find.text('VMA'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Fais un test de VMA pour comparer ta sortie.'),
      findsOneWidget,
    );
  });
}
