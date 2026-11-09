import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/orthostatic.dart';
import 'package:running_tools/features/orthostatic/orthostatic_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeOrthostaticRepository repo;
  late FakeReminderScheduler reminders;
  late FakeBeepPlayer player;

  setUp(() {
    repo = FakeOrthostaticRepository();
    reminders = FakeReminderScheduler();
    player = FakeBeepPlayer();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          orthostatic: repo,
          reminders: reminders,
          player: player,
        ),
        child: const MaterialApp(home: OrthostaticPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  OrthostaticResult past(int day, int lying, int stable) => OrthostaticResult(
    date: DateTime(2026, 10, day, 7),
    lyingBpm: lying,
    standingPeakBpm: stable + 15,
    standingStableBpm: stable,
    source: HeartRateSourceKind.manual,
  );

  testWidgets('texte prudent toujours affiché', (tester) async {
    await pumpPage(tester);
    expect(find.textContaining('pas un outil médical'), findsOneWidget);
  });

  testWidgets('test guidé, comptages, résultat comparé à ma moyenne', (
    tester,
  ) async {
    repo.results.addAll([past(1, 50, 70), past(8, 51, 71), past(15, 49, 69)]);
    await pumpPage(tester);
    await tester.tap(find.text('Faire le test (5 min)'));
    await tester.pumpAndSettle();
    expect(find.text('Allonge-toi sur le dos'), findsOneWidget);

    player.emitPosition(const Duration(minutes: 5, seconds: 3));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '13');
    await tester.enterText(fields.at(1), '21');
    await tester.enterText(fields.at(2), '20');
    await tester.pump();
    await tester.tap(find.text('Voir le résultat'));
    await tester.pumpAndSettle();

    // Couché 52, debout 80 : écart 28 contre ~20 d'habitude.
    expect(find.text('À surveiller : inhabituel pour toi'), findsOneWidget);
    expect(repo.results, hasLength(4));
    expect(repo.results.last.delta, 28);
  });

  testWidgets('rappel hebdomadaire : jour et heure', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mardi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final weekly = reminders.weekly[orthostaticReminderId]!;
    expect(weekly.weekday, DateTime.tuesday);
    expect((weekly.hour, weekly.minute), (7, 0));
    expect(weekly.payload, orthostaticPayload);
    expect(find.text('Rappel le mardi à 7h00'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer le rappel'));
    await tester.pumpAndSettle();
    expect(reminders.weekly, isEmpty);
    expect(repo.savedReminder, isNull);
  });
}
