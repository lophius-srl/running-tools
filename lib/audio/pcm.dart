import 'dart:math';
import 'dart:typed_data';

/// Signal mono en flottants (-1..1) à une fréquence d'échantillonnage donnée.
class MonoAudio {
  const MonoAudio(this.sampleRate, this.samples);

  final int sampleRate;
  final Float32List samples;

  double get durationS => samples.length / sampleRate;
}

/// Sinusoïde avec fondus de 5 ms pour éviter les clics.
Float32List tone({
  required int sampleRate,
  required double frequencyHz,
  required Duration duration,
  double amplitude = 0.8,
}) {
  final length = (duration.inMicroseconds * sampleRate / 1e6).round();
  final fade = min((0.005 * sampleRate).round(), length ~/ 2);
  final out = Float32List(length);
  for (var i = 0; i < length; i++) {
    var gain = amplitude;
    if (i < fade) gain *= i / fade;
    if (i >= length - fade) gain *= (length - 1 - i) / fade;
    out[i] = gain * sin(2 * pi * frequencyHz * i / sampleRate);
  }
  return out;
}

/// Concatène des segments, avec [gapSamples] échantillons de silence entre chacun.
Float32List sequence(List<Float32List> parts, int gapSamples) {
  final total =
      parts.fold<int>(0, (total, p) => total + p.length) +
      gapSamples * (parts.isEmpty ? 0 : parts.length - 1);
  final out = Float32List(total);
  var offset = 0;
  for (final part in parts) {
    out.setAll(offset, part);
    offset += part.length + gapSamples;
  }
  return out;
}

/// Ajoute [clip] dans [track] à partir de [offset], avec saturation.
void mixInto(Int16List track, int offset, Float32List clip) {
  final end = min(track.length, offset + clip.length);
  for (var i = max(0, offset); i < end; i++) {
    final mixed = track[i] + (clip[i - offset] * 32767).round();
    track[i] = mixed.clamp(-32768, 32767);
  }
}

/// Rééchantillonnage linéaire (suffisant pour de la voix).
Float32List resample(Float32List input, int fromRate, int toRate) {
  if (fromRate == toRate || input.isEmpty) return input;
  final length = (input.length * toRate / fromRate).floor();
  final out = Float32List(length);
  final ratio = fromRate / toRate;
  for (var i = 0; i < length; i++) {
    final pos = i * ratio;
    final j = pos.floor();
    final frac = pos - j;
    final next = j + 1 < input.length ? input[j + 1] : input[j];
    out[i] = input[j] * (1 - frac) + next * frac;
  }
  return out;
}

/// Met le pic du signal à [peak].
Float32List normalize(Float32List input, {double peak = 0.9}) {
  var max = 0.0;
  for (final s in input) {
    if (s.abs() > max) max = s.abs();
  }
  if (max == 0) return input;
  final gain = peak / max;
  return Float32List.fromList([for (final s in input) s * gain]);
}
