import 'dart:typed_data';

import '../domain/beep_schedule.dart';
import 'pcm.dart';

/// Annonces vocales déjà décodées, à la fréquence de la piste.
class AnnouncementClips {
  const AnnouncementClips({this.intro, this.stages = const {}, this.end});

  final Float32List? intro;
  final Map<int, Float32List> stages;
  final Float32List? end;
}

/// Rend la piste complète d'un test : intro, décompte, bips, annonces.
///
/// Le départ du test (t = 0 du [BeepSchedule]) tombe à [leadIn] dans la piste.
/// Chaque signal est placé à l'échantillon près.
class TrackRenderer {
  TrackRenderer({this.sampleRate = 22050, this.leadIn = 10, this.tail = 4});

  final int sampleRate;

  /// Secondes avant le départ (annonce + décompte).
  final int leadIn;

  /// Secondes de marge après la fin.
  final int tail;

  static const _voiceDelayS = 0.45;

  int sampleAt(double trackTimeS) => (trackTimeS * sampleRate).round();

  /// Position dans le test (secondes) à partir de la position de lecture.
  double testTimeAt(Duration playback) =>
      playback.inMicroseconds / 1e6 - leadIn;

  Int16List render(BeepSchedule schedule, AnnouncementClips clips) {
    final track = Int16List(sampleAt(leadIn + schedule.durationS + tail));
    Duration ms(int n) => Duration(milliseconds: n);
    final marker = tone(
      sampleRate: sampleRate,
      frequencyHz: 1000,
      duration: ms(150),
    );
    final stageChange = sequence([
      tone(sampleRate: sampleRate, frequencyHz: 1500, duration: ms(120)),
      tone(sampleRate: sampleRate, frequencyHz: 1500, duration: ms(120)),
    ], sampleAt(0.08));
    final countdown = tone(
      sampleRate: sampleRate,
      frequencyHz: 800,
      duration: ms(100),
      amplitude: 0.6,
    );
    final start = tone(
      sampleRate: sampleRate,
      frequencyHz: 1200,
      duration: ms(600),
    );
    final end = sequence([
      for (var i = 0; i < 3; i++)
        tone(sampleRate: sampleRate, frequencyHz: 1200, duration: ms(250)),
    ], sampleAt(0.1));

    if (clips.intro != null) mixInto(track, sampleAt(0.5), clips.intro!);
    for (var s = 3; s >= 1; s--) {
      mixInto(track, sampleAt(leadIn - s.toDouble()), countdown);
    }

    for (final event in schedule.events) {
      final at = sampleAt(leadIn + event.timeS);
      switch (event.kind) {
        case BeepKind.start:
          mixInto(track, at, start);
        case BeepKind.marker:
          mixInto(track, at, marker);
        case BeepKind.stageChange:
          mixInto(track, at, stageChange);
          final voice = clips.stages[event.stage];
          if (voice != null) {
            mixInto(
              track,
              sampleAt(leadIn + event.timeS + _voiceDelayS),
              voice,
            );
          }
        case BeepKind.end:
          mixInto(track, at, end);
          if (clips.end != null) {
            mixInto(track, sampleAt(leadIn + event.timeS + 1), clips.end!);
          }
      }
    }
    return track;
  }
}
