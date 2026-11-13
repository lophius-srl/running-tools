import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/goal/race_goal.dart';
import '../common/date_text.dart';
import '../common/run_widgets.dart';
import '../course/course_text.dart';
import '../home/home_entry.dart';
import 'goal_editor_page.dart';
import 'goal_provider.dart';

/// Mon objectif : la course autour de laquelle s'organise la préparation.
class GoalPage extends ConsumerWidget {
  const GoalPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    RaceGoal? goal,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => GoalEditorPage(goal: goal)));
    ref.invalidate(goalStateProvider);
  }

  Future<void> _archive(WidgetRef ref, RaceGoal goal) async {
    final repo = await ref.read(goalRepositoryProvider.future);
    await repo.save(goal.copyWith(archived: true));
    ref.invalidate(goalStateProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(goalStateProvider).value;
    final goal = state?.goal;
    return Scaffold(
      body: Column(
        children: [
          const RunHeader(entry: HomeEntry.goal),
          Expanded(
            child: state == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (goal == null) ...[
                        const Text(
                          'Pas d’objectif : tu es en mode libre. Fixe une '
                          'course objectif pour que l’app organise ta '
                          'préparation : évaluer, s’entraîner, la course, '
                          'analyser.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _edit(context, ref, null),
                          icon: const Icon(Icons.flag),
                          label: const Text('Fixer un objectif'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                      ] else ...[
                        GoalCard(goal: goal, phase: state.phase!),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _edit(context, ref, goal),
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifier'),
                        ),
                        TextButton.icon(
                          onPressed: () => _archive(ref, goal),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text(
                            'Archiver (course passée ou abandonnée)',
                          ),
                        ),
                      ],
                      if (state.past.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Objectifs passés',
                          style: theme.textTheme.titleMedium,
                        ),
                        for (final g in state.past)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(g.name),
                            subtitle: Text(
                              '${formatDateTime(g.date).split(',').first} · '
                              '${formatKm(g.distanceM)}'
                              '${g.targetTime == null ? '' : ' · visé ${formatRaceTime(g.targetTime!.inSeconds.toDouble())}'}',
                            ),
                            trailing: g.debriefId == null
                                ? null
                                : const Icon(Icons.insights),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Carte de l'objectif : nom, date, compte à rebours, phase.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, required this.phase});

  final RaceGoal goal;
  final GoalPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const white = TextStyle(color: Colors.white);
    final target = goal.targetTime == null
        ? null
        : 'Objectif ${formatRaceTime(goal.targetTime!.inSeconds.toDouble())}'
              ' · ${targetPaceText(goal)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: HomeEntry.goal.gradient),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: theme.textTheme.titleLarge
                        ?.merge(white)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${formatDateTime(goal.date).split(',').first} · '
                    '${formatKm(goal.distanceM)}',
                    style: white,
                  ),
                  if (target != null) Text(target, style: white),
                  const SizedBox(height: 6),
                  Text(
                    'Étape : ${phase.label}',
                    style: white.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Text(
              countdownText(goal, DateTime.now()),
              style: theme.textTheme.headlineMedium
                  ?.merge(white)
                  .copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
