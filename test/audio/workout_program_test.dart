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
  final program = workoutProgram(plan);

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

  group('lièvre sonore', () {
    final pacer = workoutProgram(plan, mode: WorkoutAudioMode.pacer);
    final markers = [
      for (final e in pacer.events)
        if (e.cue == Cue.marker) e.atS,
    ];

    test('un bip par repère, sauf celui qui tombe sur la fin', () {
      // 20 repères par 400 m, le 20e confondu avec le signal de fin.
      expect(markers, hasLength(8 * 19));
      expect(markers.first, closeTo(10 + 4.8, 1e-9));
      expect(markers[18], closeTo(10 + 19 * 4.8, 1e-9));
      // 2e répétition : départ à 10 + 96 + 90 s.
      expect(markers[19], closeTo(10 + 96 + 90 + 4.8, 1e-9));
    });

    test('pas de bip de repère en mode chrono', () {
      expect(program.events.where((e) => e.cue == Cue.marker), isEmpty);
    });

    test('couloir 3 : bips espacés selon la distance réelle', () {
      final lane3 = WorkoutPlan.compute(
        plan.workout,
        vmaKmh: 15,
        markerSpacingM: 20,
        lane: 3,
      );
      final first = workoutProgram(
        lane3,
        mode: WorkoutAudioMode.pacer,
      ).events.firstWhere((e) => e.cue == Cue.marker);
      expect(first.atS, closeTo(10 + 20 * 414.70 / 400 / (15 / 3.6), 0.01));
    });
  });

  test('récupération longue : « Encore 30 secondes » 30 s avant la fin', () {
    final countdowns = [
      for (final e in program.events)
        if (e.speech == recoveryCountdownAnnouncement) e.atS,
    ];
    expect(countdowns, hasLength(7));
    expect(countdowns.first, 10 + 96 + 90 - 30);
  });
}
