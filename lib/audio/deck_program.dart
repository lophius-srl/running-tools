import '../domain/deck.dart';
import '../domain/workout_plan.dart';
import 'announcements.dart';
import 'audio_program.dart';
import 'fartlek_program.dart';
import 'workout_program.dart';

/// Ce qu'une carte demande, formulé pour la voix.
String spokenCard(EffortCard card) {
  final e = card.effort;
  return switch (card.kind) {
    CardKind.joker =>
      'Joker ! ${spokenDuration(e.duration!)}, choisis ton effort',
    CardKind.sprint => 'Sprint, ${spokenDuration(e.duration!)}',
    CardKind.hill => 'Côte, ${spokenDuration(e.duration!)}',
    _ when e.isDistance =>
      '${formatKmh(e.distanceM!)} mètres'
          '${e.percentVma == null ? '' : ' à ${formatKmh(e.percentVma!)} pour cent'}',
    _ => '${spokenDuration(e.duration!)} vite',
  };
}

/// Bande-son d'un deck tiré : chaque carte est annoncée juste avant son
/// bloc ; lièvre sonore (bips aux repères) pour les cartes en distance.
AudioProgram deckProgram(DeckDraw draw, WorkoutPlan plan) => workoutProgram(
  plan,
  mode: draw.cards.any((c) => c.effort.isDistance)
      ? WorkoutAudioMode.pacer
      : WorkoutAudioMode.chrono,
  announce: (step) =>
      'Carte ${step.index} sur ${step.total} : '
      '${spokenCard(draw.cards[step.index - 1])}.',
);
