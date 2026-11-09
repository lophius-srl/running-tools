import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/common/tap_grid.dart';
import 'package:running_tools/features/multi_timer/multi_timer_page.dart';
import 'package:running_tools/features/multi_timer/multi_timer_setup_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeRaceClock clock;
  late FakeShareService share;

  setUp(() {
    clock = FakeRaceClock();
    share = FakeShareService();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(clock: clock, share: share),
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAt(WidgetTester tester, String name, double seconds) async {
    clock.elapsed = Duration(milliseconds: (seconds * 1000).round());
    await tester.tap(find.text(name));
    await tester.pump();
  }

  const page = MultiTimerPage(
    names: ['Léa', 'Tom'],
    targetLaps: 2,
    lapLengthM: 400,
  );

  testWidgets('départ, passages, arrivée, résultats et partage', (
    tester,
  ) async {
    await pump(tester, page);
    expect(find.byType(TapGrid), findsNothing);
    await tester.tap(find.text('Départ'));
    await tester.pump();
    expect(clock.started, isTrue);
    expect(find.text('Tour 1/2'), findsNWidgets(2));

    await tapAt(tester, 'Léa', 80);
    expect(find.text('Tour 2/2 · 1:20,0'), findsOneWidget);
    await tapAt(tester, 'Tom', 83);
    await tapAt(tester, 'Léa', 161);
    expect(find.text('Arrivé · 2:41,0'), findsOneWidget);

    // Léa est arrivée : son bouton ne compte plus.
    await tapAt(tester, 'Léa', 170);
    await tapAt(tester, 'Tom', 168);
    await tester.tap(find.text('Résultats'));
    await tester.pumpAndSettle();

    expect(find.text('2 tour(s) · 2:41,0 · meilleur 1:20,0'), findsOneWidget);
    expect(
      find.text('2 tour(s) · 2:48,0 · +0:07,0 · meilleur 1:23,0'),
      findsOneWidget,
    );
    await tester.tap(find.text('Partager les résultats'));
    await tester.pump();
    expect(share.shared.single, contains('1. Léa : 2 tour(s), 2:41,0'));
    expect(
      share.shared.single,
      contains('2. Tom : 2 tour(s), 2:48,0 (+0:07,0)'),
    );
  });

  testWidgets('annuler le dernier tap', (tester) async {
    await pump(tester, page);
    await tester.tap(find.text('Départ'));
    await tester.pump();
    await tapAt(tester, 'Tom', 90);
    expect(find.text('Annuler : Tom tour 1'), findsOneWidget);
    await tester.tap(find.text('Annuler : Tom tour 1'));
    await tester.pump();
    expect(find.text('Tour 1/2'), findsNWidgets(2));
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('configuration : distance → tours selon le couloir', (
    tester,
  ) async {
    await pump(tester, const MultiTimerSetupPage());
    expect(find.text('Prêt : 4 tour(s)'), findsOneWidget);
    await tester.tap(find.text('Distance'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Distance (tour entamé = tour compté)'),
      '1200',
    );
    await tester.pump();
    expect(find.text('Prêt : 3 tour(s)'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Couloir 8'));
    await tester.pump();
    expect(find.text('Couloir (tour de 453,03 m)'), findsOneWidget);
    expect(find.text('Prêt : 3 tour(s)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Inès');
    await tester.tap(find.text('Prêt : 3 tour(s)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Départ'));
    await tester.pump();
    expect(find.text('Inès'), findsOneWidget);
    expect(find.text('Tour 1/3'), findsNWidgets(4));
  });
}
