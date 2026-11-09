import 'dart:io';
import 'dart:typed_data';

import 'pcm.dart';

const _formatPcm = 1;
const _formatFloat = 3;
const _formatExtensible = 0xFFFE;

/// En-tête WAV PCM 16 bits mono.
Uint8List wavHeader({required int sampleRate, required int sampleCount}) {
  final dataBytes = sampleCount * 2;
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, _formatPcm, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, dataBytes, Endian.little);
  return header.buffer.asUint8List();
}

/// Encode des échantillons 16 bits mono en WAV complet (en mémoire).
Uint8List encodeWav(Int16List samples, int sampleRate) {
  final builder = BytesBuilder(copy: false)
    ..add(wavHeader(sampleRate: sampleRate, sampleCount: samples.length))
    ..add(_littleEndianBytes(samples));
  return builder.takeBytes();
}

/// Écrit le WAV directement sur disque (évite une copie de 40 Mo en mémoire).
void writeWavFile(String path, Int16List samples, int sampleRate) {
  final file = File(path).openSync(mode: FileMode.write);
  try {
    file
      ..writeFromSync(
        wavHeader(sampleRate: sampleRate, sampleCount: samples.length),
      )
      ..writeFromSync(_littleEndianBytes(samples));
  } finally {
    file.closeSync();
  }
}

Uint8List _littleEndianBytes(Int16List samples) {
  if (Endian.host == Endian.little) return samples.buffer.asUint8List();
  final bytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Décode un WAV PCM 16 bits ou float 32 bits (mono ou multicanal → mono).
///
/// Tolérant : saute les chunks inconnus (ex. `FLLR` d'Apple) et accepte un
/// chunk `data` dont la taille n'a pas été finalisée.
MonoAudio decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String tag(int offset) => String.fromCharCodes(bytes, offset, offset + 4);
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('Pas un fichier WAV');
  }

  int? format, channels, sampleRate, bitsPerSample;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = tag(offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bitsPerSample = data.getUint16(body + 14, Endian.little);
      if (format == _formatExtensible && size >= 26) {
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      if (format == null) throw const FormatException('Chunk fmt manquant');
      final available = bytes.length - body;
      final length = (size == 0 || size > available) ? available : size;
      return MonoAudio(
        sampleRate!,
        _toMono(data, body, length, format, channels!, bitsPerSample!),
      );
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('Chunk data manquant');
}

Float32List _toMono(
  ByteData data,
  int start,
  int length,
  int format,
  int channels,
  int bitsPerSample,
) {
  final double Function(int) read;
  if (format == _formatPcm && bitsPerSample == 16) {
    read = (o) => data.getInt16(o, Endian.little) / 32768;
  } else if (format == _formatFloat && bitsPerSample == 32) {
    read = (o) => data.getFloat32(o, Endian.little);
  } else {
    throw FormatException(
      'Format WAV non géré : $format / $bitsPerSample bits',
    );
  }
  final bytesPerSample = bitsPerSample ~/ 8;
  final frameBytes = bytesPerSample * channels;
  final frames = length ~/ frameBytes;
  final out = Float32List(frames);
  for (var f = 0; f < frames; f++) {
    var sum = 0.0;
    for (var c = 0; c < channels; c++) {
      sum += read(start + f * frameBytes + c * bytesPerSample);
    }
    out[f] = sum / channels;
  }
  return out;
}
