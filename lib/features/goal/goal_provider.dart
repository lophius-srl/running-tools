import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/goal/race_goal.dart';
import '../../domain/zones/zone_inputs.dart';
import '../zones/zone_profile.dart';

/// L'objectif actif et sa phase ; `goal == null` en mode libre.
typedef GoalState = ({RaceGoal? goal, GoalPhase? phase, List<RaceGoal> past});

final goalStateProvider = FutureProvider<GoalState>((ref) async {
  final repo = await ref.read(goalRepositoryProvider.future);
  final all = await repo.all();
  final goal = all.where((g) => !g.archived).firstOrNull;
  final past = [
    for (final g in all)
      if (g.archived) g,
  ];
  if (goal == null) return (goal: null, phase: null, past: past);
  final profile = await ref.read(zoneProfileProvider.future);
  final now = DateTime.now();
  return (
    goal: goal,
    phase: phaseOf(
      goal,
      now,
      needsEvaluation: vmaReminder(profile.vma, now) != null,
    ),
    past: past,
  );
});
