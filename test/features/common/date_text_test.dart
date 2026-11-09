import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/common/date_text.dart';

void main() {
  test('date et heure en français', () {
    expect(formatDateTime(DateTime(2026, 11, 9, 18, 5)), '9 nov. 2026, 18:05');
    expect(formatDateTime(DateTime(2027, 2, 28, 7, 0)), '28 févr. 2027, 07:00');
  });
}
