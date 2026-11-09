import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/metronome_program.dart';
import 'package:running_tools/audio/program_renderer.dart';

void main() {
  List<double> ticks(AudioProgram p) => [
    for (final e in p.events)
      if (e.cue == Cue.tick) e.atS,
  ];

  test('180 pas/min pendant 1 min : 180 tics toutes les 1/3 s', () {
    final p = metronomeProgram(
      stepsPerMinute: 180,
      duration: const Duration(minutes: 1),
    );
    final t = ticks(p);
    expect(t, hasLength(180));
    expect(t.first, 5);
    expect(t[90], closeTo(5 + 30, 1e-9));
    expect(t.last, closeTo(5 + 179 / 3, 1e-9));
    expect(p.leadInS, 5);
  });

  test('pas de dérive : le 1000e tic tombe à l\'échantillon près', () {
    final p = metronomeProgram(
      stepsPerMinute: 173,
      duration: const Duration(minutes: 10),
    );
    final renderer = ProgramRenderer();
    final t = ticks(p);
    expect(renderer.sampleAt(t[1000]), renderer.sampleAt(5 + 1000 * 60 / 173));
  });

  test('annonce et décompte avant le premier tic', () {
    final p = metronomeProgram(
      stepsPerMinute: 165,
      duration: const Duration(minutes: 1),
    );
    expect(p.speeches, {'Métronome, 165 pas par minute.'});
    expect(
      [
        for (final e in p.events)
          if (e.cue == Cue.pip) e.atS,
      ],
      [2, 3, 4],
    );
  });

  test('cadence nulle refusée', () {
    expect(
      () => metronomeProgram(stepsPerMinute: 0, duration: Duration.zero),
      throwsArgumentError,
    );
  });
}
