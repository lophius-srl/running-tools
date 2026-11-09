import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/club/club_setup_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeRecentNamesRepository names;
  late FakeBeepPlayer player;
  late FakeShareService share;

  setUp(() {
    names = FakeRecentNamesRepository()..names = ['Léa', 'Tom', 'Sam'];
    player = FakeBeepPlayer();
    share = FakeShareService();
  });

  Future<void> pumpSetup(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          recentNames: names,
          player: player,
          share: share,
        ),
        child: const MaterialApp(home: ClubSetupPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> at(WidgetTester tester, Duration playback) async {
    player.emitPosition(playback);
    await tester.pump();
  }

  testWidgets('participants : récents en un tap, saisie libre', (tester) async {
    await pumpSetup(tester);
    expect(find.text('Ajoute des participants'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Léa'));
    await tester.tap(find.widgetWithText(ActionChip, 'Tom'));
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Inès');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Démarrer avec 3 coureur(s)'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Sam'), findsOneWidget);

    await tester.tap(find.text('Démarrer avec 3 coureur(s)'));
    await tester.pumpAndSettle();
    expect(names.names.take(3), ['Léa', 'Tom', 'Inès']);
  });

  testWidgets('chaque tap enregistre le palier, puis classement et partage', (
    tester,
  ) async {
    await pumpSetup(tester);
    for (final n in ['Léa', 'Tom', 'Sam']) {
      await tester.tap(find.widgetWithText(ActionChip, n));
    }
    await tester.pump();
    await tester.tap(find.text('Démarrer avec 3 coureur(s)'));
    await tester.pumpAndSettle();
    expect(player.calls, contains('load fake.wav'));

    // Pendant l'intro, un tap ne compte pas.
    await tester.tap(find.text('Tom'));
    await tester.pump();
    expect(find.text('En course'), findsNWidgets(3));

    // 10 s d'intro + 12 min 30 : palier 12 complet, 50 % du 13e.
    await at(tester, const Duration(minutes: 12, seconds: 40));
    await tester.tap(find.text('Sam'));
    await tester.pump();
    expect(find.text('Palier 12 + 50 %'), findsOneWidget);
    expect(find.text('Annuler : Sam'), findsOneWidget);

    await at(tester, const Duration(minutes: 14, seconds: 20));
    await tester.tap(find.text('Léa'));
    await at(tester, const Duration(minutes: 15, seconds: 40));
    await tester.tap(find.text('Tom'));
    await tester.pumpAndSettle();

    // Tous ont décroché : résultats.
    expect(find.text('Résultats du groupe'), findsOneWidget);
    expect(find.text('Tom · VMA 15 km/h'), findsOneWidget);
    expect(find.text('Léa · VMA 14,5 km/h'), findsOneWidget);
    expect(find.text('Sam · VMA 13,5 km/h'), findsOneWidget);

    await tester.tap(find.byTooltip('Partager'));
    await tester.pump();
    expect(share.shared.single, contains('1. Tom : palier 15, VMA 15 km/h'));
  });

  testWidgets('annuler un abandon tapé par erreur', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Léa'));
    await tester.tap(find.widgetWithText(ActionChip, 'Tom'));
    await tester.pump();
    await tester.tap(find.text('Démarrer avec 2 coureur(s)'));
    await tester.pumpAndSettle();
    await at(tester, const Duration(minutes: 5));
    await tester.tap(find.text('Léa'));
    await tester.pump();
    await tester.tap(find.text('Annuler : Léa'));
    await tester.pump();
    expect(find.text('En course'), findsNWidgets(2));
  });
}
