import 'dart:io';

import '../domain/beep_schedule.dart';
import '../domain/staged_test_setup.dart';
import '../domain/timed_test.dart';
import 'timed_track.dart';
import 'track_builder.dart';
import 'track_cache_key.dart';
import 'track_renderer.dart';

/// Piste prête à jouer, avec ce qu'il faut pour suivre la position.
class PreparedTrack {
  const PreparedTrack({
    required this.path,
    required this.schedule,
    required this.renderer,
    this.voiceError,
  });

  final String path;
  final BeepSchedule schedule;
  final TrackRenderer renderer;

  /// Non nul si les annonces vocales ont échoué (bips seuls).
  final String? voiceError;
}

/// Piste d'un test chronométré prête à jouer.
class PreparedTimedTrack {
  const PreparedTimedTrack({
    required this.path,
    required this.leadIn,
    this.voiceError,
  });

  final String path;

  /// Secondes avant le départ dans la piste.
  final int leadIn;
  final String? voiceError;
}

abstract interface class TrackService {
  Future<PreparedTrack> prepare(
    StagedTestSetup setup, {
    void Function(String step)? onProgress,
  });

  Future<PreparedTimedTrack> prepareTimed(
    TimedTest test, {
    void Function(String step)? onProgress,
  });
}

typedef TrackBuild = Future<BuiltTrack> Function({
  required BeepSchedule schedule,
  required TrackRenderer renderer,
  required String testName,
  required Directory workDir,
  required String outputPath,
  void Function(String step)? onProgress,
});

typedef TimedTrackBuild = Future<String?> Function(
  TimedTest test, {
  required Directory workDir,
  required String outputPath,
  int sampleRate,
  int leadIn,
  void Function(String step)? onProgress,
});

/// Génère la piste, ou réutilise la dernière si les réglages sont identiques.
/// Une seule piste est gardée en cache (≈ 66 Mo pour 25 min).
class CachedTrackService implements TrackService {
  CachedTrackService(
    this.directory, {
    TrackRenderer? renderer,
    this.build = buildTrack,
    this.buildTimed = buildTimedTrack,
  }) : renderer = renderer ?? TrackRenderer();

  final Directory directory;
  final TrackRenderer renderer;
  final TrackBuild build;
  final TimedTrackBuild buildTimed;

  @override
  Future<PreparedTrack> prepare(
    StagedTestSetup setup, {
    void Function(String step)? onProgress,
  }) async {
    final schedule = BeepSchedule.generate(
      setup.protocol,
      duration: setup.maxDuration,
    );
    final cached = File(
      '${directory.path}/track_${trackCacheKey(setup, renderer)}.wav',
    );
    if (await cached.exists()) {
      return PreparedTrack(
        path: cached.path,
        schedule: schedule,
        renderer: renderer,
      );
    }

    await _clearTracks();
    final building = File('${directory.path}/track_building.wav');
    final built = await build(
      schedule: schedule,
      renderer: renderer,
      testName: setup.test.label,
      workDir: directory,
      outputPath: building.path,
      onProgress: onProgress,
    );
    // Sans les voix, on ne met pas en cache : nouvel essai la prochaine fois.
    final path = built.voiceError == null
        ? (await building.rename(cached.path)).path
        : building.path;
    return PreparedTrack(
      path: path,
      schedule: schedule,
      renderer: renderer,
      voiceError: built.voiceError,
    );
  }

  @override
  Future<PreparedTimedTrack> prepareTimed(
    TimedTest test, {
    void Function(String step)? onProgress,
  }) async {
    final leadIn = renderer.leadIn;
    final key = timedTrackCacheKey(
      test,
      sampleRate: renderer.sampleRate,
      leadIn: leadIn,
    );
    final cached = File('${directory.path}/track_$key.wav');
    if (await cached.exists()) {
      return PreparedTimedTrack(path: cached.path, leadIn: leadIn);
    }

    await _clearTracks();
    final building = File('${directory.path}/track_building.wav');
    final voiceError = await buildTimed(
      test,
      workDir: directory,
      outputPath: building.path,
      sampleRate: renderer.sampleRate,
      leadIn: leadIn,
      onProgress: onProgress,
    );
    final path = voiceError == null
        ? (await building.rename(cached.path)).path
        : building.path;
    return PreparedTimedTrack(
      path: path,
      leadIn: leadIn,
      voiceError: voiceError,
    );
  }

  Future<void> _clearTracks() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      return;
    }
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File &&
          name.startsWith('track_') &&
          name.endsWith('.wav')) {
        await entity.delete();
      }
    }
  }
}
