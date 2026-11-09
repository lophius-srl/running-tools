import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/providers.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';
import 'package:running_tools/features/staged_setup/staged_setup_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeSetupRepository repository;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(
          home: StagedSetupPage(test: StagedTest.vameval),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder fieldLabelled(String label) => find.widgetWithText(TextField, label);

  setUp(() => repository = FakeSetupRepository());

  testWidgets('réglages officiels et aperçu par défaut', (tester) async {
    await pumpPage(tester);
    expect(find.text('9 s'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
  });

  testWidgets('espacement libre avec virgule : aperçu recalculé', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(fieldLabelled('Espacement des repères'), '23,77');
    await tester.pump();
    expect(find.text('10,7 s'), findsOneWidget);
  });

  testWidgets('saisie invalide : message et bouton désactivé', (tester) async {
    await pumpPage(tester);
    await tester.enterText(fieldLabelled('Espacement des repères'), '0');
    await tester.pump();
    expect(
      find.text("L'espacement des repères doit être positif."),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.enterText(fieldLabelled('Vitesse de départ'), 'abc');
    await tester.pump();
    expect(
      find.text('Tous les champs doivent contenir un nombre.'),
      findsOneWidget,
    );
  });

  testWidgets('Démarrer mémorise les réglages', (tester) async {
    await pumpPage(tester);
    await tester.enterText(fieldLabelled('Espacement des repères'), '16,5');
    await tester.pump();
    await tester.tap(find.text('Démarrer'));
    await tester.pumpAndSettle();
    expect(repository.saved[StagedTest.vameval]!.protocol.markerSpacingM, 16.5);
  });

  testWidgets('réglages mémorisés rechargés à l\'ouverture', (tester) async {
    repository.saved[StagedTest.vameval] = StagedTestSetup(
      test: StagedTest.vameval,
      protocol: StagedTest.vameval.defaultProtocol.copyWith(markerSpacingM: 25),
      maxSpeedKmh: 18,
      method: StagedTestSetup.defaults(StagedTest.vameval).method,
    );
    await pumpPage(tester);
    expect(find.text('25'), findsOneWidget); // espacement mémorisé
    expect(find.text('21'), findsOneWidget);
    expect(find.text('21 min'), findsOneWidget);
  });
}
