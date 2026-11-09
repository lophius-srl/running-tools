import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/history/history_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHistoryRepository history;

  final vameval = TestRecord(
    id: 'v',
    date: DateTime(2026, 11, 2, 18, 30),
    kind: TestKind.vameval,
    vmaKmh: 14.75,
    vo2max: 51.6,
    distanceM: 2725,
    completedStages: 14,
    fractionOfNextStage: 0.5,
    prorata: true,
    protocol: StagedTest.vameval.defaultProtocol.copyWith(
      markerSpacingM: 23.77,
    ),
    method: MeasurementMethod.shoe,
    shoes: 'Pegasus 41',
  );
  final cooper = TestRecord(
    id: 'c',
    date: DateTime(2026, 11, 9, 8, 0),
    kind: TestKind.cooper,
    vmaKmh: 15,
    vo2max: 55.8,
    distanceM: 3000,
  );

  setUp(() => history = FakeHistoryRepository());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(history: history),
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('historique vide', (tester) async {
    await pumpPage(tester);
    expect(find.text('Aucun test enregistré'), findsOneWidget);
  });

  testWidgets('liste chronologique : date, type, VMA, VO2max', (tester) async {
    history.records.addAll([vameval, cooper]);
    await pumpPage(tester);

    final cooperTop = tester.getTopLeft(find.text('Cooper')).dy;
    final vamevalTop = tester.getTopLeft(find.text('VAMEVAL')).dy;
    expect(cooperTop, lessThan(vamevalTop));
    expect(find.text('9 nov. 2026, 08:00'), findsOneWidget);
    expect(find.text('14,8 km/h'), findsOneWidget);
    expect(find.text('VO2max 51,6'), findsOneWidget);
  });

  testWidgets('détail : setup complet et allures recalculées', (tester) async {
    history.records.add(vameval);
    await pumpPage(tester);
    await tester.tap(find.text('VAMEVAL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Palier 14 complet, suivant couru à 50 % (prorata)'),
      findsOneWidget,
    );
    expect(
      find.text('Repères tous les 23,77 m (chaussures (talon-pointe))'),
      findsOneWidget,
    );
    expect(find.text('Chaussures : Pegasus 41'), findsOneWidget);
    expect(find.text("Allures d'entraînement"), findsOneWidget);
  });

  testWidgets('suppression : annuler garde le test, confirmer le retire', (
    tester,
  ) async {
    history.records.addAll([vameval, cooper]);
    await pumpPage(tester);
    await tester.tap(find.text('Cooper'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(history.records, hasLength(2));

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(history.records.map((r) => r.id), ['v']);
    expect(find.text('Cooper'), findsNothing);
    expect(find.text('VAMEVAL'), findsOneWidget);
  });
}
