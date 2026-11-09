import 'dart:io';

import 'audio_program.dart';
import 'program_builder.dart';
import 'program_renderer.dart';

/// À incrémenter quand le rendu change (sons, voix…) : invalide le cache.
const trackFormatVersion = 2;

/// Piste prête à jouer.
class PreparedTrack {
  const PreparedTrack({
    required this.path,
    required this.program,
    this.voiceError,
  });

  final String path;
  final AudioProgram program;

  /// Non nul si les annonces vocales ont échoué (bips seuls).
  final String? voiceError;

  /// Temps de l'activité (secondes) à partir de la position de lecture.
  double activityTimeAt(Duration playback) => program.activityTimeAt(playback);
}

abstract interface class TrackService {
  Future<PreparedTrack> prepare(
    AudioProgram program, {
    void Function(String step)? onProgress,
  });
}

typedef ProgramBuild = Future<String?> Function(
  AudioProgram program, {
  required Directory workDir,
  required String outputPath,
  int sampleRate,
  void Function(String step)? onProgress,
});

/// Génère la piste d'un programme, ou réutilise la dernière si le programme
/// est identique. Une seule piste est gardée en cache.
class CachedTrackService implements TrackService {
  CachedTrackService(
    this.directory, {
    this.sampleRate = trackSampleRate,
    this.build = buildProgramTrack,
  });

  final Directory directory;
  final int sampleRate;
  final ProgramBuild build;

  @override
  Future<PreparedTrack> prepare(
    AudioProgram program, {
    void Function(String step)? onProgress,
  }) async {
    final key = program.cacheKey(
      sampleRate: sampleRate,
      format: trackFormatVersion,
    );
    final cached = File('${directory.path}/track_$key.wav');
    if (await cached.exists()) {
      return PreparedTrack(path: cached.path, program: program);
    }

    await _clearTracks();
    final building = File('${directory.path}/track_building.wav');
    final voiceError = await build(
      program,
      workDir: directory,
      outputPath: building.path,
      sampleRate: sampleRate,
      onProgress: onProgress,
    );
    // Sans les voix, on ne met pas en cache : nouvel essai la prochaine fois.
    final path = voiceError == null
        ? (await building.rename(cached.path)).path
        : building.path;
    return PreparedTrack(path: path, program: program, voiceError: voiceError);
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
