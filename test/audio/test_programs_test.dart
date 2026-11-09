import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/announcements.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/audio/program_renderer.dart';
import 'package:running_tools/audio/test_programs.dart';
import 'package:running_tools/domain/beep_schedule.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/timed_test.dart';

void main() {
  final renderer = ProgramRenderer();

  bool soundAt(Int16List track, double s) {
    final start = renderer.sampleAt(s);
    return track
        .sublist(start, start + renderer.sampleAt(0.02))
        .any((v) => v.abs() > 1000);
  }

  group('test par paliers', () {
    final schedule = BeepSchedule.generate(
      const StageProtocol.vameval(),
      duration: const Duration(minutes: 2),
    );
    final program = stagedTestProgram(schedule, testName: 'Test VAMEVAL');
    final track = renderer.render(program, const {});

    test('longueur : intro + test + marge', () {
      expect(track.length, 22050 * (10 + 120 + 4));
      expect(program.leadInS, 10);
    });

    test('bips placés à l\'échantillon près', () {
      expect(soundAt(track, 10.0), isTrue); // départ
      expect(soundAt(track, 10.0 + 9), isTrue); // repère 20 m
      expect(soundAt(track, 10.0 + 4.5), isFalse); // entre deux repères
      expect(soundAt(track, 10.0 + 60), isTrue); // changement de palier
    });

    test('annonces : intro, paliers, fin', () {
      expect(program.speeches, {
        introAnnouncement('Test VAMEVAL', 8),
        stageAnnouncement(2, 8.5),
        endAnnouncement,
      });
    });

    test('voix mixée après le signal de palier', () {
      final voice = Float32List.fromList(List.filled(2205, 0.5));
      final withVoice = renderer.render(program, {
        stageAnnouncement(2, 8.5): voice,
      });
      final at = renderer.sampleAt(10 + 60 + 0.45 + 0.05);
      expect(withVoice[at], greaterThan(10000));
      expect(track[at], 0);
    });
  });

  group('test chronométré', () {
    final program = timedTestProgram(TimedTest.halfCooper);
    final track = renderer.render(program, const {});

    test('durée : intro 10 s + 6 min + marge 6 s', () {
      expect(track.length, 22050 * (10 + 360 + 6));
    });

    test('signaux au départ, mi-temps, dernière minute et fin', () {
      expect(soundAt(track, 10), isTrue);
      expect(soundAt(track, 10 + 180), isTrue);
      expect(soundAt(track, 10 + 300), isTrue);
      expect(soundAt(track, 10 + 360), isTrue);
      expect(soundAt(track, 10 + 90), isFalse);
    });

    test('textes', () {
      expect(
        timedCueText(TimedTest.cooper, TimedCueKind.halfway),
        'Mi-temps. Encore 6 minutes.',
      );
      expect(program.speeches, hasLength(4));
    });
  });

  test('programme long et répétitif (45 min, un bip toutes les 0,35 s)', () {
    final program = AudioProgram(
      durationS: 45 * 60,
      leadInS: 0,
      events: [
        for (var t = 0.0; t < 45 * 60; t += 0.35)
          ProgramEvent.cue(t, Cue.marker),
      ],
    );
    final watch = Stopwatch()..start();
    final track = renderer.render(program, const {});
    watch.stop();
    expect(track.length, 22050 * 45 * 60);
    expect(program.events, hasLength(7715));
    // Garde-fou large : le rendu tourne dans un isolate sur l'iPhone.
    expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
  });
}
