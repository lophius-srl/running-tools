import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../domain/checklist.dart';
import '../../domain/marker_spacing.dart';
import '../../domain/orthostatic.dart';
import '../../domain/stage_protocol.dart';
import '../common/decimal_text.dart';
import '../checklists/checklists_page.dart';
import '../checklists/race_checklist_page.dart';
import '../club/club_setup_page.dart';
import '../debrief/debriefs_page.dart';
import '../deck/decks_page.dart';
import '../fartlek/fartlek_setup_page.dart';
import '../history/history_page.dart';
import '../metronome/metronome_page.dart';
import '../course/courses_page.dart';
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
import 'home_summary.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _tab = HomeTab.tests;

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
      case HomeEntry.duo:
        page = const GhostPage(duo: true);
      case HomeEntry.simulator:
        page = const CoursesPage();
      case HomeEntry.debrief:
        page = const DebriefsPage();
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
    _push(context, page);
  }

  /// Ouvre un écran, puis rafraîchit le résumé au retour.
  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    ref.invalidate(homeSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(homeSummaryProvider).value;
    final entries = switch (_tab) {
      HomeTab.tests => [
        for (final e in _tab.entries)
          if (!HomeTab.vmaTests.contains(e)) e,
      ],
      _ => _tab.entries,
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          key: PageStorageKey(_tab),
          slivers: [
            SliverToBoxAdapter(child: _Header(summary: summary)),
            if (_tab == HomeTab.tests)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    for (final entry in HomeTab.vmaTests)
                      _TestCard(
                        entry: entry,
                        onTap: () => _open(context, entry),
                      ),
                  ],
                ),
              ),
            if (_tab == HomeTab.raceDay && summary?.nextRace != null)
              SliverToBoxAdapter(
                child: _NextRaceCard(
                  race: summary!.nextRace!,
                  onTap: () => _push(
                    context,
                    RaceChecklistPage(checklistId: summary.nextRace!.id),
                  ),
                ),
              ),
            if (_tab == HomeTab.me)
              SliverToBoxAdapter(
                child: _MeCards(
                  summary: summary,
                  onHistory: () => _open(context, HomeEntry.history),
                  onForm: () => _open(context, HomeEntry.orthostatic),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                _tab == HomeTab.tests ? 0 : 20,
                16,
                24,
              ),
              sliver: SliverList.list(
                children: [
                  for (final entry in entries)
                    _ToolCard(entry: entry, onTap: () => _open(context, entry)),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) =>
              setState(() => _tab = HomeTab.values[i]),
          destinations: [
            for (final t in HomeTab.values)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final HomeSummary? summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final test = summary?.lastTest;
    final form = summary?.form;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.blue, AppColors.sky],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_run, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Running Tools',
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderChip(
                    icon: Icons.speed,
                    text: test == null
                        ? 'Pas encore de VMA'
                        : 'VMA ${formatDecimal(test.vmaKmh)} km/h · '
                              '${agoText(test.date, now)}',
                  ),
                  if (form != null)
                    _HeaderChip(
                      icon: Icons.favorite,
                      text: 'Forme : ${formLabel(form.status)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Libellé court du statut de forme.
String formLabel(FormStatus status) => switch (status) {
  FormStatus.building => 'référence en cours',
  FormStatus.normal => 'normale',
  FormStatus.watch => 'à surveiller',
};

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Prochaine course : date et avancement de la checklist.
class _NextRaceCard extends StatelessWidget {
  const _NextRaceCard({required this.race, required this.onTap});

  final RaceChecklist race;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const white = TextStyle(color: Colors.white);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: HomeEntry.checklists.gradient),
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
                  Text(
                    'Prochaine course · ${untilText(race.raceDate, DateTime.now())}',
                    style: theme.textTheme.labelLarge?.merge(white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    race.raceName,
                    style: theme.textTheme.titleLarge
                        ?.merge(white)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: race.progress,
                    minHeight: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Checklist : ${race.checkedCount}/${race.items.length}',
                    style: white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dernière VMA et forme, en grand.
class _MeCards extends StatelessWidget {
  const _MeCards({
    required this.summary,
    required this.onHistory,
    required this.onForm,
  });

  final HomeSummary? summary;
  final VoidCallback onHistory;
  final VoidCallback onForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final test = summary?.lastTest;
    final form = summary?.form;
    Widget card({
      required String title,
      required String value,
      required String detail,
      required VoidCallback onTap,
    }) => Expanded(
      child: Card(
        color: theme.colorScheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card(
              title: 'Dernière VMA',
              value: test == null ? '–' : '${formatDecimal(test.vmaKmh)} km/h',
              detail: test == null
                  ? 'Fais un test pour la connaître'
                  : '${test.kind.label} · ${agoText(test.date, now)}',
              onTap: onHistory,
            ),
            const SizedBox(width: 12),
            card(
              title: 'Forme',
              value: form == null
                  ? '–'
                  : '${form.result.delta >= 0 ? '+' : ''}${form.result.delta} bpm',
              detail: form == null
                  ? 'Test orthostatique au réveil'
                  : '${formLabel(form.status)} · ${agoText(form.result.date, now)}',
              onTap: onForm,
            ),
          ],
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
