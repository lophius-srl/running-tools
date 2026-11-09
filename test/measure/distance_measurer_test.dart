import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/marker_spacing.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/measure/distance_measurer.dart';

void main() {
  late SpacingChoice? result;

  Future<void> open(WidgetTester tester, DistanceMeasurer measurer) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await measurer.measure(context, initialSpacingM: 20),
            child: const Text('Mesurer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mesurer'));
    await tester.pumpAndSettle();
  }

  testWidgets('saisie manuelle : valeur pré-remplie, virgule acceptée', (
    tester,
  ) async {
    await open(tester, const ManualDistanceMeasurer());
    expect(find.text('20'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '22,5');
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(result!.spacingM, 22.5);
    expect(result!.method, MeasurementMethod.manual);
  });

  testWidgets('saisie manuelle annulée : null', (tester) async {
    await open(tester, const ManualDistanceMeasurer());
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('AR indisponible : repli sur la saisie manuelle', (tester) async {
    await open(
      tester,
      AdaptiveDistanceMeasurer(isArSupported: () async => false),
    );
    expect(
      find.textContaining('La réalité augmentée n’est pas disponible'),
      findsOneWidget,
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(result!.spacingM, 20);
  });

  testWidgets('vérification ARKit en erreur : repli aussi', (tester) async {
    await open(
      tester,
      AdaptiveDistanceMeasurer(isArSupported: () async => throw Exception()),
    );
    expect(find.text('Distance mesurée'), findsOneWidget);
  });
}
