import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/domain/deck.dart';
import 'package:running_tools/domain/workout_plan.dart';
import 'package:running_tools/features/deck/deck_run_page.dart';
import 'package:running_tools/features/deck/decks_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeDeckRepository decks;
  late FakeWorkoutRepository workouts;
  late FakeBeepPlayer player;
  late FakeTrackService tracks;

  setUp(() {
    decks = FakeDeckRepository();
    workouts = FakeWorkoutRepository();
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
          decks: decks,
          workouts: workouts,
          player: player,
          tracks: tracks,
        ),
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lancer le deck équilibré avec une graine', (tester) async {
    await pump(tester, const DecksPage());
    await tester.tap(find.text('Deck équilibré'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('deck-seed')), '42');
    await tester.pump();
    await tester.tap(find.text('Mélanger et jouer'));
    await tester.pumpAndSettle();

    final expected = DeckDraw.draw(balancedDeck(), seed: 42, vmaKmh: 15);
    final program = tracks.programs.single;
    expect(
      program.events.where((e) => e.cue == Cue.start),
      hasLength(expected.cards.length),
    );
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('la carte se retourne, puis part à la défausse', (tester) async {
    final draw = DeckDraw.draw(balancedDeck(), seed: 5, vmaKmh: 15);
    final plan = WorkoutPlan.compute(
      draw.toWorkout(id: 'w', name: 'Deck'),
      vmaKmh: 15,
      markerSpacingM: 20,
    );
    await pump(tester, DeckRunPage(draw: draw, plan: plan));
    Future<void> at(Duration activity) async {
      player.emitPosition(activity + const Duration(seconds: 10));
      await tester.pumpAndSettle();
    }

    final first = plan.efforts.first;
    final firstCard = draw.cards.first;
    await at(first.start + const Duration(seconds: 1));
    expect(find.text(firstCard.title), findsOneWidget);
    expect(find.text('Carte 1/${draw.cards.length}'), findsOneWidget);

    await at(first.end + const Duration(seconds: 2));
    expect(find.text('?'), findsOneWidget);
    expect(find.widgetWithText(Chip, firstCard.title), findsOneWidget);
    expect(find.text('1 jouée(s)'), findsOneWidget);

    await at(plan.totalDuration + const Duration(seconds: 1));
    expect(find.text('Partie terminée !'), findsOneWidget);
    final save = find.text('Sauver la séance pour la refaire');
    await tester.scrollUntilVisible(
      save,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final saved = workouts.workouts.single;
    expect(saved.name, 'Deck équilibré · graine 5');
    expect(saved.sets, hasLength(draw.cards.length));
    expect(find.text('Séance sauvée'), findsOneWidget);
  });

  testWidgets('composer un deck perso avec budget d\'intensité', (
    tester,
  ) async {
    await pump(tester, const DecksPage());
    await tester.tap(find.text('Composer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Piste');
    await tester.tap(find.text('Budget d’intensité'));
    await tester.pump();
    for (final title in ['400 m à 95 %', '400 m à 95 %', '30 s sprint']) {
      final chip = find.widgetWithText(ActionChip, title);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
    }
    await tester.tap(find.text('Enregistrer le deck'));
    await tester.pumpAndSettle();

    final deck = decks.decks.single;
    expect(deck.name, 'Piste');
    expect(deck.cards.map((c) => c.id), ['c-400', 'c-400', 'c-sprint']);
    expect((deck.limit as PointsLimit).points, 60);
    expect(find.text('Piste'), findsOneWidget);
  });
}
