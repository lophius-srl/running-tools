import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/common/duration_text.dart';

void main() {
  test('parseClock : formats acceptés', () {
    expect(parseClock('1:36'), const Duration(seconds: 96));
    expect(parseClock('1:36,4'), const Duration(milliseconds: 96400));
    expect(parseClock('96.4'), const Duration(milliseconds: 96400));
    expect(
      parseClock('1:02:03'),
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
  });

  test('parseClock : saisies invalides', () {
    expect(parseClock(''), isNull);
    expect(parseClock('abc'), isNull);
    expect(parseClock('1:75'), isNull);
    expect(parseClock('1,5:30'), isNull);
    expect(parseClock('-1:00'), isNull);
  });

  test('formatSplit au dixième', () {
    expect(formatSplit(const Duration(milliseconds: 101370)), '1:41,4');
    expect(formatSplit(const Duration(seconds: 59)), '0:59,0');
    expect(formatSplit(const Duration(hours: 1, seconds: 5)), '1:00:05,0');
  });

  test('speedFromPace', () {
    expect(speedFromPace('4:00'), 15);
    expect(speedFromPace('0:00'), isNull);
    expect(speedFromPace('x'), isNull);
  });
}
