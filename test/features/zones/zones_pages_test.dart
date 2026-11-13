import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/orthostatic.dart';
import 'package:running_tools/domain/test_record.dart';
import 'package:running_tools/features/zones/profile_page.dart';
import 'package:running_tools/features/zones/zones_page.dart';

import '../../support/fakes.dart';

void main() {
  late FakeProfileRepository profile;
  late FakeHistoryRepository history;
  late FakeOrthostaticRepository orthostatic;
  late FakePreferencesRepository prefs;

  TestRecord vameval(int daysAgo) => TestRecord(
    id: 't',
    date: DateTime.now().subtract(Duration(days: daysAgo)),
    kind: TestKind.vameval,
    vmaKmh: 11.9,
    vo2max: 41.7,
  );

  setUp(() {
    profile = FakeProfileRepository();
    history = FakeHistoryRepository()..records.add(vameval(10));
    orthostatic = FakeOrthostaticRepository()
      ..results.addAll([
        for (var i = 0; i < 5; i++)
          OrthostaticResult(
            date: DateTime.now().subtract(Duration(days: i)),
            lyingBpm: 80,
            standingPeakBpm: 110,
            standingStableBpm: 95,
            source: HeartRateSourceKind.manual,
          ),
      ]);
    prefs = FakePreferencesRepository()
      ..maxHr = 203
      ..maxHrDate = DateTime(2026, 11, 1);
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          profile: profile,
          history: history,
          orthostatic: orthostatic,
          preferences: prefs,
        ),
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Mes zones : valeurs de référence, sources', (tester) async {
    await pump(tester, const ZonesPage());
    expect(find.text('11,9 km/h'), findsOneWidget);
    expect(find.text('203'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text("8'24–6'43/km"), findsOneWidget);
    expect(find.text('154–169'), findsOneWidget);
    expect(find.textContaining('plus haute relevée'), findsOneWidget);
    expect(profile.data.versions, hasLength(1));
  });

  testWidgets('borne ajustée en bpm, puis valeurs par défaut', (tester) async {
    await pump(tester, const ZonesPage());
    await tester.tap(find.text('Endurance fondamentale'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bound-hr-bpm')), '165');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('154–165'), findsOneWidget);
    expect(profile.data.versions, hasLength(2));

    await tester.scrollUntilVisible(
      find.text('Valeurs par défaut'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Valeurs par défaut'));
    await tester.pumpAndSettle();
    expect(profile.data.settings.isDefault, isTrue);
  });

  testWidgets('Mon profil : FC max saisie, prioritaire ; rappel VMA', (
    tester,
  ) async {
    history.records
      ..clear()
      ..add(vameval(70));
    await pump(tester, const ProfilePage());
    expect(
      find.text('Ta VMA date de 10 semaines : refais un test.'),
      findsOneWidget,
    );
    expect(find.textContaining('5 mesures'), findsOneWidget);

    await tester.tap(find.text('Modifier').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-value')), '198');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('198 bpm'), findsOneWidget);
    expect(find.textContaining('ta saisie'), findsOneWidget);

    // Revenir à la valeur automatique.
    await tester.tap(find.text('Modifier').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valeur automatique'));
    await tester.pumpAndSettle();
    expect(find.text('203 bpm'), findsOneWidget);
  });

  testWidgets('sans FC max : estimation 220 − âge signalée', (tester) async {
    prefs.maxHr = null;
    await profile.setBirthYear(1990);
    await pump(tester, const ProfilePage());
    expect(find.textContaining('estimation 220 − âge'), findsOneWidget);
    expect(find.textContaining('Estimation peu fiable'), findsOneWidget);
  });
}
