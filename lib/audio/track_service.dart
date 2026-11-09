import 'dart:io';

import '../domain/beep_schedule.dart';
import '../domain/staged_test_setup.dart';
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

abstract interface class TrackService {
  Future<PreparedTrack> prepare(
    StagedTestSetup setup, {
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

/// Génère la piste, ou réutilise la dernière si les réglages sont identiques.
/// Une seule piste est gardée en cache (≈ 66 Mo pour 25 min).
class CachedTrackService implements TrackService {
  CachedTrackService(
    this.directory, {
    TrackRenderer? renderer,
    this.build = buildTrack,
  }) : renderer = renderer ?? TrackRenderer();

  final Directory directory;
  final TrackRenderer renderer;
  final TrackBuild build;

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
