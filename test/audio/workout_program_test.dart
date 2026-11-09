import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/workout_program.dart';
import 'package:running_tools/domain/workout_library.dart';
import 'package:running_tools/domain/workout_plan.dart';

void main() {
  final plan = WorkoutPlan.compute(
    workoutLibrary.firstWhere((w) => w.id == 'lib-8x400'),
    vmaKmh: 15,
    markerSpacingM: 20,
  );
  final program = workoutChronoProgram(plan);

  List<double> timesOf(Cue cue) => [
    for (final e in program.events)
      if (e.cue == cue) e.atS,
  ];

  test('départs : signal + décompte, après l\'intro de 10 s', () {
    final starts = timesOf(Cue.start);
    expect(starts, hasLength(8));
    expect(starts.first, 10);
    expect(starts[1], 10 + 96 + 90);
    expect(timesOf(Cue.pip).take(3), [7, 8, 9]);
  });

  test('fins : double bip, triple bip pour la dernière', () {
    expect(timesOf(Cue.change), hasLength(7));
    expect(timesOf(Cue.change).first, 10 + 96);
    expect(timesOf(Cue.end).single, 10 + plan.totalDuration.inSeconds);
  });

  test('annonces : répétition 6 s avant, récupération, fin', () {
    expect(
      program.speeches,
      containsAll([
        'Répétition 1 sur 8, 400 mètres à 100 pour cent.',
        'Récupération, 1 minute 30.',
        sessionEndAnnouncement,
      ]),
    );
    final first = program.events.firstWhere(
      (e) => e.speech == 'Répétition 1 sur 8, 400 mètres à 100 pour cent.',
    );
    expect(first.atS, 4);
  });

  test('durée : intro + séance + marge', () {
    expect(program.durationS, 10 + plan.totalDuration.inSeconds + 4);
    expect(program.leadInS, 10);
  });

  test('résumés de séries', () {
    expect(describeSet(plan.workout.sets.single), '8 × 400 m à 100 %');
    final cotes = workoutLibrary.firstWhere((w) => w.id == 'lib-cotes');
    expect(describeSet(cotes.sets.single), '8 × 45 s');
  });
}
