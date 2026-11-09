/// Textes des annonces vocales (lus par la synthèse vocale).
String formatKmh(double speed) {
  final rounded = (speed * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
}

String _spokenSpeed(double speed) =>
    '${formatKmh(speed).replaceAll(',', ' virgule ')} kilomètres heure';

String stageAnnouncement(int stage, double speedKmh) =>
    'Palier $stage, ${_spokenSpeed(speedKmh)}';

String introAnnouncement(String testName, double startSpeedKmh) =>
    '$testName. ${stageAnnouncement(1, startSpeedKmh)}. Départ dans 3 secondes.';

const endAnnouncement = 'Fin du test.';
