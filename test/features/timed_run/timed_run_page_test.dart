import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/timed_test.dart';
import 'package:running_tools/features/common/pocket_mode_overlay.dart';
import 'package:running_tools/features/timed_run/timed_run_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBeepPlayer player;
  late FakeScreenWakeLock wakeLock;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(player: player, wakeLock: wakeLock),
        child: const MaterialApp(home: TimedRunPage(test: TimedTest.cooper)),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    player = FakeBeepPlayer();
    wakeLock = FakeScreenWakeLock();
  });

  testWidgets('décompte puis temps restant', (tester) async {
    await pumpPage(tester);
    expect(player.calls, contains('load fake.wav'));
    expect(wakeLock.enabled, isTrue);
    expect(find.text('Départ dans 10 s'), findsOneWidget);

    // 10 s d'intro + 4 min 30 : il reste 7 min 30.
    player.emitPosition(const Duration(minutes: 4, seconds: 40));
    await tester.pump();
    expect(find.text('07:30'), findsOneWidget);
  });

  testWidgets('mode poche sans bouton « J\'ai décroché »', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Mode poche'));
    await tester.pump();
    expect(find.byType(PocketModeOverlay), findsOneWidget);
    expect(find.text("J'ai décroché"), findsNothing);
  });

  testWidgets('fin du chrono : saisie de la distance puis résultat', (
    tester,
  ) async {
    await pumpPage(tester);
    player.emitPosition(const Duration(minutes: 12, seconds: 11));
    await tester.pump();
    expect(find.text('Temps écoulé !'), findsOneWidget);

    final button = find.widgetWithText(FilledButton, 'Voir le résultat');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '2800');
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('VMA 14 km/h'), findsOneWidget);
  });
}
