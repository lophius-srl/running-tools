import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/orthostatic_program.dart';
import 'package:running_tools/domain/orthostatic.dart';

void main() {
  const protocol = OrthostaticProtocol();

  List<double> times(AudioProgram p, Cue cue) => [
    for (final e in p.events)
      if (e.cue == cue) e.atS,
  ];

  test('« Lève-toi » à 3 min, fin à 5 min', () {
    final p = orthostaticProgram(protocol, manual: false);
    expect(times(p, Cue.start), [2 + 180]);
    expect(times(p, Cue.end), [2 + 300]);
    expect(
      p.speeches,
      contains('Lève-toi maintenant, et reste debout immobile.'),
    );
    expect(p.speeches, contains('Mesure de la fréquence couchée.'));
  });

  test('manuel : 3 comptages de 15 s encadrés par « Top » et « Stop »', () {
    final p = orthostaticProgram(protocol, manual: true);
    final starts = manualCountStarts(protocol);
    expect(starts, const [
      Duration(seconds: 160),
      Duration(seconds: 185),
      Duration(seconds: 280),
    ]);
    expect(times(p, Cue.pip), [
      for (final s in starts) 2 + s.inSeconds.toDouble(),
    ]);
    expect(times(p, Cue.change), [
      for (final s in starts) 2 + s.inSeconds + 15.0,
    ]);
    // Les comptages ne chevauchent pas le lever.
    expect(
      starts[0] + manualCountLength,
      lessThanOrEqualTo(protocol.standUpAt),
    );
    expect(starts[1], greaterThan(protocol.standUpAt));
  });
}
