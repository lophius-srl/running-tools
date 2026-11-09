/// Une répétition : une distance OU une durée, à un pourcentage de VMA.
class Effort {
  const Effort.distance(double this.distanceM, {this.percentVma})
    : duration = null;

  const Effort.time(Duration this.duration, {this.percentVma})
    : distanceM = null;

  final double? distanceM;
  final Duration? duration;

  /// `null` pour un effort sans allure cible (ex. côtes).
  final double? percentVma;

  bool get isDistance => distanceM != null;

  Map<String, Object?> toJson() => {
    'distanceM': ?distanceM,
    'seconds': ?duration?.inSeconds,
    'percentVma': ?percentVma,
  };

  static Effort fromJson(Map<String, Object?> json) {
    final percent = (json['percentVma'] as num?)?.toDouble();
    final distance = (json['distanceM'] as num?)?.toDouble();
    return distance != null
        ? Effort.distance(distance, percentVma: percent)
        : Effort.time(
            Duration(seconds: json['seconds']! as int),
            percentVma: percent,
          );
  }
}

/// Récupération après une répétition : une durée OU une distance trottinée.
class Recovery {
  const Recovery.time(Duration this.duration) : distanceM = null;

  const Recovery.distance(double this.distanceM) : duration = null;

  /// Allure de trot pour une récupération en distance.
  static const joggingPercentVma = 50.0;

  final Duration? duration;
  final double? distanceM;

  Map<String, Object?> toJson() => {
    'seconds': ?duration?.inSeconds,
    'distanceM': ?distanceM,
  };

  static Recovery fromJson(Map<String, Object?> json) {
    final distance = (json['distanceM'] as num?)?.toDouble();
    return distance != null
        ? Recovery.distance(distance)
        : Recovery.time(Duration(seconds: json['seconds']! as int));
  }
}

/// [reps] répétitions identiques, chacune suivie de [recovery].
class WorkoutSet {
  const WorkoutSet({required this.reps, required this.effort, this.recovery});

  final int reps;
  final Effort effort;
  final Recovery? recovery;

  Map<String, Object?> toJson() => {
    'reps': reps,
    'effort': effort.toJson(),
    if (recovery case final r?) 'recovery': r.toJson(),
  };

  static WorkoutSet fromJson(Map<String, Object?> json) => WorkoutSet(
    reps: json['reps']! as int,
    effort: Effort.fromJson(json['effort']! as Map<String, Object?>),
    recovery: switch (json['recovery']) {
      final Map<String, Object?> r => Recovery.fromJson(r),
      _ => null,
    },
  );
}

/// Une séance : une suite de séries.
class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.sets,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final List<WorkoutSet> sets;

  /// Séance de la bibliothèque (non modifiable, mais duplicable).
  final bool builtIn;

  int get effortCount => sets.fold(0, (sum, s) => sum + s.reps);

  /// Toutes les répétitions sont en distance : le lièvre sonore s'applique.
  bool get isDistanceBased => sets.every((s) => s.effort.isDistance);

  Workout copyWith({String? id, String? name, List<WorkoutSet>? sets}) =>
      Workout(
        id: id ?? this.id,
        name: name ?? this.name,
        sets: sets ?? this.sets,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sets': [for (final s in sets) s.toJson()],
  };

  /// `null` si le format est inattendu.
  static Workout? fromJson(Map<String, Object?> json) {
    try {
      return Workout(
        id: json['id']! as String,
        name: json['name']! as String,
        sets: [
          for (final s in json['sets']! as List)
            WorkoutSet.fromJson(s as Map<String, Object?>),
        ],
      );
    } on Object {
      return null;
    }
  }
}
