import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../domain/goal/next_action.dart';
import '../../domain/goal/race_goal.dart';
import '../../domain/orthostatic.dart';
import '../../domain/zones/zones.dart';
import '../common/decimal_text.dart';
import '../course/course_text.dart';
import '../goal/goal_provider.dart';
import '../zones/zone_badge.dart';
import '../zones/zone_profile.dart';
import 'home_entry.dart';
import 'home_summary.dart';
import 'home_widgets.dart';

/// L'étape du parcours qui correspond à une phase.
JourneyStage stageOf(GoalPhase phase) => switch (phase) {
  GoalPhase.evaluate => JourneyStage.evaluate,
  GoalPhase.train => JourneyStage.train,
  GoalPhase.raceDay => JourneyStage.race,
  GoalPhase.analyze => JourneyStage.analyze,
};

/// Accueil : mes chiffres, mon objectif, la prochaine action.
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key, required this.onOpen, required this.onAction});

  final EntryOpener onOpen;
  final ValueChanged<NextAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider).value;
    final goal = ref.watch(goalStateProvider).value;
    final profile = ref.watch(zoneProfileProvider).value;
    final now = DateTime.now();
    final race = summary?.nextRace;
    final action = nextAction(
      ActionContext(
        today: now,
        goal: goal?.goal,
        phase: goal?.phase,
        vmaDate: profile?.vma?.date,
        lastOrthostatic: summary?.form?.result.date,
        checklist: race == null
            ? null
            : (done: race.checkedCount, total: race.items.length),
      ),
    );
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Hero(profile: profile, summary: summary),
        ),
        SliverToBoxAdapter(
          child: _GoalCard(
            goal: goal?.goal,
            phase: goal?.phase,
            action: action,
            onAction: () => onAction(action),
            onGoal: () => onOpen(HomeEntry.goal),
          ),
        ),
        if (profile != null &&
            (profile.zones.hasPace || profile.zones.hasHeartRate))
          SliverToBoxAdapter(
            child: _ZonesCard(
              profile: profile,
              goal: goal?.goal,
              onTap: () => onOpen(HomeEntry.zones),
            ),
          ),
        SliverToBoxAdapter(
          child: _FormCard(
            summary: summary,
            onTap: () => onOpen(HomeEntry.orthostatic),
          ),
        ),
        if (summary?.lastDebrief case final d?)
          SliverToBoxAdapter(
            child: DashCard(
              title: 'Dernier débrief',
              onTap: () => onOpen(HomeEntry.debrief),
              child: Row(
                children: [
                  _ScoreRing(score: d.score),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${formatKm(d.distanceM)} · ${agoText(d.date, now)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (d.findings.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            d.findings.first,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// En-tête : bonjour, la date, et mes trois chiffres.
class _Hero extends StatelessWidget {
  const _Hero({required this.profile, required this.summary});

  final ZoneProfile? profile;
  final HomeSummary? summary;

  @override
  Widget build(BuildContext context) {
    final vma = profile?.vma;
    final rest = profile?.restHeartRate;
    final max = profile?.maxHeartRate;
    Widget stat(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return PageHeader(
      overline: longDate(DateTime.now()),
      title: 'Bonjour',
      child: Row(
        children: [
          stat('VMA', vma == null ? '–' : '${formatDecimal(vma.value)} km/h'),
          const SizedBox(width: AppSpace.s),
          stat('FC repos', rest == null ? '–' : '${rest.value} bpm'),
          const SizedBox(width: AppSpace.s),
          stat('FC max', max == null ? '–' : '${max.value} bpm'),
        ],
      ),
    );
  }
}

/// L'objectif : compte à rebours, frise des 4 étapes, prochaine action.
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.phase,
    required this.action,
    required this.onAction,
    required this.onGoal,
  });

  final RaceGoal? goal;
  final GoalPhase? phase;
  final NextAction action;
  final VoidCallback onAction;
  final VoidCallback onGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = goal;
    final current = phase == null ? null : stageOf(phase!);
    const white = TextStyle(color: Colors.white);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.m),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.brand,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onGoal,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g == null ? 'Pas encore d’objectif' : g.name,
                            style: theme.textTheme.titleLarge
                                ?.merge(white)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            g == null
                                ? 'Mode libre'
                                : '${formatKm(g.distanceM)}'
                                      '${g.targetTime == null ? '' : ' · objectif ${formatRaceTime(g.targetTime!.inSeconds.toDouble())}'}',
                            style: white.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (g != null)
                      Text(
                        countdownText(g, DateTime.now()),
                        style: theme.textTheme.headlineMedium
                            ?.merge(white)
                            .copyWith(fontWeight: FontWeight.w900),
                      ),
                  ],
                ),
              ),
              if (current != null) ...[
                const SizedBox(height: 16),
                JourneyStepper(current: current),
              ],
              const SizedBox(height: 16),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.m),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.title,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                action.detail,
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frise des 4 étapes : faites, en cours, à venir.
class JourneyStepper extends StatelessWidget {
  const JourneyStepper({super.key, required this.current});

  final JourneyStage current;

  @override
  Widget build(BuildContext context) {
    final stages = JourneyStage.values;
    return Row(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : Colors.white.withValues(
                                alpha: i <= current.index ? 0.9 : 0.3,
                              ),
                      ),
                    ),
                    Container(
                      width: i == current.index ? 28 : 18,
                      height: i == current.index ? 28 : 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current.index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                      child: i < current.index
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: AppColors.blue,
                            )
                          : i == current.index
                          ? Icon(
                              stages[i].icon,
                              size: 16,
                              color: AppColors.blue,
                            )
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == stages.length - 1
                            ? Colors.transparent
                            : Colors.white.withValues(
                                alpha: i < current.index ? 0.9 : 0.3,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  stages[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: i == current.index ? 1 : 0.75,
                    ),
                    fontSize: 12,
                    fontWeight: i == current.index
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Mes zones en ruban, et les deux qui comptent le plus.
class _ZonesCard extends StatelessWidget {
  const _ZonesCard({
    required this.profile,
    required this.goal,
    required this.onTap,
  });

  final ZoneProfile profile;
  final RaceGoal? goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zones = profile.zones;
    final targetKmh = goal?.targetKmh;
    final targetZone = targetKmh == null ? null : zones.zoneForSpeed(targetKmh);
    return DashCard(
      title: 'Mes zones',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.hasUnseenChange && profile.lastChanges.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpace.m),
              padding: const EdgeInsets.all(AppSpace.m),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Row(
                children: [
                  const Icon(Icons.update, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tes zones ont changé · '
                      '${profile.lastChanges.firstWhere((c) => c.zone == ZoneId.z2, orElse: () => profile.lastChanges.first).text}',
                    ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Row(
              children: [
                for (final id in ZoneId.values)
                  Expanded(
                    child: Container(
                      height: 26,
                      color: zoneColor(id),
                      alignment: Alignment.center,
                      child: Text(
                        id.short,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Endurance', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          ZoneBadge(zone: ZoneId.z2, zones: zones),
          if (targetZone != null) ...[
            const SizedBox(height: 10),
            Text(
              'Allure objectif ${targetPaceText(goal!)}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            ZoneBadge(zone: targetZone, zones: zones),
          ],
        ],
      ),
    );
  }
}

/// Ma forme : le dernier test orthostatique.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.summary, required this.onTap});

  final HomeSummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = summary?.form;
    final (label, color, icon) = switch (form?.status) {
      null => (
        'Pas encore mesurée',
        theme.colorScheme.outline,
        Icons.favorite_border,
      ),
      FormStatus.building => (
        'Référence en construction',
        theme.colorScheme.primary,
        Icons.favorite,
      ),
      FormStatus.normal => (
        'Dans ta normale',
        const Color(0xFF15803D),
        Icons.favorite,
      ),
      FormStatus.watch => (
        'À surveiller : vas-y doucement',
        theme.colorScheme.error,
        Icons.warning_amber,
      ),
    };
    return DashCard(
      title: 'Ma forme',
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                Text(
                  form == null
                      ? 'Test orthostatique au réveil, 5 minutes.'
                      : 'Écart couché-debout '
                            '${form.result.delta >= 0 ? '+' : ''}${form.result.delta} bpm · '
                            '${agoText(form.result.date, DateTime.now())}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Note d'un débrief dans un anneau.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? const Color(0xFF15803D)
        : score >= 70
        ? const Color(0xFF1E63E9)
        : score >= 50
        ? const Color(0xFFB45309)
        : const Color(0xFFDC2626);
    return SizedBox.square(
      dimension: 56,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Center(
            child: Text(
              '$score',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
