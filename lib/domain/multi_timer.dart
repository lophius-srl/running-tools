/// Chronométrage de plusieurs coureurs : un tap = un passage.
class MultiTimer {
  MultiTimer(List<String> names, {required this.targetLaps})
    : runners = [for (final n in names) RunnerTimes(n)] {
    if (names.isEmpty) throw ArgumentError.value(names, 'names', 'vide');
    if (targetLaps < 1) {
      throw ArgumentError.value(targetLaps, 'targetLaps', 'doit être ≥ 1');
    }
  }

  final List<RunnerTimes> runners;
  final int targetLaps;

  /// Coureurs dans l'ordre des taps, pour l'annulation.
  final _history = <int>[];

  /// Enregistre un passage du coureur [runner] à [elapsed] depuis le départ.
  /// Renvoie `false` si le coureur a déjà terminé ou si le temps recule.
  bool tap(int runner, Duration elapsed) {
    final times = runners[runner];
    if (times.isFinished(targetLaps)) return false;
    if (times.passages.isNotEmpty && elapsed <= times.passages.last) {
      return false;
    }
    times.passages.add(elapsed);
    _history.add(runner);
    return true;
  }

  /// Dernier passage enregistré (coureur, tour) ; `null` si aucun.
  ({int runner, int lap})? get lastTap => _history.isEmpty
      ? null
      : (runner: _history.last, lap: runners[_history.last].laps);

  /// Annule le dernier passage, quel que soit le coureur.
  bool undo() {
    if (_history.isEmpty) return false;
    runners[_history.removeLast()].passages.removeLast();
    return true;
  }

  bool get allFinished => runners.every((r) => r.isFinished(targetLaps));

  /// Classement : plus de tours d'abord, puis passage le plus tôt.
  List<Standing> standings() {
    final order = [...runners]
      ..sort((a, b) {
        final byLaps = b.laps.compareTo(a.laps);
        if (byLaps != 0) return byLaps;
        if (a.laps == 0) return 0;
        return a.passages.last.compareTo(b.passages.last);
      });
    return [
      for (var i = 0; i < order.length; i++)
        Standing(
          rank: i + 1,
          runner: order[i],
          gap: _gapToLeader(order[i], order.first),
        ),
    ];
  }

  /// Écart avec le premier au même tour ; `null` sans tour bouclé.
  static Duration? _gapToLeader(RunnerTimes runner, RunnerTimes leader) {
    final lap = runner.laps;
    if (lap == 0 || leader.laps < lap) return null;
    return runner.passages[lap - 1] - leader.passages[lap - 1];
  }

  /// Résultats en texte, prêts à partager.
  String exportText({String title = 'Chrono', double? lapLengthM}) {
    final lines = <String>[title];
    for (final s in standings()) {
      final r = s.runner;
      final total = r.laps == 0 ? '—' : _clock(r.passages.last);
      final gap = s.gap == null || s.rank == 1 ? '' : ' (+${_clock(s.gap!)})';
      lines.add('${s.rank}. ${r.name} : ${r.laps} tour(s), $total$gap');
      if (r.laps > 0) {
        lines.add('   Tours : ${r.lapTimes.map(_clock).join(' · ')}');
      }
    }
    if (lapLengthM != null) {
      lines.add(
        'Tour de ${lapLengthM.toStringAsFixed(2).replaceAll('.', ',')} m',
      );
    }
    return lines.join('\n');
  }
}

/// Passages cumulés d'un coureur depuis le départ.
class RunnerTimes {
  RunnerTimes(this.name);

  final String name;
  final passages = <Duration>[];

  int get laps => passages.length;

  bool isFinished(int targetLaps) => laps >= targetLaps;

  List<Duration> get lapTimes => [
    for (var i = 0; i < passages.length; i++)
      passages[i] - (i == 0 ? Duration.zero : passages[i - 1]),
  ];

  Duration? get bestLap =>
      lapTimes.isEmpty ? null : lapTimes.reduce((a, b) => a <= b ? a : b);
}

class Standing {
  const Standing({required this.rank, required this.runner, this.gap});

  final int rank;
  final RunnerTimes runner;
  final Duration? gap;
}

/// Nombre de tours pour couvrir [distanceM] (tour entamé = tour compté).
int lapsForDistance(double distanceM, double lapLengthM) {
  if (!(distanceM > 0) || !(lapLengthM > 0)) {
    throw ArgumentError('distance et longueur de tour doivent être > 0');
  }
  return (distanceM / lapLengthM - 1e-9).ceil();
}

String _clock(Duration d) {
  final tenths = (d.inMilliseconds / 100).round();
  final s = tenths ~/ 10;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')},${tenths % 10}';
}
