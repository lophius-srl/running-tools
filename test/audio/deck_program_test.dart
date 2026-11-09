import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/deck_program.dart';
import 'package:running_tools/domain/deck.dart';
import 'package:running_tools/domain/workout_plan.dart';

void main() {
  EffortCard card(String id) => predefinedCards.firstWhere((c) => c.id == id);

  test('cartes formulées pour la voix', () {
    expect(spokenCard(card('c-400')), '400 mètres à 95 pour cent');
    expect(spokenCard(card('c-sprint')), 'Sprint, 30 secondes');
    expect(spokenCard(card('c-cote')), 'Côte, 45 secondes');
    expect(spokenCard(card('c-1min')), '1 minute vite');
    expect(spokenCard(card('c-joker')), 'Joker ! 1 minute, choisis ton effort');
  });

  test('chaque carte annoncée, lièvre pour les cartes en distance', () {
    final draw = DeckDraw.draw(balancedDeck(), seed: 11, vmaKmh: 15);
    final plan = WorkoutPlan.compute(
      draw.toWorkout(id: 'w', name: 'Deck'),
      vmaKmh: 15,
      markerSpacingM: 20,
    );
    final program = deckProgram(draw, plan);
    for (final (i, c) in draw.cards.indexed) {
      expect(
        program.speeches,
        contains('Carte ${i + 1} sur ${draw.cards.length} : ${spokenCard(c)}.'),
      );
    }
    final hasDistance = draw.cards.any((c) => c.effort.isDistance);
    expect(program.events.any((e) => e.cue == Cue.marker), hasDistance);
  });
}
