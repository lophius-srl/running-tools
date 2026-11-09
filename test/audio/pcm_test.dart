import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/pcm.dart';

void main() {
  test('tone : durée exacte, fondus sans clic', () {
    final t = tone(
      sampleRate: 22050,
      frequencyHz: 1000,
      duration: const Duration(milliseconds: 150),
    );
    expect(t.length, 3308); // 0,15 × 22050 arrondi
    expect(t.first, 0);
    expect(t.last.abs(), lessThan(1e-6));
    expect(t.reduce((a, b) => a.abs() > b.abs() ? a : b).abs(), lessThan(0.81));
  });

  test('mixInto additionne et sature', () {
    final track = Int16List.fromList([30000, 0, 0]);
    mixInto(track, 0, Float32List.fromList([0.5, 0.5]));
    expect(track[0], 32767);
    expect(track[1], 16384);
    expect(track[2], 0);
  });

  test('mixInto ignore ce qui dépasse la piste', () {
    final track = Int16List(2);
    mixInto(track, 1, Float32List.fromList([0.5, 0.5, 0.5]));
    expect(track, [0, 16384]);
  });

  test('resample : durée conservée, interpolation linéaire', () {
    final input = Float32List.fromList([0, 1, 0, -1]);
    final out = resample(input, 2, 4);
    expect(out, hasLength(8));
    expect(out[1], closeTo(0.5, 1e-6));
  });

  test('normalize : pic à 0,9', () {
    final out = normalize(Float32List.fromList([0.1, -0.3]));
    expect(out[1], closeTo(-0.9, 1e-6));
  });
}
