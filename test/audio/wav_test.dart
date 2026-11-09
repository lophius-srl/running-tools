import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/wav.dart';

Uint8List _floatWav({
  required int sampleRate,
  required List<double> samples,
  bool extensible = false,
  bool withFillerChunk = false,
  bool unfinalizedDataSize = false,
}) {
  final b = BytesBuilder();
  void ascii(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  ascii('RIFF');
  u32(0);
  ascii('WAVE');
  if (withFillerChunk) {
    ascii('FLLR');
    u32(3); // taille impaire : un octet de bourrage suit
    b.add([0, 0, 0, 0]);
  }
  ascii('fmt ');
  u32(extensible ? 40 : 16);
  u16(extensible ? 0xFFFE : 3);
  u16(1);
  u32(sampleRate);
  u32(sampleRate * 4);
  u16(4);
  u16(32);
  if (extensible) {
    u16(22);
    u16(32);
    u32(4);
    u16(3); // sous-format float
    b.add(List.filled(14, 0));
  }
  ascii('data');
  u32(unfinalizedDataSize ? 0 : samples.length * 4);
  for (final s in samples) {
    b.add((ByteData(4)..setFloat32(0, s, Endian.little)).buffer.asUint8List());
  }
  return b.toBytes();
}

void main() {
  test('aller-retour PCM 16 bits', () {
    final samples = Int16List.fromList([0, 16384, -16384, 32767, -32768]);
    final bytes = encodeWav(samples, 22050);
    expect(bytes.length, 44 + 10);
    expect(String.fromCharCodes(bytes, 0, 4), 'RIFF');

    final decoded = decodeWav(bytes);
    expect(decoded.sampleRate, 22050);
    expect(decoded.samples, hasLength(5));
    expect(decoded.samples[1], closeTo(0.5, 1e-4));
    expect(decoded.samples[2], closeTo(-0.5, 1e-4));
  });

  test('float 32 bits (format produit par AVAudioFile)', () {
    final decoded = decodeWav(
      _floatWav(sampleRate: 24000, samples: [0.25, -0.75]),
    );
    expect(decoded.sampleRate, 24000);
    expect(decoded.samples, [closeTo(0.25, 1e-6), closeTo(-0.75, 1e-6)]);
  });

  test('WAVE_FORMAT_EXTENSIBLE + chunk inconnu de taille impaire', () {
    final decoded = decodeWav(
      _floatWav(
        sampleRate: 22050,
        samples: [0.5, 0.1, -0.2],
        extensible: true,
        withFillerChunk: true,
      ),
    );
    expect(decoded.samples, hasLength(3));
    expect(decoded.samples.first, closeTo(0.5, 1e-6));
  });

  test('taille du chunk data non finalisée : lit jusqu\'à la fin', () {
    final decoded = decodeWav(
      _floatWav(
        sampleRate: 22050,
        samples: [0.1, 0.2, 0.3, 0.4],
        unfinalizedDataSize: true,
      ),
    );
    expect(decoded.samples, hasLength(4));
  });

  test('rejette un fichier qui n\'est pas un WAV', () {
    expect(
      () => decodeWav(Uint8List.fromList(List.filled(20, 0))),
      throwsFormatException,
    );
  });
}
