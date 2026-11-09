import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/lane_calculator/lane_calculator_page.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LaneCalculatorPage()));
  }

  testWidgets('allure → temps : 400 m à 4:00/km en couloir 4', (tester) async {
    await pumpPage(tester);
    expect(find.text('1:36,0 en couloir 1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Couloir 4'));
    await tester.pump();
    expect(find.text('1:41,4 en couloir 4'), findsOneWidget);
    expect(find.text('422,37 m réels · 1:36,0 en couloir 1'), findsOneWidget);
  });

  testWidgets('temps → allure : 1:36 au couloir 3 = plus vite que 4:00/km', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.bySemanticsLabel('Couloir 3'));
    await tester.tap(find.text('Temps → allure'));
    await tester.pump();
    // 414,70 m en 96 s : 15,55 km/h, soit 3:51 /km.
    expect(find.text('3:51 /km · 15,6 km/h'), findsOneWidget);
    expect(
      find.text('Sans correction : 4:00 /km (414,7 m réels)'),
      findsOneWidget,
    );
  });

  testWidgets('saisie incomplète : message d\'aide', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Allure cible'), 'x');
    await tester.pump();
    expect(find.textContaining('Saisis une distance'), findsOneWidget);
  });

  testWidgets('table des tours : 453,03 m en couloir 8', (tester) async {
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('453,03 m'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('453,03 m'), findsOneWidget);
  });
}
