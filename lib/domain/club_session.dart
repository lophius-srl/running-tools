import 'beep_schedule.dart';
import 'stage_protocol.dart';
import 'staged_outcome.dart';
import 'training_paces.dart';

/// Test par paliers passé à plusieurs sur la même bande-son.
class ClubSession {
  ClubSession({
    required this.test,
    required this.schedule,
    required List<String> names,
  }) : participants = List.unmodifiable(names) {
    if (names.isEmpty) throw ArgumentError.value(names, 'names', 'vide');
  }

  final StagedTest test;
  final BeepSchedule schedule;
  final List<String> participants;

  final _outcomes = <int, StagedOutcome>{};

  /// Participants dans l'ordre des abandons, pour l'annulation.
  final _history = <int>[];

  StagedOutcome? outcomeOf(int participant) => _outcomes[participant];

  bool hasDropped(int participant) => _outcomes.containsKey(participant);

  bool get allDropped => _outcomes.length == participants.length;

  /// « A décroché » à [testTimeS] secondes du départ. Ignoré avant le départ
  /// ou si le participant a déjà décroché.
  bool dropOut(int participant, double testTimeS) {
    if (testTimeS <= 0 || hasDropped(participant)) return false;
    _outcomes[participant] = StagedOutcome.at(test, schedule, testTimeS);
    _history.add(participant);
    return true;
  }

  /// Dernier abandon enregistré ; `null` si aucun.
  int? get lastDropOut => _history.isEmpty ? null : _history.last;

  bool undo() {
    if (_history.isEmpty) return false;
    _outcomes.remove(_history.removeLast());
    return true;
  }

  /// Participants encore en course quand le test s'arrête : ils ont tenu
  /// jusqu'à [testTimeS].
  void finishAt(double testTimeS) {
    for (var i = 0; i < participants.length; i++) {
      if (!hasDropped(i)) dropOut(i, testTimeS);
    }
  }

  /// Classement : vitesse retenue décroissante (sans résultat en dernier).
  List<ClubResult> results({required bool prorata}) {
    final rows = [
      for (var i = 0; i < participants.length; i++)
        if (_outcomes[i] case final outcome?)
          ClubResult(name: participants[i], outcome: outcome, prorata: prorata),
    ]..sort((a, b) => (b.speedKmh ?? -1).compareTo(a.speedKmh ?? -1));
    return rows;
  }

  /// Résultats en texte, prêts à partager.
  String exportText({required bool prorata, required String title}) {
    final lines = [title];
    for (final (i, r) in results(prorata: prorata).indexed) {
      final result = r.outcome.result(prorata: prorata);
      lines.add(
        result == null
            ? '${i + 1}. ${r.name} : aucun palier complet'
            : '${i + 1}. ${r.name} : palier ${r.outcome.completedStages}, '
                  'VMA ${_one(result.vmaKmh)} km/h, '
                  'VO2max ${_one(result.vo2max)}, '
                  'EF ${formatPace(paceForSpeed(result.vmaKmh * 0.65))} /km',
      );
    }
    return lines.join('\n');
  }

  /// « 15 » ou « 14,5 » : une décimale, sans zéro inutile.
  static String _one(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1).replaceAll('.', ',');
  }
}

class ClubResult {
  const ClubResult({
    required this.name,
    required this.outcome,
    required this.prorata,
  });

  final String name;
  final StagedOutcome outcome;
  final bool prorata;

  double? get speedKmh => outcome.reachedSpeedKmh(prorata: prorata);
}
