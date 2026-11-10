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
    this.rival,
  });

  final GhostAnnounceEvery every;
  final double leadThresholdM;

  /// Prénom de l'ami (duo) ; `null` pour le fantôme.
  final String? rival;

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
      phrases.add('$at. ${describeGap(gap, rival: rival)}');
    }
    return phrases.isEmpty ? null : phrases.join(' ');
  }

  String? _leaderChange(GhostGap gap) {
    if (gap.meters.abs() < leadThresholdM) return null;
    final meAhead = gap.ahead;
    final previous = _meAhead;
    _meAhead = meAhead;
    if (previous == null || previous == meAhead) return null;
    final meters = gap.meters.abs().round();
    return switch ((meAhead, rival)) {
      (true, null) => 'Tu dépasses ton fantôme !',
      (false, null) => 'Le fantôme repasse devant, $meters mètres.',
      (true, final name?) => 'Tu passes devant $name !',
      (false, final name?) => '$name repasse devant, $meters mètres.',
    };
  }
}

/// « Tu as 12 secondes d'avance. » ; en duo : « Tom est 50 mètres devant. »
String describeGap(GhostGap gap, {String? rival}) {
  if (rival != null) return _describeRivalGap(gap, rival);
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

String _describeRivalGap(GhostGap gap, String rival) {
  final m = gap.meters.round().abs();
  if (m < 3) return 'Tu es à hauteur de $rival.';
  final metres = m == 1 ? 'mètre' : 'mètres';
  return gap.meters > 0
      ? 'Tu es $m $metres devant $rival.'
      : '$rival est $m $metres devant.';
}
