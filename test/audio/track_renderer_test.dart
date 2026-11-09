import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/announcements.dart';
import 'package:running_tools/audio/track_renderer.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/stage_protocol.dart';

void main() {
  final schedule = BeepSchedule.generate(
    const StageProtocol.vameval(),
    duration: const Duration(minutes: 2),
  );
  final renderer = TrackRenderer();
  final track = renderer.render(schedule, const AnnouncementClips());

  bool soundAt(double trackTimeS) {
    final start = renderer.sampleAt(trackTimeS);
    return track
        .sublist(start, start + renderer.sampleAt(0.02))
        .any((s) => s.abs() > 1000);
  }

  test('longueur : intro + test + marge', () {
    expect(track.length, 22050 * (10 + 120 + 4));
  });

  test('bips placés à l\'échantillon près', () {
    expect(soundAt(10.0), isTrue); // départ
    expect(soundAt(10.0 + 9), isTrue); // repère 20 m
    expect(soundAt(10.0 + 4.5), isFalse); // entre deux repères
    expect(soundAt(10.0 + 60), isTrue); // changement de palier
  });

  test('voix mixée après le signal de palier', () {
    final voice = Float32List.fromList(List.filled(2205, 0.5));
    final withVoice = renderer.render(
      schedule,
      AnnouncementClips(stages: {2: voice}),
    );
    final at = renderer.sampleAt(10 + 60 + 0.45 + 0.05);
    expect(withVoice[at], greaterThan(10000));
    expect(track[at], 0);
  });

  test('testTimeAt retire l\'intro', () {
    expect(renderer.testTimeAt(const Duration(seconds: 70)), 60);
  });

  test('textes des annonces', () {
    expect(stageAnnouncement(2, 8.5), 'Palier 2, 8 virgule 5 kilomètres heure');
    expect(stageAnnouncement(5, 10), 'Palier 5, 10 kilomètres heure');
    expect(formatKmh(8.5), '8,5');
  });
}
