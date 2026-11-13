import 'package:flutter/widgets.dart';

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:running_tools/audio/beep_player.dart';
import 'package:running_tools/audio/cadence_coach.dart';
import 'package:running_tools/audio/live_voice.dart';
import 'package:running_tools/audio/providers.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/track_service.dart';
import 'package:running_tools/data/checklist_repository.dart';
import 'package:running_tools/data/course_repository.dart';
import 'package:running_tools/data/debrief_repository.dart';
import 'package:running_tools/data/deck_repository.dart';
import 'package:running_tools/data/fartlek_repository.dart';
import 'package:running_tools/data/ghost_repository.dart';
import 'package:running_tools/data/goal_repository.dart';
import 'package:running_tools/data/history_repository.dart';
import 'package:running_tools/data/orthostatic_repository.dart';
import 'package:running_tools/data/preferences_repository.dart';
import 'package:running_tools/data/profile_repository.dart';
import 'package:running_tools/data/providers.dart';
import 'package:running_tools/data/recent_names_repository.dart';
import 'package:running_tools/data/setup_repository.dart';
import 'package:running_tools/data/workout_repository.dart';
import 'package:running_tools/device/accelerometer.dart';
import 'package:running_tools/device/heart_rate_history.dart';
import 'package:running_tools/device/heart_rate_monitor.dart';
import 'package:running_tools/device/location_source.dart';
import 'package:running_tools/device/race_clock.dart';
import 'package:running_tools/device/reminder_scheduler.dart';
import 'package:running_tools/device/screen_wake_lock.dart';
import 'package:running_tools/device/share_service.dart';
import 'package:running_tools/domain/cadence_advice.dart';
import 'package:running_tools/domain/checklist.dart';
import 'package:running_tools/domain/debrief/debrief_summary.dart';
import 'package:running_tools/domain/deck.dart';
import 'package:running_tools/domain/ghost.dart';
import 'package:running_tools/domain/goal/race_goal.dart';
import 'package:running_tools/domain/gps_tracker.dart';
import 'package:running_tools/domain/marker_spacing.dart';
import 'package:running_tools/domain/orthostatic.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/domain/workout.dart';
import 'package:running_tools/domain/zones/zones.dart';
import 'package:running_tools/measure/distance_measurer.dart';

/// Dépôt de réglages en mémoire.
class FakeSetupRepository implements SetupRepository {
  final saved = <StagedTest, StagedTestSetup>{};

  @override
  Future<StagedTestSetup?> load(StagedTest test) async => saved[test];

  @override
  Future<void> save(StagedTestSetup setup) async => saved[setup.test] = setup;
}

class FakePreferencesRepository implements PreferencesRepository {
  bool duck = true;

  @override
  Future<bool> duckOthers() async => duck;

  @override
  Future<void> setDuckOthers(bool value) async => duck = value;

  double? shoeLength;

  @override
  Future<double?> shoeLengthM() async => shoeLength;

  @override
  Future<void> setShoeLengthM(double value) async => shoeLength = value;

  int? maxHr;

  @override
  Future<int?> maxHeartRate() async => maxHr;

  DateTime? maxHrDate;

  @override
  Future<DateTime?> maxHeartRateDate() async => maxHrDate;

  @override
  Future<void> setMaxHeartRate(int value) async => maxHr = value;
}

/// Piste instantanée, sans audio.
class FakeTrackService implements TrackService {
  final programs = <AudioProgram>[];

  @override
  Future<PreparedTrack> prepare(
    AudioProgram program, {
    void Function(String step)? onProgress,
  }) async {
    programs.add(program);
    return PreparedTrack(path: 'fake.wav', program: program);
  }
}

/// Lecteur piloté par le test.
class FakeBeepPlayer implements BeepPlayer {
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);
  final calls = <String>[];
  bool? duckOthers;
  @override
  Duration position = Duration.zero;

  void emitPosition(Duration value) {
    position = value;
    _position.add(value);
  }

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> configure({required bool duckOthers}) async =>
      this.duckOthers = duckOthers;

  @override
  Future<void> load(String path) async => calls.add('load $path');

  @override
  Future<void> play() async {
    calls.add('play');
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async => emitPosition(position);

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playing.add(false);
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class FakeHistoryRepository implements TestHistoryRepository {
  final records = <TestRecord>[];

  @override
  Future<List<TestRecord>> all() async =>
      [...records]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> add(TestRecord record) async => records.add(record);

  @override
  Future<void> delete(String id) async =>
      records.removeWhere((r) => r.id == id);
}

class FakeWorkoutRepository implements WorkoutRepository {
  final workouts = <Workout>[];

  @override
  Future<List<Workout>> all() async => [...workouts];

  @override
  Future<void> save(Workout workout) async {
    workouts
      ..removeWhere((w) => w.id == workout.id)
      ..add(workout);
  }

  @override
  Future<void> delete(String id) async =>
      workouts.removeWhere((w) => w.id == id);
}

class FakeCadenceCoach implements CadenceCoach {
  final said = <CadenceAdvice>[];
  var prepared = false;

  @override
  Future<void> prepare() async => prepared = true;

  @override
  Future<void> say(CadenceAdvice advice) async => said.add(advice);

  @override
  Future<void> dispose() async {}
}

/// Accéléromètre piloté par le test.
class FakeAccelerometer implements AccelerometerSource {
  final controller = StreamController<AccelSample>.broadcast(sync: true);

  @override
  Stream<AccelSample> samples() => controller.stream;
}

/// Horloge pilotée par le test.
class FakeRaceClock implements RaceClock {
  var started = false;
  @override
  Duration elapsed = Duration.zero;

  @override
  void start() => started = true;
}

class FakeShareService implements ShareService {
  final shared = <String>[];

  @override
  Future<void> shareText(String text, {String? subject}) async =>
      shared.add(text);
}

class FakeRecentNamesRepository implements RecentNamesRepository {
  var names = <String>[];

  @override
  Future<List<String>> recent() async => [...names];

  @override
  Future<void> remember(List<String> added) async => names = [
    ...added,
    for (final n in names)
      if (!added.contains(n)) n,
  ];
}

class FakeChecklistRepository implements ChecklistRepository {
  final customTemplates = <ChecklistTemplate>[];
  final raceList = <RaceChecklist>[];

  @override
  Future<List<ChecklistTemplate>> templates() async => [...customTemplates];

  @override
  Future<void> saveTemplate(ChecklistTemplate template) async {
    customTemplates
      ..removeWhere((t) => t.id == template.id)
      ..add(template);
  }

  @override
  Future<void> deleteTemplate(String id) async =>
      customTemplates.removeWhere((t) => t.id == id);

  @override
  Future<List<RaceChecklist>> races() async =>
      [...raceList]..sort((a, b) => a.raceDate.compareTo(b.raceDate));

  @override
  Future<void> saveRace(RaceChecklist race) async {
    final i = raceList.indexWhere((r) => r.id == race.id);
    i >= 0 ? raceList[i] = race : raceList.add(race);
  }

  @override
  Future<void> deleteRace(String id) async =>
      raceList.removeWhere((r) => r.id == id);
}

class FakeReminderScheduler implements ReminderScheduler {
  final scheduled = <int, ({DateTime at, String payload})>{};
  var granted = true;

  @override
  Future<void> init(void Function(String payload) onOpen) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!granted) return false;
    scheduled[id] = (at: at, payload: payload);
    return true;
  }

  final weekly = <int, ({int weekday, int hour, int minute, String payload})>{};

  @override
  Future<bool> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!granted) return false;
    weekly[id] = (
      weekday: weekday,
      hour: hour,
      minute: minute,
      payload: payload,
    );
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    weekly.remove(id);
  }
}

class FakeFartlekRepository implements FartlekRepository {
  final list = <RecentFartlek>[];

  @override
  Future<List<RecentFartlek>> recent() async => [...list];

  @override
  Future<void> remember(RecentFartlek fartlek) async => list.insert(0, fartlek);
}

class FakeDeckRepository implements DeckRepository {
  final decks = <Deck>[];

  @override
  Future<List<Deck>> all() async => [...decks];

  @override
  Future<void> save(Deck deck) async {
    decks
      ..removeWhere((d) => d.id == deck.id)
      ..add(deck);
  }

  @override
  Future<void> delete(String id) async => decks.removeWhere((d) => d.id == id);
}

class FakeOrthostaticRepository implements OrthostaticRepository {
  final results = <OrthostaticResult>[];
  ({int weekday, int hour, int minute})? savedReminder;

  @override
  Future<List<OrthostaticResult>> all() async =>
      [...results]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> add(OrthostaticResult result) async => results.add(result);

  @override
  Future<void> delete(DateTime date) async =>
      results.removeWhere((r) => r.date == date);

  @override
  Future<({int weekday, int hour, int minute})?> reminder() async =>
      savedReminder;

  @override
  Future<void> setReminder(
    ({int weekday, int hour, int minute})? value,
  ) async => savedReminder = value;
}

class FakeScreenWakeLock implements ScreenWakeLock {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}

/// Mesure instantanée : renvoie [result] sans ouvrir la caméra.
class FakeDistanceMeasurer implements DistanceMeasurer {
  FakeDistanceMeasurer(this.result);

  final SpacingChoice? result;
  double? requestedSpacing;

  @override
  Future<SpacingChoice?> measure(
    BuildContext context, {
    required double initialSpacingM,
  }) async {
    requestedSpacing = initialSpacingM;
    return result;
  }
}

class FakeHeartRateMonitor implements HeartRateMonitor {
  final _bpm = StreamController<int>.broadcast(sync: true);
  final calls = <String>[];
  static const belt = HeartRateDevice(id: 'belt-1', name: 'Ceinture test');

  void emit(int bpm) => _bpm.add(bpm);

  @override
  Stream<List<HeartRateDevice>> scan() => Stream.value(const [belt]);

  @override
  Future<void> stopScan() async => calls.add('stopScan');

  @override
  Future<void> connect(HeartRateDevice device) async =>
      calls.add('connect ${device.id}');

  @override
  Stream<int> get bpm => _bpm.stream;

  @override
  Future<void> disconnect() async => calls.add('disconnect');
}

class FakeHeartRateHistory implements HeartRateHistory {
  var authorized = true;

  /// Mesures, décalées par rapport au début de la période demandée.
  final readings = <({Duration offset, int bpm})>[];
  (DateTime, DateTime)? lastQuery;

  @override
  Future<bool> authorize() async => authorized;

  @override
  Future<List<DatedHeartRate>> between(DateTime start, DateTime end) async {
    lastQuery = (start, end);
    return [for (final r in readings) (at: start.add(r.offset), bpm: r.bpm)];
  }
}

class FakeLocationSource implements LocationSource {
  var access = LocationAccess.granted;
  StreamController<GpsFix>? _fixes;

  bool get tracking => _fixes?.hasListener ?? false;

  void emit(GpsFix fix) => _fixes!.add(fix);

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Stream<GpsFix> fixes() =>
      (_fixes = StreamController<GpsFix>(sync: true)).stream;
}

class FakeLiveVoice implements LiveVoice {
  final said = <String>[];

  @override
  Future<void> say(String text) async => said.add(text);

  @override
  Future<void> dispose() async {}
}

class FakeGhostRepository implements GhostRepository {
  final summaries = <GhostRunSummary>[];
  final ghosts = <String, Ghost>{};
  final friends = <String, String>{};
  var _next = 0;

  @override
  Future<List<GhostRunSummary>> runs() async => summaries.reversed.toList();

  @override
  Future<void> addRun(GhostRunSummary run) async => summaries.add(run);

  @override
  Future<List<SavedGhost>> saved() async => [
    for (final MapEntry(:key, :value) in ghosts.entries)
      SavedGhost(
        id: key,
        name: value.name,
        distanceM: value.totalDistanceM!,
        timeS: value.totalTimeS!,
        friend: friends[key],
      ),
  ];

  @override
  Future<SavedGhost> save(Ghost ghost, {String? friend}) async {
    final id = 'g${_next++}';
    ghosts[id] = ghost;
    if (friend != null) friends[id] = friend;
    return (await saved()).firstWhere((g) => g.id == id);
  }

  @override
  Future<Ghost?> load(String id) async => ghosts[id];

  @override
  Future<void> delete(String id) async {
    ghosts.remove(id);
    friends.remove(id);
  }
}

class FakeCourseRepository implements CourseRepository {
  final courses = <SavedCourse>[];

  @override
  Future<List<SavedCourse>> all() async => [...courses];

  @override
  Future<void> save(SavedCourse course) async {
    final i = courses.indexWhere((c) => c.id == course.id);
    if (i < 0) {
      courses.insert(0, course);
    } else {
      courses[i] = course;
    }
  }

  @override
  Future<void> delete(String id) async =>
      courses.removeWhere((c) => c.id == id);
}

class FakeDebriefRepository implements DebriefRepository {
  final debriefs = <DebriefSummary>[];

  @override
  Future<List<DebriefSummary>> all() async =>
      [...debriefs]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> save(DebriefSummary debrief) async {
    debriefs
      ..removeWhere((d) => d.id == debrief.id)
      ..add(debrief);
  }

  @override
  Future<void> delete(String id) async =>
      debriefs.removeWhere((d) => d.id == id);
}

class FakeProfileRepository implements ProfileRepository {
  ProfileData data = const ProfileData();
  DateTime now = DateTime(2026, 11, 13, 8);

  ProfileData _with({
    Object? manualVma = _keep,
    Object? manualMaxHeartRate = _keep,
    Object? manualRestHeartRate = _keep,
    Object? birthYear = _keep,
    ZoneSettings? settings,
    List<ZoneVersion>? versions,
    int? seenVersions,
  }) => ProfileData(
    manualVma: manualVma == _keep
        ? data.manualVma
        : manualVma as ({double value, DateTime date})?,
    manualMaxHeartRate: manualMaxHeartRate == _keep
        ? data.manualMaxHeartRate
        : manualMaxHeartRate as ({int value, DateTime date})?,
    manualRestHeartRate: manualRestHeartRate == _keep
        ? data.manualRestHeartRate
        : manualRestHeartRate as ({int value, DateTime date})?,
    birthYear: birthYear == _keep ? data.birthYear : birthYear as int?,
    settings: settings ?? data.settings,
    versions: versions ?? data.versions,
    seenVersions: seenVersions ?? data.seenVersions,
  );

  static const _keep = Object();

  @override
  Future<ProfileData> read() async => data;

  @override
  Future<void> setManualVma(double? value) async =>
      data = _with(manualVma: value == null ? null : (value: value, date: now));

  @override
  Future<void> setManualMaxHeartRate(int? value) async => data = _with(
    manualMaxHeartRate: value == null ? null : (value: value, date: now),
  );

  @override
  Future<void> setManualRestHeartRate(int? value) async => data = _with(
    manualRestHeartRate: value == null ? null : (value: value, date: now),
  );

  @override
  Future<void> setBirthYear(int? year) async => data = _with(birthYear: year);

  @override
  Future<void> setSettings(ZoneSettings settings) async =>
      data = _with(settings: settings);

  @override
  Future<bool> recordVersion(ZoneSet zones, DateTime date) async {
    final last = data.versions.lastOrNull;
    if (last != null && last.zones.sameAs(zones)) return false;
    data = _with(
      versions: [
        ...data.versions,
        ZoneVersion(date: date, zones: zones),
      ],
      seenVersions: data.versions.isEmpty ? 1 : null,
    );
    return true;
  }

  @override
  Future<void> markVersionsSeen() async =>
      data = _with(seenVersions: data.versions.length);
}

class FakeGoalRepository implements GoalRepository {
  final goals = <RaceGoal>[];

  @override
  Future<List<RaceGoal>> all() async =>
      [...goals]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<RaceGoal?> active() async =>
      (await all()).where((g) => !g.archived).firstOrNull;

  @override
  Future<void> save(RaceGoal goal) async {
    final others = [
      for (final g in goals)
        if (g.id != goal.id)
          !goal.archived && !g.archived ? g.copyWith(archived: true) : g,
    ];
    goals
      ..clear()
      ..addAll([goal, ...others]);
  }

  @override
  Future<void> delete(String id) async => goals.removeWhere((g) => g.id == id);
}

/// Remplace tous les services natifs par des faux.
List<Override> fakeOverrides({
  FakeSetupRepository? setups,
  FakePreferencesRepository? preferences,
  FakeBeepPlayer? player,
  FakeScreenWakeLock? wakeLock,
  FakeHistoryRepository? history,
  DistanceMeasurer? measurer,
  FakeWorkoutRepository? workouts,
  FakeTrackService? tracks,
  FakeRaceClock? clock,
  FakeShareService? share,
  FakeCadenceCoach? coach,
  FakeAccelerometer? accelerometer,
  FakeRecentNamesRepository? recentNames,
  FakeChecklistRepository? checklists,
  FakeReminderScheduler? reminders,
  FakeFartlekRepository? fartleks,
  FakeDeckRepository? decks,
  FakeOrthostaticRepository? orthostatic,
  FakeHeartRateMonitor? heartRate,
  FakeHeartRateHistory? healthHeartRate,
  FakeLocationSource? location,
  FakeLiveVoice? voice,
  FakeGhostRepository? ghosts,
  FakeCourseRepository? courses,
  FakeDebriefRepository? debriefs,
  FakeProfileRepository? profile,
  FakeGoalRepository? goals,
}) => [
  goalRepositoryProvider.overrideWith(
    (ref) async => goals ?? FakeGoalRepository(),
  ),
  profileRepositoryProvider.overrideWith(
    (ref) async => profile ?? FakeProfileRepository(),
  ),
  debriefRepositoryProvider.overrideWith(
    (ref) async => debriefs ?? FakeDebriefRepository(),
  ),
  courseRepositoryProvider.overrideWith(
    (ref) async => courses ?? FakeCourseRepository(),
  ),
  liveVoiceFactoryProvider.overrideWithValue(() => voice ?? FakeLiveVoice()),
  ghostRepositoryProvider.overrideWith(
    (ref) async => ghosts ?? FakeGhostRepository(),
  ),
  locationSourceProvider.overrideWithValue(location ?? FakeLocationSource()),
  heartRateHistoryProvider.overrideWithValue(
    healthHeartRate ?? FakeHeartRateHistory(),
  ),
  heartRateMonitorFactoryProvider.overrideWithValue(
    () => heartRate ?? FakeHeartRateMonitor(),
  ),
  orthostaticRepositoryProvider.overrideWith(
    (ref) async => orthostatic ?? FakeOrthostaticRepository(),
  ),
  deckRepositoryProvider.overrideWith(
    (ref) async => decks ?? FakeDeckRepository(),
  ),
  fartlekRepositoryProvider.overrideWith(
    (ref) async => fartleks ?? FakeFartlekRepository(),
  ),
  checklistRepositoryProvider.overrideWith(
    (ref) async => checklists ?? FakeChecklistRepository(),
  ),
  reminderSchedulerProvider.overrideWithValue(
    reminders ?? FakeReminderScheduler(),
  ),
  recentNamesRepositoryProvider.overrideWith(
    (ref) async => recentNames ?? FakeRecentNamesRepository(),
  ),
  raceClockFactoryProvider.overrideWithValue(() => clock ?? FakeRaceClock()),
  shareServiceProvider.overrideWithValue(share ?? FakeShareService()),
  cadenceCoachFactoryProvider.overrideWithValue(
    () => coach ?? FakeCadenceCoach(),
  ),
  accelerometerProvider.overrideWithValue(accelerometer ?? FakeAccelerometer()),
  workoutRepositoryProvider.overrideWith(
    (ref) async => workouts ?? FakeWorkoutRepository(),
  ),
  distanceMeasurerProvider.overrideWithValue(
    measurer ?? FakeDistanceMeasurer(null),
  ),
  historyRepositoryProvider.overrideWith(
    (ref) async => history ?? FakeHistoryRepository(),
  ),
  screenWakeLockProvider.overrideWithValue(wakeLock ?? FakeScreenWakeLock()),
  setupRepositoryProvider.overrideWith(
    (ref) async => setups ?? FakeSetupRepository(),
  ),
  preferencesRepositoryProvider.overrideWith(
    (ref) async => preferences ?? FakePreferencesRepository(),
  ),
  trackServiceProvider.overrideWith(
    (ref) async => tracks ?? FakeTrackService(),
  ),
  beepPlayerFactoryProvider.overrideWithValue(() => player ?? FakeBeepPlayer()),
];
