import '../training_paces.dart';

/// Distances courantes (m).
const commonRaceDistances = <(String, double)>[
  ('5 km', 5000),
  ('10 km', 10000),
  ('Semi', 21097.5),
  ('Marathon', 42195),
];

/// Ma course objectif.
class RaceGoal {
  const RaceGoal({
    required this.id,
    required this.name,
    required this.date,
    required this.distanceM,
    this.targetTime,
    this.courseId,
    this.debriefId,
    this.archived = false,
  });

  final String id;
  final String name;

  /// Jour de la course (l'heure est ignorée).
  final DateTime date;
  final double distanceM;
  final Duration? targetTime;

  /// Parcours du simulateur (GPX), facultatif.
  final String? courseId;

  /// Débrief de la course, une fois courue.
  final String? debriefId;

  /// Objectif passé (couru, abandonné ou remplacé).
  final bool archived;

  /// Allure visée (par km, arrondie à la seconde), `null` sans temps visé.
  Duration? get targetPace => targetTime == null
      ? null
      : Duration(seconds: (targetTime!.inSeconds / distanceM * 1000).round());

  /// Vitesse visée (km/h).
  double? get targetKmh => targetTime == null
      ? null
      : distanceM / 1000 / (targetTime!.inMilliseconds / 3600000);

  RaceGoal copyWith({
    String? name,
    DateTime? date,
    double? distanceM,
    Duration? Function()? targetTime,
    String? Function()? courseId,
    String? Function()? debriefId,
    bool? archived,
  }) => RaceGoal(
    id: id,
    name: name ?? this.name,
    date: date ?? this.date,
    distanceM: distanceM ?? this.distanceM,
    targetTime: targetTime == null ? this.targetTime : targetTime(),
    courseId: courseId == null ? this.courseId : courseId(),
    debriefId: debriefId == null ? this.debriefId : debriefId(),
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'date': date.toIso8601String(),
    'distanceM': distanceM,
    'targetS': ?targetTime?.inSeconds,
    'courseId': ?courseId,
    'debriefId': ?debriefId,
    'archived': archived,
  };

  static RaceGoal? fromJson(Map<String, Object?> json) {
    try {
      final target = json['targetS'] as int?;
      return RaceGoal(
        id: json['id']! as String,
        name: json['name']! as String,
        date: DateTime.parse(json['date']! as String),
        distanceM: (json['distanceM']! as num).toDouble(),
        targetTime: target == null ? null : Duration(seconds: target),
        courseId: json['courseId'] as String?,
        debriefId: json['debriefId'] as String?,
        archived: json['archived'] as bool? ?? false,
      );
    } on Object {
      return null;
    }
  }
}

/// Les 4 étapes de la préparation.
enum GoalPhase {
  evaluate('Évaluer'),
  train('S’entraîner'),
  raceDay('Course'),
  analyze('Analyser');

  const GoalPhase(this.label);
  final String label;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Jours jusqu'à la course (0 le jour J, négatif après).
int daysUntil(RaceGoal goal, DateTime today) =>
    _day(goal.date).difference(_day(today)).inDays;

/// Phase courante, déduite de la date :
/// - Analyser dès le lendemain de la course ;
/// - Jour J à partir de J-2 ;
/// - avant : Évaluer si les données sont à refaire ([needsEvaluation] :
///   VMA absente ou de plus de 8 semaines), S'entraîner sinon.
GoalPhase phaseOf(
  RaceGoal goal,
  DateTime today, {
  required bool needsEvaluation,
}) {
  final days = daysUntil(goal, today);
  if (days < 0) return GoalPhase.analyze;
  if (days <= 2) return GoalPhase.raceDay;
  return needsEvaluation ? GoalPhase.evaluate : GoalPhase.train;
}

/// « J-34 », « Jour J », « J+2 ».
String countdownText(RaceGoal goal, DateTime today) {
  final days = daysUntil(goal, today);
  if (days == 0) return 'Jour J';
  return days > 0 ? 'J-$days' : 'J+${-days}';
}

/// « 4'45/km » pour l'allure visée.
String? targetPaceText(RaceGoal goal) =>
    goal.targetPace == null ? null : '${formatPace(goal.targetPace!)}/km';
