import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/timed_test.dart';

void main() {
  Map<TimedCueKind, Duration> cues(TimedTest t) => {
    for (final c in t.cues) c.kind: c.at,
  };

  test('Cooper : départ, mi-temps 6:00, dernière minute 11:00, fin 12:00', () {
    expect(cues(TimedTest.cooper), {
      TimedCueKind.start: Duration.zero,
      TimedCueKind.halfway: const Duration(minutes: 6),
      TimedCueKind.lastMinute: const Duration(minutes: 11),
      TimedCueKind.end: const Duration(minutes: 12),
    });
  });

  test('demi-Cooper : mi-temps 3:00, dernière minute 5:00', () {
    final c = cues(TimedTest.halfCooper);
    expect(c[TimedCueKind.halfway], const Duration(minutes: 3));
    expect(c[TimedCueKind.lastMinute], const Duration(minutes: 5));
    expect(c[TimedCueKind.end], const Duration(minutes: 6));
  });

  test('résultats', () {
    expect(TimedTest.cooper.result(2800).vmaKmh, 14);
    expect(TimedTest.halfCooper.result(1500).vmaKmh, 15);
  });
}
