import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../../domain/marker_spacing.dart';
import '../../domain/stage_protocol.dart';
import '../common/decimal_text.dart';
import '../checklists/checklists_page.dart';
import '../club/club_setup_page.dart';
import '../deck/decks_page.dart';
import '../fartlek/fartlek_setup_page.dart';
import '../history/history_page.dart';
import '../metronome/metronome_page.dart';
import '../ghost/ghost_page.dart';
import '../gps/gps_check_page.dart';
import '../orthostatic/orthostatic_page.dart';
import '../lane_calculator/lane_calculator_page.dart';
import '../multi_timer/multi_timer_setup_page.dart';
import '../setup_assistant/spacing_assistant_page.dart';
import '../workouts/workouts_page.dart';
import '../staged_setup/staged_setup_page.dart';
import '../timed_run/timed_run_page.dart';
import 'home_entry.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Mise en place depuis l'accueil : choisir l'espacement, puis le test.
  Future<void> _openSetupAssistant(BuildContext context) async {
    final navigator = Navigator.of(context);
    final choice = await navigator.push<SpacingChoice>(
      MaterialPageRoute(builder: (_) => const SpacingAssistantPage()),
    );
    if (choice == null || !context.mounted) return;
    final test = await showModalBottomSheet<StagedTest>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Repères tous les ${formatDecimal(choice.spacingM)} m : '
                'pour quel test ?',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final t in StagedTest.values)
              ListTile(
                leading: Icon(HomeEntry.ofStagedTest(t).icon),
                title: Text(t.label),
                onTap: () => Navigator.of(context).pop(t),
              ),
          ],
        ),
      ),
    );
    if (test == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => StagedSetupPage(test: test, initialChoice: choice),
      ),
    );
  }

  void _open(BuildContext context, HomeEntry entry) {
    final Widget page;
    switch (entry) {
      case HomeEntry.cooper || HomeEntry.halfCooper:
        page = TimedRunPage(test: entry.timedTest!);
      case HomeEntry.vameval || HomeEntry.lucLeger:
        page = StagedSetupPage(test: entry.stagedTest!);
      case HomeEntry.history:
        page = const HistoryPage();
      case HomeEntry.checklists:
        page = const ChecklistsPage();
      case HomeEntry.ghost:
        page = const GhostPage();
      case HomeEntry.gps:
        page = const GpsCheckPage();
      case HomeEntry.orthostatic:
        page = const OrthostaticPage();
      case HomeEntry.lanes:
        page = const LaneCalculatorPage();
      case HomeEntry.workouts:
        page = const WorkoutsPage();
      case HomeEntry.metronome:
        page = const MetronomePage();
      case HomeEntry.multiTimer:
        page = const MultiTimerSetupPage();
      case HomeEntry.club:
        page = const ClubSetupPage();
      case HomeEntry.fartlek:
        page = const FartlekSetupPage();
      case HomeEntry.deck:
        page = const DecksPage();
      case HomeEntry.setup:
        _openSetupAssistant(context);
        return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(child: section('Tests')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (final entry in HomeEntry.tests)
                    _TestCard(entry: entry, onTap: () => _open(context, entry)),
                ],
              ),
            ),
            SliverToBoxAdapter(child: section('Entraînement')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  for (final entry in HomeEntry.training)
                    _ToolCard(entry: entry, onTap: () => _open(context, entry)),
                ],
              ),
            ),
            SliverToBoxAdapter(child: section('Outils')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.list(
                children: [
                  for (final entry in HomeEntry.tools)
                    _ToolCard(entry: entry, onTap: () => _open(context, entry)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Running Tools',
                      style: textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Teste ta VMA et ton VO2max, seul.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_run,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({required this.entry, required this.onTap});

  final HomeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: entry.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: entry.gradient.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(entry.icon, color: Colors.white, size: 28),
                ),
                const Spacer(),
                Text(
                  entry.label,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.entry, required this.onTap});

  final HomeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: entry.gradient),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(entry.icon, color: Colors.white),
        ),
        title: Text(
          entry.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(entry.subtitle),
        trailing: Icon(Icons.chevron_right, color: scheme.primary),
        onTap: onTap,
      ),
    );
  }
}
