import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/features/common/decimal_text.dart';

void main() {
  test('parseDecimal accepte virgule et point', () {
    expect(parseDecimal('23,77'), 23.77);
    expect(parseDecimal(' 16.5 '), 16.5);
    expect(parseDecimal('abc'), isNull);
    expect(parseDecimal(''), isNull);
  });

  test('formatDecimal sans zéros inutiles', () {
    expect(formatDecimal(8), '8');
    expect(formatDecimal(8.5), '8,5');
    expect(formatDecimal(23.77), '23,77');
    expect(formatDecimal(60), '60');
    expect(formatDecimal(100), '100');
    expect(formatDecimal(10.5), '10,5');
  });
}
