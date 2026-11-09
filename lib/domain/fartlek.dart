import 'dart:math';

/// Intensité annoncée des accélérations.
enum FartlekFeel { fast, veryFast }

/// Réglages d'un fartlek surprise (uniquement basé sur le temps).
class FartlekSettings {
  const FartlekSettings({
    this.total = const Duration(minutes: 40),
    this.warmup = const Duration(minutes: 10),
    this.cooldown = const Duration(minutes: 5),
    this.minGap = const Duration(minutes: 2),
    this.maxGap = const Duration(minutes: 6),
    this.minBurst = const Duration(seconds: 20),
    this.maxBurst = const Duration(minutes: 2),
    this.percentVma,
  });

  final Duration total;
  final Duration warmup;
  final Duration cooldown;

  /// Récupération entre deux accélérations (et avant la première).
  final Duration minGap;
  final Duration maxGap;
  final Duration minBurst;
  final Duration maxBurst;

  /// Allure cible en % VMA ; `null` : « vite / très vite » au hasard.
  final double? percentVma;

  List<String> get validationErrors => [
    if (warmup + cooldown >= total)
      'L’échauffement et le retour au calme dépassent la durée totale.',
    if (minGap <= Duration.zero || maxGap < minGap)
      'Intervalle entre accélérations invalide.',
    if (minBurst <= Duration.zero || maxBurst < minBurst)
      'Durée des accélérations invalide.',
    if (percentVma case final p? when p <= 0) '% VMA invalide.',
  ];

  bool get isValid => validationErrors.isEmpty;

  Map<String, Object?> toJson() => {
    'total': total.inSeconds,
    'warmup': warmup.inSeconds,
    'cooldown': cooldown.inSeconds,
    'minGap': minGap.inSeconds,
    'maxGap': maxGap.inSeconds,
    'minBurst': minBurst.inSeconds,
    'maxBurst': maxBurst.inSeconds,
    'percentVma': ?percentVma,
  };

  static FartlekSettings? fromJson(Map<String, Object?> json) {
    try {
      Duration s(String k) => Duration(seconds: json[k]! as int);
      return FartlekSettings(
        total: s('total'),
        warmup: s('warmup'),
        cooldown: s('cooldown'),
        minGap: s('minGap'),
        maxGap: s('maxGap'),
        minBurst: s('minBurst'),
        maxBurst: s('maxBurst'),
        percentVma: (json['percentVma'] as num?)?.toDouble(),
      );
    } on Object {
      return null;
    }
  }
}

/// Une accélération, à [start] après le départ.
class FartlekBurst {
  const FartlekBurst({required this.start, required this.duration, this.feel});

  final Duration start;
  final Duration duration;

  /// En mode ressenti : « vite » ou « très vite ».
  final FartlekFeel? feel;

  Duration get end => start + duration;
}

/// Séance tirée au hasard : même graine + mêmes réglages = même séance.
class FartlekPlan {
  FartlekPlan._(this.settings, this.seed, this.bursts);

  factory FartlekPlan.generate(FartlekSettings settings, int seed) {
    if (!settings.isValid) {
      throw ArgumentError(settings.validationErrors.join(' '));
    }
    final random = Random(seed);
    final end = settings.total - settings.cooldown;
    final bursts = <FartlekBurst>[];
    var t = settings.warmup + _draw(random, settings.minGap, settings.maxGap);
    while (t + settings.minBurst <= end) {
      var d = _draw(random, settings.minBurst, settings.maxBurst);
      if (t + d > end) d = end - t;
      bursts.add(
        FartlekBurst(
          start: t,
          duration: d,
          feel: settings.percentVma == null
              ? FartlekFeel.values[random.nextInt(2)]
              : null,
        ),
      );
      t += d + _draw(random, settings.minGap, settings.maxGap);
    }
    return FartlekPlan._(settings, seed, List.unmodifiable(bursts));
  }

  final FartlekSettings settings;
  final int seed;
  final List<FartlekBurst> bursts;

  Duration get total => settings.total;

  Duration get hardTime =>
      bursts.fold(Duration.zero, (sum, b) => sum + b.duration);

  /// Phase à [elapsed] depuis le départ.
  FartlekPhase phaseAt(Duration elapsed) {
    if (elapsed < settings.warmup) return FartlekPhase.warmup;
    if (elapsed >= total) return FartlekPhase.done;
    if (elapsed >= total - settings.cooldown) return FartlekPhase.cooldown;
    for (final b in bursts) {
      if (elapsed >= b.start && elapsed < b.end) return FartlekPhase.burst;
    }
    return FartlekPhase.easy;
  }

  /// Accélération en cours à [elapsed] ; `null` sinon.
  FartlekBurst? burstAt(Duration elapsed) =>
      bursts.where((b) => elapsed >= b.start && elapsed < b.end).firstOrNull;

  /// Tirage au pas de 5 s entre [min] et [max] inclus.
  static Duration _draw(Random random, Duration min, Duration max) {
    final steps = (max - min).inSeconds ~/ 5;
    return min + Duration(seconds: 5 * random.nextInt(steps + 1));
  }
}

enum FartlekPhase { warmup, easy, burst, cooldown, done }

/// Nouvelle graine lisible (6 chiffres).
int newFartlekSeed(Random random) => 100000 + random.nextInt(900000);
