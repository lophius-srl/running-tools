import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';
import 'package:running_tools/features/common/pocket_mode_overlay.dart';
import 'package:running_tools/features/staged_run/staged_run_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBeepPlayer player;
  late FakePreferencesRepository preferences;
  late FakeScreenWakeLock wakeLock;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          player: player,
          preferences: preferences,
          wakeLock: wakeLock,
        ),
        child: MaterialApp(
          home: StagedRunPage(
            setup: StagedTestSetup.defaults(StagedTest.vameval),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    player = FakeBeepPlayer();
    preferences = FakePreferencesRepository();
    wakeLock = FakeScreenWakeLock();
  });

  testWidgets('piste chargée avec la préférence de ducking', (tester) async {
    preferences.duck = false;
    await pumpPage(tester);
    expect(player.calls, contains('load fake.wav'));
    expect(player.duckOthers, isFalse);
    expect(find.text('Départ dans 10 s'), findsOneWidget);
    expect(find.text('Palier 1'), findsOneWidget);
  });

  testWidgets('la position de lecture pilote l\'affichage', (tester) async {
    await pumpPage(tester);
    // Intro de 10 s, puis 90 s de test : milieu du palier 2.
    player.emitPosition(const Duration(seconds: 100));
    await tester.pump();
    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('Palier 2'), findsOneWidget);
    expect(find.text('8,5 km/h'), findsOneWidget);
    expect(find.text('204 m'), findsOneWidget);
    expect(find.text('dans 30 s'), findsOneWidget);

    player.emitPosition(const Duration(minutes: 26));
    await tester.pump();
    expect(find.text('Fin de la piste'), findsOneWidget);
  });

  testWidgets('lecture, pause et choix du ducking mémorisé', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Lecture'));
    await tester.pump();
    expect(player.calls, contains('play'));
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(preferences.duck, isFalse);
    expect(player.duckOthers, isFalse);
  });

  testWidgets('quitter l\'écran arrête et libère le lecteur', (tester) async {
    await pumpPage(tester);
    expect(wakeLock.enabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(player.calls, containsAllInOrder(['stop', 'dispose']));
    expect(wakeLock.enabled, isFalse);
  });

  testWidgets('« J\'ai décroché » arrête la piste et ouvre le résultat', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text("J'ai décroché"), findsNothing);

    // 10 s d'intro + 14 min 10 s : palier 14 complet.
    player.emitPosition(const Duration(minutes: 14, seconds: 20));
    await tester.pump();
    await tester.tap(find.text("J'ai décroché"));
    await tester.pumpAndSettle();

    expect(player.calls, contains('pause'));
    expect(find.text('VMA 14,5 km/h'), findsOneWidget);
  });

  testWidgets('mode poche : un tap ne fait rien, 2 s de maintien décrochent', (
    tester,
  ) async {
    await pumpPage(tester);
    player.emitPosition(const Duration(minutes: 14, seconds: 20));
    await tester.pump();
    await tester.tap(find.byTooltip('Mode poche'));
    await tester.pump();
    expect(find.byType(PocketModeOverlay), findsOneWidget);

    final dropOut = find.text("J'ai décroché").last;
    await tester.tap(dropOut);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(PocketModeOverlay), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(dropOut));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('VMA 14,5 km/h'), findsOneWidget);
  });

  testWidgets('mode poche : maintien en haut pour en sortir', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Mode poche'));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.lock_open)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.up();
    await tester.pump();
    expect(find.byType(PocketModeOverlay), findsNothing);
  });
}
