import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/audio/track_cache_key.dart';
import 'package:running_tools/audio/track_renderer.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';

void main() {
  final renderer = TrackRenderer();
  final base = StagedTestSetup.defaults(StagedTest.vameval);

  StagedTestSetup withSpacing(double m) => StagedTestSetup(
    test: base.test,
    protocol: base.protocol.copyWith(markerSpacingM: m),
    maxSpeedKmh: base.maxSpeedKmh,
    method: base.method,
  );

  test('stable pour des réglages identiques', () {
    expect(
      trackCacheKey(base, renderer),
      trackCacheKey(withSpacing(20), renderer),
    );
  });

  test('change si un réglage audible change', () {
    expect(
      trackCacheKey(base, renderer),
      isNot(trackCacheKey(withSpacing(20.5), renderer)),
    );
    expect(
      trackCacheKey(base, renderer),
      isNot(trackCacheKey(base, TrackRenderer(leadIn: 5))),
    );
  });

  test('la méthode de mesure ne change pas la piste', () {
    final ar = StagedTestSetup(
      test: base.test,
      protocol: base.protocol,
      maxSpeedKmh: base.maxSpeedKmh,
      method: MeasurementMethod.ar,
    );
    expect(trackCacheKey(ar, renderer), trackCacheKey(base, renderer));
  });
}
