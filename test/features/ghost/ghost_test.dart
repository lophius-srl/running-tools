import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/ghost.dart';
import 'package:running_tools/domain/gps_tracker.dart';
import 'package:running_tools/domain/gpx.dart';
import 'package:running_tools/features/ghost/ghost_page.dart';

import '../../support/fakes.dart';

GeoPoint north(double m) => GeoPoint(45.75 + m / 6371000 * 180 / pi, 4.85);

String gpxOf(int seconds) {
  final points = [
    for (var s = 0; s <= seconds; s++)
      '<trkpt lat="${north(s * 3.0).latitude}" lon="4.85"><time>'
          '${DateTime.utc(2026, 11, 2, 8).add(Duration(seconds: s)).toIso8601String()}'
          '</time></trkpt>',
  ];
  return '<gpx><trk><name>Boucle du parc</name><trkseg>${points.join()}'
      '</trkseg></trk></gpx>';
}

void main() {
  late FakeLocationSource location;
  late FakeLiveVoice voice;
  late FakeGhostRepository ghosts;
  late FakeRaceClock clock;

  setUp(() {
    location = FakeLocationSource();
    voice = FakeLiveVoice();
    ghosts = FakeGhostRepository();
    clock = FakeRaceClock();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    GpxPicker? picker,
    bool duo = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(
            location: location,
            voice: voice,
            ghosts: ghosts,
            clock: clock,
          ),
          if (picker != null) gpxPickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(home: GhostPage(duo: duo)),
      ),
    );
    await tester.pumpAndSettle();
  }

  GpsFix fix(int second, double meters) => GpsFix(
    time: DateTime(2026, 11, 10, 8).add(Duration(seconds: second)),
    position: north(meters),
    accuracyM: 5,
  );

  testWidgets('course contre un fantôme virtuel : annonces, arrivée, bilan', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('ghost-distance')), '1');
    await tester.pump();
    await tester.tap(find.text('Courir contre le fantôme'));
    await tester.pumpAndSettle();

    // Pas de départ sans GPS.
    final go = find.widgetWithText(FilledButton, 'Partir');
    expect(tester.widget<FilledButton>(go).onPressed, isNull);
    location.emit(fix(0, 0));
    await tester.pump();
    await tester.tap(go);
    await tester.pump();
    expect(clock.started, isTrue);
    expect(voice.said.single, startsWith('Partez !'));

    // 4'40/km contre 5'00/km.
    for (var s = 1; s <= 300; s++) {
      clock.elapsed = Duration(seconds: s);
      location.emit(fix(s, s * 1000 / 280));
      if (s == 150) {
        await tester.pump();
        expect(find.textContaining('devant le fantôme'), findsOneWidget);
        expect(find.textContaining('Reste'), findsOneWidget);
      }
    }
    await tester.pumpAndSettle();

    expect(find.text('Fantôme battu !'), findsOneWidget);
    expect(voice.said.any((p) => p.startsWith('Arrivée !')), isTrue);
    final run = ghosts.summaries.single;
    expect(run.ghostName, 'Allure 5:00/km');
    expect(run.gapS, greaterThan(5));
    expect(run.distanceM, greaterThanOrEqualTo(1000));
    expect(run.curve, hasLength(10));
  });

  testWidgets('import GPX : fantôme enregistré, « même parcours » possible', (
    tester,
  ) async {
    await pumpPage(
      tester,
      picker: () async => (name: 'parc', content: gpxOf(200)),
    );
    final route = find.widgetWithText(
      ButtonSegment<GhostAlignment>,
      'Même parcours',
    );
    expect(route, findsNothing);
    await tester.tap(find.text('Importer un GPX'));
    await tester.pumpAndSettle();

    expect(find.text('Boucle du parc'), findsOneWidget);
    expect(ghosts.ghosts.values.single.hasRoute, isTrue);
    await tester.tap(find.text('Même parcours'));
    await tester.pump();
    final button = tester.widget<SegmentedButton<GhostAlignment>>(
      find.byType(SegmentedButton<GhostAlignment>),
    );
    expect(button.selected, {GhostAlignment.route});
  });

  testWidgets('GPX illisible : message', (tester) async {
    await pumpPage(
      tester,
      picker: () async => (name: 'x', content: 'pas un gpx'),
    );
    await tester.tap(find.text('Importer un GPX'));
    await tester.pumpAndSettle();
    expect(find.text('Fichier GPX illisible.'), findsOneWidget);
    expect(ghosts.ghosts, isEmpty);
  });

  test('écart affiché', () {
    expect(formatGap(12.4), '+12 s');
    expect(formatGap(-65), '−1:05');
    expect(formatGap(0.2), '0 s');
  });

  testWidgets('duo : sortie d’un ami, annonces et bilan à son nom', (
    tester,
  ) async {
    await pumpPage(
      tester,
      duo: true,
      picker: () async => (name: 'parc', content: gpxOf(400)),
    );
    expect(find.text('Fantôme à allure constante'), findsNothing);
    expect(find.textContaining('Exporter le GPX'), findsOneWidget);

    await tester.tap(find.text('Ajouter la sortie d’un ami (GPX)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-name')), 'Tom');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Tom · Boucle du parc'), findsOneWidget);
    expect(ghosts.friends.values.single, 'Tom');

    await tester.scrollUntilVisible(
      find.text('Courir contre Tom'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Courir contre Tom'));
    await tester.pumpAndSettle();
    location.emit(fix(0, 0));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Partir'));
    await tester.pump();
    expect(voice.said.single, 'Partez ! Tom est parti avec toi.');

    // Tom court à 3 m/s ; moi à 2,5 m/s : il est devant.
    for (var s = 1; s <= 120; s++) {
      clock.elapsed = Duration(seconds: s);
      location.emit(fix(s, s * 2.5));
    }
    await tester.pump();
    expect(find.textContaining('derrière Tom'), findsOneWidget);

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Tom gagne'), findsOneWidget);
    expect(ghosts.summaries.single.rival, 'Tom');
  });

  testWidgets('les sorties d’amis ne se mélangent pas aux fantômes', (
    tester,
  ) async {
    await ghosts.save(parseGpxGhost(gpxOf(60)), friend: 'Tom');
    await pumpPage(tester);
    expect(find.textContaining('Tom'), findsNothing);
  });
}
