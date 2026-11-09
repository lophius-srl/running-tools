import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/history/progress_card.dart';

void main() {
  TestRecord record(String id, DateTime date, TestKind kind, double vma) =>
      TestRecord(
        id: id,
        date: date,
        kind: kind,
        vmaKmh: vma,
        vo2max: vma * 3.5,
      );

  Future<void> pumpCard(WidgetTester tester, List<TestRecord> records) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [ProgressCard(records: records)]),
        ),
      ),
    );
  }

  LineChartData chartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart)).data;

  testWidgets('un seul test : valeur et invitation, pas de courbe', (
    tester,
  ) async {
    await pumpCard(tester, [
      record('a', DateTime(2026, 9, 1), TestKind.vameval, 14.5),
    ]);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('14,5 km/h'), findsOneWidget);
  });

  testWidgets('courbe VMA, puis VO2max', (tester) async {
    await pumpCard(tester, [
      record('a', DateTime(2026, 9, 1), TestKind.vameval, 14),
      record('b', DateTime(2026, 10, 1), TestKind.vameval, 14.5),
    ]);
    expect(chartData(tester).lineBarsData.single.spots.map((s) => s.y), [
      14,
      14.5,
    ]);

    await tester.tap(find.text('VO2max'));
    await tester.pumpAndSettle();
    expect(find.text('Progression VO2max (ml/kg/min)'), findsOneWidget);
    expect(chartData(tester).lineBarsData.single.spots.map((s) => s.y), [
      49,
      50.75,
    ]);
  });

  testWidgets('filtre par type de test', (tester) async {
    await pumpCard(tester, [
      record('a', DateTime(2026, 9, 1), TestKind.vameval, 14),
      record('b', DateTime(2026, 10, 1), TestKind.vameval, 14.5),
      record('c', DateTime(2026, 11, 1), TestKind.cooper, 15),
    ]);
    expect(chartData(tester).lineBarsData.single.spots, hasLength(3));

    await tester.tap(find.widgetWithText(FilterChip, 'Cooper'));
    await tester.pumpAndSettle();
    expect(chartData(tester).lineBarsData.single.spots, hasLength(2));

    await tester.tap(find.widgetWithText(FilterChip, 'VAMEVAL'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun test pour ce filtre.'), findsOneWidget);
  });

  testWidgets('pas de filtre quand un seul type de test', (tester) async {
    await pumpCard(tester, [
      record('a', DateTime(2026, 9, 1), TestKind.cooper, 14),
      record('b', DateTime(2026, 10, 1), TestKind.cooper, 14.5),
    ]);
    expect(find.byType(FilterChip), findsNothing);
  });
}
