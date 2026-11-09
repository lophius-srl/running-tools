import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/domain/cadence_advice.dart';
import 'package:running_tools/features/metronome/metronome_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBeepPlayer player;
  late FakeTrackService tracks;
  late FakeCadenceCoach coach;
  late FakeAccelerometer accelerometer;

  setUp(() {
    player = FakeBeepPlayer();
    tracks = FakeTrackService();
    coach = FakeCadenceCoach();
    accelerometer = FakeAccelerometer();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          player: player,
          tracks: tracks,
          coach: coach,
          accelerometer: accelerometer,
        ),
        child: const MaterialApp(home: MetronomePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Simule [seconds] de course à [spm] pas/min (pics d'impact à 50 Hz).
  void run(double spm, {required int fromMs, int seconds = 12}) {
    final period = 60000 / spm;
    for (var ms = fromMs; ms < fromMs + seconds * 1000; ms += 20) {
      final phase = (ms % period) / period;
      accelerometer.controller.add((
        time: Duration(milliseconds: ms),
        x: 0,
        y: 0,
        z: phase < 0.15 ? 8.0 : 0.0,
      ));
    }
  }

  testWidgets('réglage de la cadence et de la durée, puis départ', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('175'), findsOneWidget);
    await tester.tap(find.text('+5'));
    await tester.tap(find.text('-1'));
    await tester.tap(find.text('30 min'));
    await tester.pump();
    expect(find.text('179'), findsOneWidget);

    await tester.tap(find.text('Démarrer'));
    await tester.pumpAndSettle();
    final program = tracks.programs.single;
    expect(program.events.where((e) => e.cue == Cue.tick), hasLength(179 * 30));
    expect(player.calls, containsAll(['load fake.wav', 'play']));
    expect(coach.prepared, isFalse);
    // Réglages verrouillés pendant la lecture.
    expect(find.text('Démarrer'), findsNothing);
  });

  testWidgets('mesure : cadence affichée et conseil vocal', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Mesurer ma cadence'));
    await tester.pump();
    await tester.tap(find.text('Démarrer'));
    await tester.pumpAndSettle();
    expect(coach.prepared, isTrue);

    run(160, fromMs: 0);
    await tester.pump();
    expect(find.text('160'), findsOneWidget);
    expect(find.text('Accélère la cadence. (−15 pas/min)'), findsOneWidget);

    player.emitPosition(const Duration(seconds: 20));
    await tester.pump();
    expect(coach.said, [CadenceAdvice.faster]);

    // Pas de nouveau conseil avant 45 s.
    player.emitPosition(const Duration(seconds: 40));
    await tester.pump();
    expect(coach.said, hasLength(1));
  });
}
