import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/timed_track.dart';
import 'package:running_tools/audio/track_renderer.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/timed_test.dart';

/// Empreinte FNV-1a 64 bits des échantillons : la moindre différence change
/// la valeur.
String fingerprint(Int16List samples) {
  var hash = 0xcbf29ce484222325;
  for (final s in samples) {
    hash ^= s & 0xffff;
    hash *= 0x100000001b3;
  }
  return hash.toUnsigned(63).toRadixString(16);
}

/// Fausse voix reconnaissable (rampe), longueur fonction du texte.
Float32List voice(int length) =>
    Float32List.fromList([for (var i = 0; i < length; i++) (i % 100) / 200]);

// Empreintes relevées AVANT le passage au moteur générique (#48) : le
// refactoring doit produire exactement les mêmes pistes.
void main() {
  test('piste VAMEVAL (3 min, 23,77 m) inchangée', () {
    final schedule = BeepSchedule.generate(
      const StageProtocol.vameval(markerSpacingM: 23.77),
      duration: const Duration(minutes: 3),
    );
    final track = TrackRenderer().render(
      schedule,
      AnnouncementClips(
        intro: voice(30000),
        stages: {2: voice(15000), 3: voice(16000)},
        end: voice(9000),
      ),
    );
    expect(track.length, 22050 * (10 + 180 + 4));
    expect(fingerprint(track), '3938f2080b0b5ab2');
  });

  test('piste demi-Cooper inchangée', () {
    final track = renderTimedTrack(TimedTest.halfCooper, {
      for (final kind in TimedCueKind.values) kind: voice(10000 + kind.index),
    });
    expect(fingerprint(track), '6da9e6d292498249');
  });
}
