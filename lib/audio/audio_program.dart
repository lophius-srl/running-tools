import 'dart:convert';

/// Sons disponibles dans une bande-son.
enum Cue {
  /// Bip de repère (1000 Hz, 150 ms).
  marker,

  /// Double bip aigu : changement de palier, mi-temps, dernière minute.
  change,

  /// Décompte avant le départ des tests par paliers (doux).
  countdown,

  /// Décompte avant le départ des tests chronométrés.
  pip,

  /// Signal de départ (600 ms).
  start,

  /// Triple bip de fin.
  end,
}

/// Un événement de la bande-son, à [atS] secondes du début de la piste.
class ProgramEvent {
  const ProgramEvent.cue(this.atS, Cue this.cue) : speech = null;

  const ProgramEvent.speech(this.atS, String this.speech) : cue = null;

  final double atS;
  final Cue? cue;

  /// Texte lu par la synthèse vocale.
  final String? speech;

  Map<String, Object?> toJson() => {
    't': atS,
    if (cue case final c?) 'cue': c.name,
    'speech': ?speech,
  };
}

/// Bande-son à pré-générer : une durée et des événements datés.
///
/// Les événements sont mixés dans l'ordre de la liste : quand des sons se
/// chevauchent, l'ordre peut changer le résultat (saturation).
class AudioProgram {
  const AudioProgram({
    required this.durationS,
    required this.leadInS,
    required this.events,
  });

  /// Longueur totale de la piste.
  final double durationS;

  /// Instant du départ dans la piste (t = 0 de l'activité).
  final double leadInS;
  final List<ProgramEvent> events;

  /// Textes distincts à synthétiser.
  Set<String> get speeches => {for (final e in events) ?e.speech};

  /// Clé stable : identique tant que la piste produite est identique.
  String cacheKey({required int sampleRate, required int format}) => _fnv1a64(
    jsonEncode({
      'duration': durationS,
      'leadIn': leadInS,
      'events': [for (final e in events) e.toJson()],
      'sampleRate': sampleRate,
      'format': format,
    }),
  ).toRadixString(16);

  /// Temps de l'activité (secondes) à partir de la position de lecture.
  double activityTimeAt(Duration playback) =>
      playback.inMicroseconds / 1e6 - leadInS;
}

int _fnv1a64(String text) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(text)) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  return hash.toUnsigned(63);
}
