import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal/next_action.dart';
import '../../domain/marker_spacing.dart';
import '../../domain/stage_protocol.dart';
import '../checklists/checklists_page.dart';
import '../checklists/race_checklist_page.dart';
import '../club/club_setup_page.dart';
import '../common/decimal_text.dart';
import '../course/courses_page.dart';
import '../debrief/debriefs_page.dart';
import '../deck/decks_page.dart';
import '../fartlek/fartlek_setup_page.dart';
import '../ghost/ghost_page.dart';
import '../goal/goal_page.dart';
import '../goal/goal_provider.dart';
import '../gps/gps_check_page.dart';
import '../history/history_page.dart';
import '../lane_calculator/lane_calculator_page.dart';
import '../metronome/metronome_page.dart';
import '../multi_timer/multi_timer_setup_page.dart';
import '../orthostatic/orthostatic_page.dart';
import '../setup_assistant/spacing_assistant_page.dart';
import '../staged_setup/staged_setup_page.dart';
import '../timed_run/timed_run_page.dart';
import '../workouts/workouts_page.dart';
import '../zones/profile_page.dart';
import '../zones/zone_profile.dart';
import '../zones/zones_page.dart';
import 'dashboard_tab.dart';
import 'home_entry.dart';
import 'home_summary.dart';
import 'journey_tab.dart';
import 'me_tab.dart';

/// L'app : Accueil (mes chiffres), Ma prépa (le parcours), Moi.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _tab = HomeTab.home;

  /// Mise en place depuis l'accueil : choisir l'espacement, puis le test.
  Future<void> _openSetupAssistant() async {
    final navigator = Navigator.of(context);
    final choice = await navigator.push<SpacingChoice>(
      MaterialPageRoute(builder: (_) => const SpacingAssistantPage()),
    );
    if (choice == null || !mounted) return;
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
    _refresh();
  }

  void _open(HomeEntry entry) {
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
      case HomeEntry.goal:
        page = const GoalPage();
      case HomeEntry.profile:
        page = const ProfilePage();
      case HomeEntry.zones:
        page = const ZonesPage();
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
        _openSetupAssistant();
        return;
    }
    _push(page);
  }

  /// La prochaine action de l'accueil ouvre l'écran qui la réalise.
  void _act(NextAction action) {
    switch (action.kind) {
      case NextActionKind.testVma:
        // Le choix du test se fait dans le parcours.
        setState(() => _tab = HomeTab.journey);
      case NextActionKind.setGoal || NextActionKind.newGoal:
        _open(HomeEntry.goal);
      case NextActionKind.orthostatic:
        _open(HomeEntry.orthostatic);
      case NextActionKind.workout:
        _open(HomeEntry.workouts);
      case NextActionKind.racePlan:
        _open(HomeEntry.simulator);
      case NextActionKind.debrief:
        _open(HomeEntry.debrief);
      case NextActionKind.checklist:
        final race = ref.read(homeSummaryProvider).value?.nextRace;
        if (race == null) {
          _open(HomeEntry.checklists);
        } else {
          _push(RaceChecklistPage(checklistId: race.id));
        }
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    _refresh();
  }

  /// Au retour d'un écran, les données de l'accueil ont pu changer.
  void _refresh() => ref
    ..invalidate(homeSummaryProvider)
    ..invalidate(zoneProfileProvider)
    ..invalidate(goalStateProvider);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: switch (_tab) {
        HomeTab.home => DashboardTab(onOpen: _open, onAction: _act),
        HomeTab.journey => JourneyTab(onOpen: _open),
        HomeTab.me => MeTab(onOpen: _open),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = HomeTab.values[i]),
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
