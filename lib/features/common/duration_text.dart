/// Lit « 1:36 », « 1:36,4 », « 96,4 » ou « 1:02:03 » ; `null` si illisible.
Duration? parseClock(String text) {
  final parts = text.trim().replaceAll(',', '.').split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  var seconds = 0.0;
  for (var i = 0; i < parts.length; i++) {
    final value = double.tryParse(parts[i]);
    if (value == null || value < 0) return null;
    // Seules les secondes (dernière partie) peuvent avoir des décimales.
    if (i < parts.length - 1 && value != value.roundToDouble()) return null;
    if (i > 0 && value >= 60) return null;
    seconds = seconds * 60 + value;
  }
  return Duration(microseconds: (seconds * 1e6).round());
}

/// « 1:36,4 » (dixièmes) ou « 1:02:03,0 » au-delà d'une heure.
String formatSplit(Duration d) {
  final tenths = (d.inMilliseconds / 100).round();
  final totalSeconds = tenths ~/ 10;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return '${h > 0 ? '$h:' : ''}$mm:$s,${tenths % 10}';
}

/// Vitesse (km/h) d'une allure « min:ss » au kilomètre.
double? speedFromPace(String text) {
  final pace = parseClock(text);
  if (pace == null || pace <= Duration.zero) return null;
  return 3600 / (pace.inMicroseconds / 1e6);
}
