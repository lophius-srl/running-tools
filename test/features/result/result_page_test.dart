import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_outcome.dart';
import 'package:running_tools/domain/staged_test_setup.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/domain/timed_test.dart';
import 'package:running_tools/features/result/result_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHistoryRepository history;

  final setup = StagedTestSetup(
    test: StagedTest.vameval,
    protocol: StagedTest.vameval.defaultProtocol.copyWith(
      markerSpacingM: 23.77,
    ),
    maxSpeedKmh: 20,
    method: MeasurementMethod.shoe,
  );

  StagedOutcome outcome({required int completed, double fraction = 0}) =>
      StagedOutcome(
        test: StagedTest.vameval,
        protocol: setup.protocol,
        completedStages: completed,
        fractionOfNextStage: fraction,
        distanceM: 2400,
      );

  setUp(() => history = FakeHistoryRepository());

  Future<void> pumpPage(WidgetTester tester, ResultPage page) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(history: history),
        child: MaterialApp(home: page),
      ),
    );
  }

  testWidgets('paliers : VMA, VO2max, setup et prorata', (tester) async {
    await pumpPage(
      tester,
      ResultPage.staged(outcome(completed: 14, fraction: 0.4), setup),
    );
    expect(find.text('VMA 14,5 km/h'), findsOneWidget);
    expect(find.text('VO2max 50,8 ml/kg/min'), findsOneWidget);
    expect(
      find.text('Palier 14 complet, palier suivant couru à 40 %'),
      findsOneWidget,
    );
    expect(
      find.text('Repères tous les 23,77 m (chaussures (talon-pointe))'),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('VMA 14,7 km/h'), findsOneWidget);
  });

  testWidgets('allures par zone', (tester) async {
    await pumpPage(tester, ResultPage.timed(TimedTest.cooper, 3000));
    expect(find.text('VMA 15 km/h'), findsOneWidget);
    expect(find.text('Endurance fondamentale'), findsOneWidget);
    expect(find.text('60–70 % VMA'), findsOneWidget);
    expect(find.text('6:40 – 5:43 /km'), findsOneWidget);
  });

  testWidgets('Enregistrer : test, setup et chaussures dans l\'historique', (
    tester,
  ) async {
    await pumpPage(
      tester,
      ResultPage.staged(outcome(completed: 14, fraction: 0.4), setup),
    );
    await tester.tap(find.byType(Switch));
    await tester.enterText(find.byType(TextField), ' Pegasus 41 ');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final r = history.records.single;
    expect(r.kind, TestKind.vameval);
    expect(r.vmaKmh, closeTo(14.7, 1e-9));
    expect(r.prorata, isTrue);
    expect(r.completedStages, 14);
    expect(r.protocol!.markerSpacingM, 23.77);
    expect(r.method, MeasurementMethod.shoe);
    expect(r.shoes, 'Pegasus 41');
    expect(find.text('Test enregistré'), findsOneWidget);
  });

  testWidgets('Ignorer : rien n\'est enregistré', (tester) async {
    await pumpPage(tester, ResultPage.timed(TimedTest.halfCooper, 1500));
    await tester.ensureVisible(find.text('Ignorer'));
    await tester.pump();
    await tester.tap(find.text('Ignorer'));
    await tester.pumpAndSettle();
    expect(history.records, isEmpty);
  });

  testWidgets('Cooper enregistré avec sa distance', (tester) async {
    await pumpPage(tester, ResultPage.timed(TimedTest.cooper, 2800));
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final r = history.records.single;
    expect(r.kind, TestKind.cooper);
    expect(r.distanceM, 2800);
    expect(r.shoes, isNull);
    expect(r.protocol, isNull);
  });

  testWidgets('aucun palier complet : ni allures ni enregistrement', (
    tester,
  ) async {
    await pumpPage(tester, ResultPage.staged(outcome(completed: 0), setup));
    expect(find.text('Aucun palier complet'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    expect(find.text('Terminer'), findsOneWidget);
  });
}
