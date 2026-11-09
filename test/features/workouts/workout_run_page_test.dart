import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/audio_program.dart';
import 'package:running_tools/domain/workout.dart';
import 'package:running_tools/domain/workout_plan.dart';
import 'package:running_tools/features/workouts/workout_run_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBeepPlayer player;
  late FakeTrackService tracks;

  // 2 × 400 m à 100 % de 15 km/h (96 s), récupération 1 min.
  final plan = WorkoutPlan.compute(
    const Workout(
      id: 'w',
      name: '2 × 400',
      sets: [
        WorkoutSet(
          reps: 2,
          effort: Effort.distance(400, percentVma: 100),
          recovery: Recovery.time(Duration(minutes: 1)),
        ),
      ],
    ),
    vmaKmh: 15,
    markerSpacingM: 20,
  );

  setUp(() {
    player = FakeBeepPlayer();
    tracks = FakeTrackService();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(player: player, tracks: tracks),
        child: MaterialApp(home: WorkoutRunPage(plan: plan)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> at(WidgetTester tester, Duration playback) async {
    player.emitPosition(playback);
    await tester.pump();
  }

  testWidgets('la bande-son « chrono » de la séance est chargée', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(player.calls, contains('load fake.wav'));
    final program = tracks.programs.single;
    expect(program.events.where((e) => e.cue == Cue.start), hasLength(2));
  });

  testWidgets('départ, répétition, récupération, puis récap', (tester) async {
    await pumpPage(tester);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('00:10'), findsOneWidget);

    await at(tester, const Duration(seconds: 10 + 30));
    expect(find.text('Répétition 1/2'), findsOneWidget);
    expect(find.text('01:06'), findsOneWidget); // 96 − 30 s
    expect(find.text('400 m · 1:36,0 (4:00 /km)'), findsOneWidget);

    await at(tester, const Duration(seconds: 10 + 96 + 20));
    expect(find.text('Récupération'), findsOneWidget);
    expect(find.text('00:40'), findsOneWidget);
    expect(find.text('Ensuite : 400 m · 1:36,0 (4:00 /km)'), findsOneWidget);

    await at(tester, Duration(seconds: 10 + plan.totalDuration.inSeconds + 1));
    expect(find.text('Séance terminée !'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}
