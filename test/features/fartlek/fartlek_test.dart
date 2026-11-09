import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/data/fartlek_repository.dart';
import 'package:running_tools/domain/fartlek.dart';
import 'package:running_tools/features/fartlek/fartlek_run_page.dart';
import 'package:running_tools/features/fartlek/fartlek_setup_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeFartlekRepository fartleks;
  late FakeBeepPlayer player;
  late FakeTrackService tracks;

  setUp(() {
    fartleks = FakeFartlekRepository();
    player = FakeBeepPlayer();
    tracks = FakeTrackService();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          fartleks: fartleks,
          player: player,
          tracks: tracks,
        ),
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('départ : séance mémorisée avec sa graine, piste chargée', (
    tester,
  ) async {
    await pump(tester, const FartlekSetupPage());
    await tester.tap(find.text('30 min'));
    final seedField = find.byKey(const Key('fartlek-seed'));
    await scrollTo(tester, seedField);
    await tester.enterText(seedField, '424242');
    await tester.pump();
    await tester.tap(find.text('C’est parti'));
    await tester.pumpAndSettle();

    final saved = fartleks.list.single;
    expect(saved.seed, 424242);
    expect(saved.settings.total, const Duration(minutes: 30));
    final program = tracks.programs.single;
    final expected = FartlekPlan.generate(saved.settings, 424242);
    expect(
      program.events.where((e) => e.cue == Cue.change),
      hasLength(expected.bursts.length),
    );
  });

  testWidgets('rejouer une séance récente remet réglages et graine', (
    tester,
  ) async {
    fartleks.list.add(
      RecentFartlek(
        date: DateTime(2026, 11, 2),
        seed: 777777,
        settings: const FartlekSettings(
          total: Duration(minutes: 50),
          percentVma: 92,
        ),
      ),
    );
    await pump(tester, const FartlekSetupPage());
    await scrollTo(tester, find.text('50 minutes · graine 777777'));
    await tester.tap(find.text('50 minutes · graine 777777'));
    await tester.pumpAndSettle();
    expect(find.text('777777'), findsOneWidget);
    expect(find.text('92'), findsOneWidget);
  });

  testWidgets('graine invalide : départ bloqué', (tester) async {
    await pump(tester, const FartlekSetupPage());
    final seedField = find.byKey(const Key('fartlek-seed'));
    await scrollTo(tester, seedField);
    await tester.enterText(seedField, 'abc');
    await tester.pump();
    expect(find.text('Graine invalide (un nombre).'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'C’est parti');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('course : échauffement, accélération, footing, récap', (
    tester,
  ) async {
    final plan = FartlekPlan.generate(const FartlekSettings(), 42);
    await pump(tester, FartlekRunPage(plan: plan));
    Future<void> at(Duration activity) async {
      player.emitPosition(activity + const Duration(seconds: 5));
      await tester.pump();
    }

    await at(const Duration(minutes: 3));
    expect(find.text('Échauffement'), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);

    final b = plan.bursts.first;
    await at(b.start + const Duration(seconds: 2));
    expect(find.text('Accélère !'), findsOneWidget);

    await at(b.end + const Duration(seconds: 5));
    expect(find.text('Footing'), findsOneWidget);
    expect(find.textContaining('à tout moment'), findsOneWidget);

    await at(plan.total + const Duration(seconds: 1));
    expect(find.text('Séance terminée !'), findsOneWidget);
    expect(find.text('${plan.bursts.length} accélérations'), findsOneWidget);
  });
}
