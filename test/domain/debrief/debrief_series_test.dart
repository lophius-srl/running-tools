import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/debrief/clean_activity.dart';
import 'package:running_tools/domain/debrief/debrief_series.dart';
import 'package:running_tools/domain/debrief/effort_track.dart';
import 'package:running_tools/domain/debrief/gpx_activity.dart';

import '../../fixtures/activities.dart';

void main() {
  test('série tous les 50 m : altitude, allure, FC', () {
    final t = EffortTrack(
      CleanActivity.from(
        parseGpxActivity(
          toGpx(
            scriptedRun(
              km: 5,
              kmhAt: (d) => d < 2500 ? 12 : 10,
              elevationAt: hillAt,
              hrAt: (d, s) => d < 2500 ? 140 : 160,
            ),
          ),
        ),
      ),
    );
    final s = debriefSeries(t);
    expect(s.length, closeTo(100, 2));
    expect(s.first.km, 0);
    // 12 km/h = 5:00/km, 10 km/h = 6:00/km.
    expect(s[20].paceS, closeTo(300, 8));
    expect(s[80].paceS, closeTo(360, 10));
    expect(s[20].heartRate, closeTo(140, 1));
    expect(s[80].heartRate, closeTo(160, 1));
    // Sommet de la bosse vers 3 km.
    final top = s.reduce((a, b) => a.elevationM! > b.elevationM! ? a : b);
    expect(top.km, closeTo(3, 0.15));
  });
}
