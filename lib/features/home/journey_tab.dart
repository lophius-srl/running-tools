import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../goal/goal_provider.dart';
import '../zones/zone_profile.dart';
import 'dashboard_tab.dart';
import 'home_entry.dart';
import 'home_widgets.dart';

/// Ma prépa : les 4 étapes, de l'évaluation au débrief.
class JourneyTab extends ConsumerWidget {
  const JourneyTab({super.key, required this.onOpen});

  final EntryOpener onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(goalStateProvider).value;
    final profile = ref.watch(zoneProfileProvider).value;
    // Sans objectif : évaluer tant qu'il n'y a pas de VMA, puis s'entraîner.
    final current = goal?.phase != null
        ? stageOf(goal!.phase!)
        : profile?.vma == null
        ? JourneyStage.evaluate
        : JourneyStage.train;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(goalName: goal?.goal?.name)),
          for (final stage in JourneyStage.values)
            SliverToBoxAdapter(
              child: _StageCard(
                stage: stage,
                current: stage == current,
                done: stage.index < current.index,
                last: stage == JourneyStage.values.last,
                onOpen: onOpen,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.goalName});

  final String? goalName;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.navy, AppColors.blue, AppColors.sky],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ma prépa',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            Text(
              goalName == null
                  ? 'Évaluer, s’entraîner, courir, analyser : et on '
                        'recommence.'
                  : 'Vers « $goalName »',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Une étape : numéro sur la frise, question, écrans en tuiles.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.current,
    required this.done,
    required this.last,
    required this.onOpen,
  });

  final JourneyStage stage;
  final bool current;
  final bool done;
  final bool last;
  final EntryOpener onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = stage.gradient.last;
    return Stack(
      children: [
        // Trait de la frise vers l'étape suivante, derrière la carte.
        if (!last)
          Positioned(
            left: 26.5,
            top: 38,
            bottom: 0,
            child: Container(
              width: 3,
              color: done ? accent : theme.colorScheme.outlineVariant,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: current || done
                        ? LinearGradient(colors: stage.gradient)
                        : null,
                    border: current || done
                        ? null
                        : Border.all(color: theme.colorScheme.outline),
                    color: current || done
                        ? null
                        : theme.colorScheme.surfaceContainerLowest,
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${stage.index + 1}',
                          style: TextStyle(
                            color: current
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 16, 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: current
                        ? null
                        : theme.colorScheme.surfaceContainerLowest,
                    gradient: current
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              for (final c in stage.gradient)
                                c.withValues(alpha: 0.12),
                            ],
                          )
                        : null,
                    border: current
                        ? Border.all(color: accent, width: 2)
                        : null,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(stage.icon, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stage.label,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (current)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Tu es ici',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(stage.question, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      EntryGrid(
                        entries: stage.entries,
                        onOpen: onOpen,
                        // Sur une carte blanche, des tuiles teintées.
                        tileColor: current
                            ? null
                            : theme.scaffoldBackgroundColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
