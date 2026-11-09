import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/marker_spacing.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/features/setup_assistant/spacing_assistant_page.dart';

void main() {
  late SpacingChoice? result;

  Future<void> pumpAssistant(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<SpacingChoice>(
                  MaterialPageRoute(
                    builder: (_) => const SpacingAssistantPage(),
                  ),
                ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('terrain normé : tennis → 23,77 m', (tester) async {
    await pumpAssistant(tester);
    await tester.tap(find.text('Terrain normé'));
    await tester.pumpAndSettle();
    expect(find.text('23,77 m'), findsOneWidget);

    await tester.tap(find.text('Tennis'));
    await tester.pumpAndSettle();
    expect(result!.spacingM, 23.77);
    expect(result!.method, MeasurementMethod.field);
    expect(result!.source, 'Tennis');
  });

  testWidgets('saisie manuelle avec virgule', (tester) async {
    await pumpAssistant(tester);
    await tester.tap(find.text('Saisie manuelle'));
    await tester.pumpAndSettle();

    final validate = find.widgetWithText(FilledButton, 'Valider');
    expect(tester.widget<FilledButton>(validate).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '18,3');
    await tester.pump();
    await tester.tap(validate);
    await tester.pumpAndSettle();
    expect(result!.spacingM, 18.3);
    expect(result!.method, MeasurementMethod.tape);
  });

  testWidgets('chaussure et AR pas encore disponibles', (tester) async {
    await pumpAssistant(tester);
    expect(find.text('Bientôt disponible'), findsNWidgets(2));
    await tester.tap(find.text('Réalité augmentée'));
    await tester.pumpAndSettle();
    expect(find.byType(SpacingAssistantPage), findsOneWidget);
  });
}
