import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/cadence_advice.dart';

void main() {
  test('conseil selon l\'écart, tolérance de 3 pas/min', () {
    expect(adviceFor(170, 180), CadenceAdvice.faster);
    expect(adviceFor(177, 180), isNull);
    expect(adviceFor(183, 180), isNull);
    expect(adviceFor(186, 180), CadenceAdvice.slower);
    expect(adviceFor(null, 180), isNull);
  });
}
