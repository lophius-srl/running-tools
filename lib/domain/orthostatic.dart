import 'dart:math';

/// D'où viennent les mesures de fréquence cardiaque.
enum HeartRateSourceKind {
  bluetooth('Ceinture Bluetooth'),
  health('Apple Santé'),
  manual('Comptage manuel');

  const HeartRateSourceKind(this.label);

  final String label;
}

/// Déroulé du test : allongé (stabilisation puis mesure), puis debout.
class OrthostaticProtocol {
  const OrthostaticProtocol({
    this.lying = const Duration(minutes: 3),
    this.standing = const Duration(minutes: 2),
    this.window = const Duration(seconds: 30),
  });

  /// Durée allongé ; la FC couché est mesurée sur la dernière [window].
  final Duration lying;

  /// Durée debout ; pic sur la première [window], stabilisation sur la
  /// dernière.
  final Duration standing;
  final Duration window;

  Duration get standUpAt => lying;
  Duration get total => lying + standing;
}

/// Un échantillon de FC, à [time] depuis le début du test.
typedef HeartRateSample = ({Duration time, int bpm});

/// Résultat d'un test orthostatique.
class OrthostaticResult {
  const OrthostaticResult({
    required this.date,
    required this.lyingBpm,
    required this.standingPeakBpm,
    required this.standingStableBpm,
    required this.source,
  });

  /// Calcule le résultat à partir d'échantillons continus (ceinture, Santé).
  /// `null` s'il manque des mesures dans une des trois fenêtres.
  static OrthostaticResult? fromSamples(
    List<HeartRateSample> samples, {
    required OrthostaticProtocol protocol,
    required DateTime date,
    required HeartRateSourceKind source,
  }) {
    List<int> within(Duration from, Duration to) => [
      for (final s in samples)
        if (s.time >= from && s.time < to) s.bpm,
    ];
    final lying = within(protocol.lying - protocol.window, protocol.lying);
    final peak = within(protocol.lying, protocol.lying + protocol.window);
    final stable = within(protocol.total - protocol.window, protocol.total);
    if (lying.isEmpty || peak.isEmpty || stable.isEmpty) return null;
    return OrthostaticResult(
      date: date,
      lyingBpm: _mean(lying),
      standingPeakBpm: peak.reduce(max),
      standingStableBpm: _mean(stable),
      source: source,
    );
  }

  /// Comptage manuel : pulsations comptées pendant 15 s, multipliées par 4.
  factory OrthostaticResult.fromCounts({
    required int lying15s,
    required int standingPeak15s,
    required int standingStable15s,
    required DateTime date,
  }) => OrthostaticResult(
    date: date,
    lyingBpm: lying15s * 4,
    standingPeakBpm: standingPeak15s * 4,
    standingStableBpm: standingStable15s * 4,
    source: HeartRateSourceKind.manual,
  );

  final DateTime date;
  final int lyingBpm;
  final int standingPeakBpm;
  final int standingStableBpm;
  final HeartRateSourceKind source;

  /// Écart debout (stabilisé) − couché : l'indicateur suivi.
  int get delta => standingStableBpm - lyingBpm;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'lying': lyingBpm,
    'peak': standingPeakBpm,
    'stable': standingStableBpm,
    'source': source.name,
  };

  static OrthostaticResult? fromJson(Map<String, Object?> json) {
    try {
      return OrthostaticResult(
        date: DateTime.parse(json['date']! as String),
        lyingBpm: json['lying']! as int,
        standingPeakBpm: json['peak']! as int,
        standingStableBpm: json['stable']! as int,
        source: HeartRateSourceKind.values.byName(json['source']! as String),
      );
    } on Object {
      return null;
    }
  }

  static int _mean(List<int> values) =>
      (values.reduce((a, b) => a + b) / values.length).round();
}

enum FormStatus {
  /// Moins de [OrthostaticBaseline.minTests] tests précédents.
  building,
  normal,
  watch,
}

/// Ma référence personnelle, à partir de mes tests précédents.
class OrthostaticBaseline {
  OrthostaticBaseline._(
    this.count,
    this.meanDelta,
    this.sdDelta,
    this.meanLying,
    this.sdLying,
  );

  /// Référence sur les [window] tests les plus récents de [previous].
  factory OrthostaticBaseline.of(
    List<OrthostaticResult> previous, {
    int window = 8,
  }) {
    final recent = ([
      ...previous,
    ]..sort((a, b) => b.date.compareTo(a.date))).take(window).toList();
    final deltas = [for (final r in recent) r.delta.toDouble()];
    final lyings = [for (final r in recent) r.lyingBpm.toDouble()];
    return OrthostaticBaseline._(
      recent.length,
      _mean(deltas),
      _sd(deltas),
      _mean(lyings),
      _sd(lyings),
    );
  }

  static const minTests = 3;

  /// Écart-type minimal, pour ne pas alerter sur 1 ou 2 battements.
  static const minSd = 3.0;

  final int count;
  final double meanDelta;
  final double sdDelta;
  final double meanLying;
  final double sdLying;

  /// « À surveiller » si l'écart OU la FC couché dépasse MA moyenne de plus
  /// de 2 écarts-types (jamais de seuil absolu).
  FormStatus statusOf(OrthostaticResult result) {
    if (count < minTests) return FormStatus.building;
    final deltaLimit = meanDelta + 2 * max(sdDelta, minSd);
    final lyingLimit = meanLying + 2 * max(sdLying, minSd);
    return result.delta > deltaLimit || result.lyingBpm > lyingLimit
        ? FormStatus.watch
        : FormStatus.normal;
  }

  static double _mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  static double _sd(List<double> v) {
    if (v.length < 2) return 0;
    final m = _mean(v);
    return sqrt(
      v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (v.length - 1),
    );
  }
}
