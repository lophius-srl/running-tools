import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/device/location_source.dart';
import 'package:running_tools/domain/gps_tracker.dart';
import 'package:running_tools/features/gps/gps_check_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeLocationSource location;

  setUp(() => location = FakeLocationSource());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(location: location),
        child: const MaterialApp(home: GpsCheckPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  GpsFix fix(int second, double northM, {double accuracy = 5}) => GpsFix(
    time: DateTime(2026, 11, 10, 8).add(Duration(seconds: second)),
    position: GeoPoint(45.75 + northM / 6371000 * 57.29577951, 4.85),
    accuracyM: accuracy,
  );

  testWidgets('distance en direct, points écartés, arrêt net', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Démarrer le suivi'));
    await tester.pump();
    expect(location.tracking, isTrue);
    expect(find.text('Recherche du signal…'), findsOneWidget);

    for (var s = 0; s <= 300; s++) {
      location.emit(fix(s, s * 10 / 3));
    }
    location.emit(fix(301, 5000));
    await tester.pump();
    // Le filtre perd quelques mètres au démarrage, le temps d'estimer la
    // vitesse.
    expect(find.text('0,99 km'), findsOneWidget);
    // Temps écoulé nul (horloge du test) : pas d'allure moyenne absurde.
    expect(find.text('Allure moyenne : – /km'), findsOneWidget);
    expect(find.text('Signal GPS bon (±5 m)'), findsOneWidget);
    expect(find.text('Allure actuelle : 5:00 /km'), findsOneWidget);
    expect(find.text('1 point(s) GPS écarté(s)'), findsOneWidget);

    await tester.tap(find.text('Arrêter'));
    await tester.pump();
    expect(location.tracking, isFalse);
  });

  testWidgets('accès refusé : message clair, pas de suivi', (tester) async {
    location.access = LocationAccess.denied;
    await pumpPage(tester);
    await tester.tap(find.text('Démarrer le suivi'));
    await tester.pump();
    expect(find.textContaining('Accès à la position refusé'), findsOneWidget);
    expect(location.tracking, isFalse);
  });

  test('qualité du signal', () {
    expect(signalQuality(4).$1, 'Signal GPS bon');
    expect(signalQuality(12).$1, 'Signal GPS moyen');
    expect(signalQuality(20).$1, 'Signal GPS faible');
  });
}
