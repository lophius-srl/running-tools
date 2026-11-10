import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/course_repository.dart';
import 'package:running_tools/domain/course_profile.dart';
import 'package:running_tools/features/checklists/new_race_page.dart';
import 'package:running_tools/features/common/gpx_picker.dart';
import 'package:running_tools/features/course/course_text.dart';
import 'package:running_tools/features/course/courses_page.dart';

import '../../support/fakes.dart';

/// 2 km plat, 1 km à +6 %, 1 km à −6 %, 1 km plat.
String hillGpx() {
  double ele(double d) {
    if (d <= 2000) return 200;
    if (d <= 3000) return 200 + (d - 2000) * 0.06;
    if (d <= 4000) return 260 - (d - 3000) * 0.06;
    return 200;
  }

  final points = [
    for (var d = 0.0; d <= 5000; d += 20)
      '<trkpt lat="${45 + d / 6371000 * 180 / pi}" lon="4">'
          '<ele>${ele(d)}</ele></trkpt>',
  ];
  return '<gpx><trk><name>Corrida des collines</name><trkseg>'
      '${points.join()}</trkseg></trk></gpx>';
}

void main() {
  late FakeCourseRepository courses;
  late FakeShareService share;
  late FakeChecklistRepository checklists;

  setUp(() {
    courses = FakeCourseRepository();
    share = FakeShareService();
    checklists = FakeChecklistRepository();
  });

  Future<void> pumpPage(WidgetTester tester, {String? gpx}) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(
            courses: courses,
            share: share,
            checklists: checklists,
          ),
          gpxPickerProvider.overrideWithValue(
            () async => (name: 'course', content: gpx ?? hillGpx()),
          ),
        ],
        child: const MaterialApp(home: CoursesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('import : profil, sections, allure, objectif de temps', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('Importer un GPX'));
    await tester.pumpAndSettle();

    // Le lissage arrondit le sommet : D+ un peu sous 60 m.
    expect(find.text('5,0 km · D+ 57 m · D− 57 m'), findsOneWidget);
    expect(find.textContaining('Montée · 2,0 km'), findsOneWidget);
    expect(find.textContaining('Descente · 3,0 km'), findsOneWidget);
    // Base 5:00/km sur le plat : un peu plus de 25 min avec la bosse.
    final planned = find.textContaining('Temps prévu : 2');
    expect(planned, findsOneWidget);

    await tester.enterText(find.byKey(const Key('course-value')), '4:30');
    await tester.pump();
    expect(
      courses.courses.single.value,
      const Duration(minutes: 4, seconds: 30),
    );

    // Passage en objectif : le temps prévu devient l'objectif.
    await tester.tap(find.text('Objectif de temps'));
    await tester.pumpAndSettle();
    expect(courses.courses.single.pacing, CoursePacing.target);
    await tester.enterText(find.byKey(const Key('course-value')), '25:00');
    await tester.pump();
    expect(find.textContaining('Allure sur le plat : 4:'), findsOneWidget);

    await scrollTo(tester, find.text('Partager la bande d’allure'));
    await tester.tap(find.text('Partager la bande d’allure'));
    await tester.pump();
    expect(share.shared.single, contains('Objectif 25:00'));
    expect(share.shared.single, contains('4,99 km : 25:00'));
  });

  testWidgets('checklist de la course : création liée au parcours', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('Importer un GPX'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Checklist de la course'));
    await tester.tap(find.text('Checklist de la course'));
    await tester.pumpAndSettle();
    final page = tester.widget<NewRacePage>(find.byType(NewRacePage));
    expect(page.courseId, courses.courses.single.id);
    expect(page.initialName, 'Corrida des collines');
  });

  testWidgets('GPX sans altitudes : message', (tester) async {
    await pumpPage(tester, gpx: '<gpx><trk><trkseg></trkseg></trk></gpx>');
    await tester.tap(find.text('Importer un GPX'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sans altitudes'), findsNothing);
    expect(find.textContaining('avec altitudes'), findsOneWidget);
    expect(courses.courses, isEmpty);
  });

  test('temps de course affichés', () {
    expect(formatRaceTime(1500), '25:00');
    expect(formatRaceTime(6730), '1:52:10');
    expect(formatKm(12345), '12,3 km');
  });

  test('aller-retour JSON d’un parcours', () {
    final c = SavedCourse(
      id: 'c1',
      profile: CourseProfile(
        name: 'Boucle',
        elevations: const [100, 101.25, 99],
      ),
      pacing: CoursePacing.target,
      value: const Duration(minutes: 50),
    );
    final back = SavedCourse.fromJson(c.toJson())!;
    expect(back.profile.elevations, [100, 101.3, 99]);
    expect(back.pacing, CoursePacing.target);
    expect(back.value, const Duration(minutes: 50));
  });
}
