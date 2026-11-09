import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/marker_spacing.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/features/setup_assistant/spacing_assistant_page.dart';

import '../../support/fakes.dart';

void main() {
  late SpacingChoice? result;
  late FakePreferencesRepository prefs;

  Future<void> pumpAssistant(
    WidgetTester tester, {
    FakeDistanceMeasurer? measurer,
  }) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    result = null;
    prefs = FakePreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(preferences: prefs, measurer: measurer),
        child: MaterialApp(
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

  testWidgets('AR : la mesure remplit l\'espacement', (tester) async {
    final measurer = FakeDistanceMeasurer(
      const SpacingChoice(19.86, MeasurementMethod.ar),
    );
    await pumpAssistant(tester, measurer: measurer);
    await tester.tap(find.text('Réalité augmentée'));
    await tester.pumpAndSettle();
    expect(measurer.requestedSpacing, 20);
    expect(result!.spacingM, 19.86);
    expect(result!.method, MeasurementMethod.ar);
  });

  testWidgets('AR abandonnée : on reste dans l\'assistant', (tester) async {
    await pumpAssistant(tester);
    await tester.tap(find.text('Réalité augmentée'));
    await tester.pumpAndSettle();
    expect(find.byType(SpacingAssistantPage), findsOneWidget);
    expect(result, isNull);
  });

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('chaussure : mètres → pas, longueur mémorisée', (tester) async {
    await pumpAssistant(tester);
    await tester.tap(find.text('Chaussure (talon-pointe)'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Longueur de la chaussure'), '29,5');
    await tester.pump();
    expect(
      find.text('Compte 67 pas + 23,5 cm entre deux repères.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Utiliser cet espacement'));
    await tester.pump();
    await tester.tap(find.text('Utiliser cet espacement'));
    await tester.pumpAndSettle();
    expect(result!.spacingM, 20);
    expect(result!.method, MeasurementMethod.shoe);
    expect(prefs.shoeLength, closeTo(0.295, 1e-9));
  });

  testWidgets('chaussure : calibrage puis pas → mètres', (tester) async {
    await pumpAssistant(tester);
    await tester.tap(find.text('Chaussure (talon-pointe)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Je ne la connais pas : calibrer'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Pas'), '34');
    await tester.tap(find.text('Calculer la longueur'));
    await tester.pumpAndSettle();
    expect(find.text('29,41'), findsOneWidget);

    await tester.ensureVisible(find.text('Pas → mètres'));
    await tester.pump();
    await tester.tap(find.text('Pas → mètres'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Pas comptés'), '68');
    await tester.pump();
    expect(find.text('Tes repères sont espacés de 20 m.'), findsOneWidget);
  });

  testWidgets('chaussure : longueur déjà mémorisée pré-remplie', (
    tester,
  ) async {
    await pumpAssistant(tester);
    prefs.shoeLength = 0.28;
    await tester.tap(find.text('Chaussure (talon-pointe)'));
    await tester.pumpAndSettle();
    expect(find.text('28'), findsOneWidget);
  });

  testWidgets('piste : mode d\'emploi puis 20 m', (tester) async {
    await pumpAssistant(tester);
    await tester.tap(find.text('Terrain normé'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Piste d’athlétisme (400 m)'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Piste d’athlétisme (400 m)'));
    await tester.pumpAndSettle();

    expect(find.text('Sur une piste de 400 m'), findsOneWidget);
    expect(find.textContaining('84,39 m'), findsOneWidget);
    expect(result, isNull);

    await tester.ensureVisible(find.text('Utiliser 20 m'));
    await tester.pump();
    await tester.tap(find.text('Utiliser 20 m'));
    await tester.pumpAndSettle();
    expect(result!.spacingM, 20);
    expect(result!.method, MeasurementMethod.field);
    expect(result!.source, 'Piste d’athlétisme (400 m)');
  });

  testWidgets('piste : fermer le mode d\'emploi ne valide rien', (
    tester,
  ) async {
    await pumpAssistant(tester);
    await tester.tap(find.text('Terrain normé'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Piste d’athlétisme (400 m)'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Piste d’athlétisme (400 m)'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(SpacingAssistantPage), findsOneWidget);
  });
}
