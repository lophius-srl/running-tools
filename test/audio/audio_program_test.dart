import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';

void main() {
  AudioProgram program({double at = 12, String speech = 'Palier 2'}) =>
      AudioProgram(
        durationS: 60,
        leadInS: 10,
        events: [
          ProgramEvent.cue(at, Cue.marker),
          ProgramEvent.speech(20, speech),
          ProgramEvent.speech(40, speech),
        ],
      );

  String key(AudioProgram p) => p.cacheKey(sampleRate: 22050, format: 2);

  test('clé stable pour un programme identique', () {
    expect(key(program()), key(program()));
  });

  test('clé différente si un instant, un texte ou le format change', () {
    expect(key(program()), isNot(key(program(at: 12.001))));
    expect(key(program()), isNot(key(program(speech: 'Palier 3'))));
    expect(
      key(program()),
      isNot(program().cacheKey(sampleRate: 22050, format: 3)),
    );
  });

  test('chaque texte n\'est synthétisé qu\'une fois', () {
    expect(program().speeches, {'Palier 2'});
  });

  test('temps de l\'activité depuis la position de lecture', () {
    expect(program().activityTimeAt(const Duration(seconds: 70)), 60);
    expect(program().activityTimeAt(const Duration(seconds: 4)), -6);
  });
}
