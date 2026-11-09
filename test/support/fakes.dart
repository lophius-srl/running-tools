import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:running_tools/audio/beep_player.dart';
import 'package:running_tools/audio/providers.dart';
import 'package:running_tools/audio/track_renderer.dart';
import 'package:running_tools/audio/track_service.dart';
import 'package:running_tools/data/preferences_repository.dart';
import 'package:running_tools/data/providers.dart';
import 'package:running_tools/data/setup_repository.dart';
import 'package:running_tools/device/screen_wake_lock.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';

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
}

/// Piste instantanée, sans audio.
class FakeTrackService implements TrackService {
  @override
  Future<PreparedTrack> prepare(
    StagedTestSetup setup, {
    void Function(String step)? onProgress,
  }) async => PreparedTrack(
    path: 'fake.wav',
    schedule: BeepSchedule.generate(
      setup.protocol,
      duration: setup.maxDuration,
    ),
    renderer: TrackRenderer(),
  );
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

class FakeScreenWakeLock implements ScreenWakeLock {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}

/// Remplace tous les services natifs par des faux.
List<Override> fakeOverrides({
  FakeSetupRepository? setups,
  FakePreferencesRepository? preferences,
  FakeBeepPlayer? player,
  FakeScreenWakeLock? wakeLock,
}) => [
  screenWakeLockProvider.overrideWithValue(wakeLock ?? FakeScreenWakeLock()),
  setupRepositoryProvider.overrideWith(
    (ref) async => setups ?? FakeSetupRepository(),
  ),
  preferencesRepositoryProvider.overrideWith(
    (ref) async => preferences ?? FakePreferencesRepository(),
  ),
  trackServiceProvider.overrideWith((ref) async => FakeTrackService()),
  beepPlayerFactoryProvider.overrideWithValue(() => player ?? FakeBeepPlayer()),
];
