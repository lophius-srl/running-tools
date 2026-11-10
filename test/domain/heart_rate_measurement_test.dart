import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/heart_rate_measurement.dart';

void main() {
  test('FC sur 8 bits', () {
    expect(parseHeartRateMeasurement([0x00, 62]), 62);
    // Autres drapeaux (contact capteur, RR) sans effet sur la valeur.
    expect(parseHeartRateMeasurement([0x16, 148, 0x10, 0x03]), 148);
  });

  test('FC sur 16 bits, petit-boutiste', () {
    expect(parseHeartRateMeasurement([0x01, 0x2C, 0x01]), 300);
    expect(parseHeartRateMeasurement([0x01, 72, 0]), 72);
  });

  test('trames invalides ou sans contact', () {
    expect(parseHeartRateMeasurement([]), isNull);
    expect(parseHeartRateMeasurement([0x00]), isNull);
    expect(parseHeartRateMeasurement([0x01, 72]), isNull);
    expect(parseHeartRateMeasurement([0x00, 0]), isNull);
  });
}
