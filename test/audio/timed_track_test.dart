import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/timed_track.dart';
import 'package:running_tools/domain/timed_test.dart';

void main() {
  const rate = 22050;
  final track = renderTimedTrack(TimedTest.halfCooper, const {});

  bool soundAt(Int16List t, double s) {
    final start = (s * rate).round();
    return t
        .sublist(start, start + (0.02 * rate).round())
        .any((v) => v.abs() > 1000);
  }

  test('durée : intro 10 s + 6 min + marge 6 s', () {
    expect(track.length, rate * (10 + 360 + 6));
  });

  test('signaux au départ, mi-temps, dernière minute et fin', () {
    expect(soundAt(track, 10), isTrue);
    expect(soundAt(track, 10 + 180), isTrue);
    expect(soundAt(track, 10 + 300), isTrue);
    expect(soundAt(track, 10 + 360), isTrue);
    expect(soundAt(track, 10 + 90), isFalse);
  });

  test('annonces vocales mixées', () {
    final voice = Float32List.fromList(List.filled(2205, 0.5));
    final withVoice = renderTimedTrack(TimedTest.halfCooper, {
      TimedCueKind.lastMinute: voice,
    });
    final at = ((10 + 300 + 0.45 + 0.05) * rate).round();
    expect(withVoice[at], greaterThan(10000));
    expect(track[at], 0);
  });

  test('textes', () {
    expect(
      timedCueText(TimedTest.cooper, TimedCueKind.halfway),
      'Mi-temps. Encore 6 minutes.',
    );
  });
}
