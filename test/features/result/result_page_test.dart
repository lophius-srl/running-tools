import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_outcome.dart';
import 'package:running_tools/domain/timed_test.dart';
import 'package:running_tools/features/result/result_page.dart';

void main() {
  StagedOutcome outcome({required int completed, double fraction = 0}) =>
      StagedOutcome(
        test: StagedTest.vameval,
        protocol: StagedTest.vameval.defaultProtocol,
        completedStages: completed,
        fractionOfNextStage: fraction,
        distanceM: 2400,
      );

  Future<void> pumpPage(WidgetTester tester, ResultPage page) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: page));
  }

  testWidgets('paliers : VMA, VO2max et prorata', (tester) async {
    await pumpPage(
      tester,
      ResultPage.staged(outcome(completed: 14, fraction: 0.4)),
    );
    expect(find.text('VMA 14,5 km/h'), findsOneWidget);
    expect(find.text('VO2max 50,8 ml/kg/min'), findsOneWidget);
    expect(
      find.text('Palier 14 complet, palier suivant couru à 40 %.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('VMA 14,7 km/h'), findsOneWidget);
  });

  testWidgets('paliers : aucun palier complet', (tester) async {
    await pumpPage(tester, ResultPage.staged(outcome(completed: 0)));
    expect(find.text('Aucun palier complet'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Cooper : résultat depuis la distance, sans prorata', (
    tester,
  ) async {
    await pumpPage(tester, ResultPage.timed(TimedTest.cooper, 2800));
    expect(find.text('VMA 14 km/h'), findsOneWidget);
    expect(find.text('VO2max 51,3 ml/kg/min'), findsOneWidget);
    expect(find.text('2800 m en 12 min'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
}
