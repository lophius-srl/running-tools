import 'ghost.dart';

/// Fréquence des annonces d'écart.
enum GhostAnnounceEvery {
  kilometer('Tous les km'),
  twoMinutes('Toutes les 2 min');

  const GhostAnnounceEvery(this.label);
  final String label;
}

/// Décide quoi annoncer pendant la course contre le fantôme : l'écart à
/// intervalle régulier, et chaque changement de leader. Un seuil (en
/// mètres) évite d'annoncer en boucle quand on est au coude à coude.
class GhostAnnouncer {
  GhostAnnouncer({
    this.every = GhostAnnounceEvery.kilometer,
    this.leadThresholdM = 10,
  });

  final GhostAnnounceEvery every;
  final double leadThresholdM;

  bool? _meAhead;
  var _lastMark = 0;

  /// Phrase à dire maintenant, ou `null`.
  String? update({
    required double timeS,
    required double distanceM,
    required GhostGap gap,
  }) {
    final phrases = <String>[];
    final leader = _leaderChange(gap);
    if (leader != null) phrases.add(leader);
    final mark = every == GhostAnnounceEvery.kilometer
        ? distanceM ~/ 1000
        : timeS ~/ 120;
    if (mark > _lastMark) {
      _lastMark = mark;
      final at = every == GhostAnnounceEvery.kilometer
          ? (mark == 1 ? '1 kilomètre' : '$mark kilomètres')
          : '${mark * 2} minutes';
      phrases.add('$at. ${describeGap(gap)}');
    }
    return phrases.isEmpty ? null : phrases.join(' ');
  }

  String? _leaderChange(GhostGap gap) {
    if (gap.meters.abs() < leadThresholdM) return null;
    final meAhead = gap.ahead;
    final previous = _meAhead;
    _meAhead = meAhead;
    if (previous == null || previous == meAhead) return null;
    return meAhead
        ? 'Tu dépasses ton fantôme !'
        : 'Le fantôme repasse devant, ${gap.meters.abs().round()} mètres.';
  }
}

/// « Tu as 12 secondes d'avance. »
String describeGap(GhostGap gap) {
  final s = gap.seconds.round().abs();
  if (s == 0) return 'Tu es à hauteur du fantôme.';
  final unit = s == 1 ? 'seconde' : 'secondes';
  final amount = s >= 60
      ? '${s ~/ 60} minute${s >= 120 ? 's' : ''}'
            '${s % 60 == 0 ? '' : ' ${s % 60}'}'
      : '$s $unit';
  return gap.seconds > 0
      ? 'Tu as $amount d’avance.'
      : 'Tu as $amount de retard.';
}

/// Courbe de l'écart (s) selon la distance, un point tous les [stepM] :
/// c'est un résumé, pas une trace.
class GapCurve {
  GapCurve({this.stepM = 100});

  final double stepM;
  final _points = <(double, double)>[];

  List<(double distanceM, double gapS)> get points =>
      List.unmodifiable(_points);

  void add(double distanceM, GhostGap gap) {
    final next = (_points.length + 1) * stepM;
    if (distanceM >= next) _points.add((next, gap.seconds));
  }
}
