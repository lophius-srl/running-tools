import 'race_goal.dart';

/// Ce qu'il y a de plus utile à faire maintenant.
enum NextActionKind {
  setGoal,
  testVma,
  orthostatic,
  workout,
  checklist,
  racePlan,
  debrief,
  newGoal,
}

class NextAction {
  const NextAction(this.kind, this.title, this.detail);

  final NextActionKind kind;
  final String title;
  final String detail;
}

/// Ce que l'on sait au moment de choisir.
class ActionContext {
  const ActionContext({
    required this.today,
    this.goal,
    this.phase,
    this.vmaDate,
    this.lastOrthostatic,
    this.checklist,
    this.hasRacePlan = false,
  });

  final DateTime today;
  final RaceGoal? goal;
  final GoalPhase? phase;

  /// Date de la VMA utilisée, `null` sans VMA.
  final DateTime? vmaDate;
  final DateTime? lastOrthostatic;

  /// Checklist de la course : cochés / total.
  final ({int done, int total})? checklist;

  /// Le simulateur a un parcours pour l'objectif.
  final bool hasRacePlan;
}

/// Une seule action, la plus utile, selon la phase et les données :
/// 1. pas de VMA → un test (sans elle, pas d'allures) ;
/// 2. Analyser : lire le débrief de la course, puis fixer le prochain
///    objectif ;
/// 3. Jour J : la checklist si elle n'est pas finie, sinon le plan de course ;
/// 4. VMA de plus de 8 semaines → refaire un test (sauf en fin de prépa) ;
/// 5. sans objectif → en fixer un ;
/// 6. pas de mesure de forme depuis 7 jours → test orthostatique ;
/// 7. sinon, la séance du jour.
NextAction nextAction(ActionContext c) {
  final goal = c.goal;
  final days = goal == null ? null : daysUntil(goal, c.today);
  if (c.vmaDate == null) {
    return const NextAction(
      NextActionKind.testVma,
      'Fais un test de VMA',
      'Il calcule tes allures et tes zones d’entraînement.',
    );
  }
  if (goal != null && c.phase == GoalPhase.analyze) {
    return goal.debriefId == null
        ? NextAction(
            NextActionKind.debrief,
            'Lis le débrief de ta course',
            'Importe ta sortie « ${goal.name} » : ce qui a marché, ce qui '
                'a coûté.',
          )
        : const NextAction(
            NextActionKind.newGoal,
            'Fixe ton prochain objectif',
            'Un nouveau cycle commence : test, entraînement, course.',
          );
  }
  if (goal != null && c.phase == GoalPhase.raceDay) {
    final when = days == 0
        ? 'C’est aujourd’hui'
        : 'Course dans $days jour${days == 1 ? '' : 's'}';
    final list = c.checklist;
    if (list == null || list.done < list.total) {
      return NextAction(
        NextActionKind.checklist,
        '$when : ta checklist',
        list == null
            ? 'Prépare la liste de ce qu’il ne faut pas oublier.'
            : '${list.done} sur ${list.total} déjà prêts.',
      );
    }
    return NextAction(
      NextActionKind.racePlan,
      '$when : ton plan de course',
      c.hasRacePlan
          ? 'Revois tes allures par section.'
          : 'Ajoute le parcours pour un plan section par section.',
    );
  }
  final weeks = c.today.difference(c.vmaDate!).inDays ~/ 7;
  if (weeks >= 8) {
    return NextAction(
      NextActionKind.testVma,
      'Ta VMA date de $weeks semaines',
      'Refais un test pour garder des zones justes.',
    );
  }
  if (goal == null) {
    return const NextAction(
      NextActionKind.setGoal,
      'Fixe ta course objectif',
      'L’app organise alors ta préparation jusqu’au jour J.',
    );
  }
  final ortho = c.lastOrthostatic;
  if (ortho == null || c.today.difference(ortho).inDays >= 7) {
    return const NextAction(
      NextActionKind.orthostatic,
      'Mesure ta forme',
      'Test orthostatique au réveil : 5 minutes allongé puis debout.',
    );
  }
  return NextAction(
    NextActionKind.workout,
    'Séance du jour',
    days == null
        ? 'Choisis ta séance, allures calées sur ta VMA.'
        : 'Encore $days jours avant « ${goal.name} ».',
  );
}
