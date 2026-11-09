import 'dart:convert';

import '../domain/staged_test_setup.dart';
import '../domain/timed_test.dart';
import 'track_renderer.dart';

/// À incrémenter quand le rendu de la piste change (sons, annonces…).
const trackFormatVersion = 1;

/// Clé stable d'une piste : identique tant que rien d'audible ne change.
String trackCacheKey(StagedTestSetup setup, TrackRenderer renderer) {
  final audible = {
    ...setup.toJson()..remove('method'),
    'sampleRate': renderer.sampleRate,
    'leadIn': renderer.leadIn,
    'tail': renderer.tail,
    'format': trackFormatVersion,
  };
  return _fnv1a64(jsonEncode(audible)).toRadixString(16);
}

/// Clé d'une piste de test chronométré.
String timedTrackCacheKey(
  TimedTest test, {
  required int sampleRate,
  required int leadIn,
}) => _fnv1a64(
  jsonEncode({
    'timed': test.name,
    'sampleRate': sampleRate,
    'leadIn': leadIn,
    'format': trackFormatVersion,
  }),
).toRadixString(16);

/// Hachage FNV-1a 64 bits (déterministe d'une exécution à l'autre).
int _fnv1a64(String text) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(text)) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  return hash.toUnsigned(63);
}
