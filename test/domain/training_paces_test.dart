import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/training_paces.dart';

void main() {
  test('allure : 15 km/h = 4:00 /km, 13 km/h = 4:37 /km', () {
    expect(formatPace(paceForSpeed(15)), '4:00');
    expect(formatPace(paceForSpeed(13)), '4:37');
  });

  test('vitesse nulle refusée', () {
    expect(() => paceForSpeed(0), throwsArgumentError);
  });

  test('zones par défaut pour une VMA de 15 km/h', () {
    final paces = trainingPaces(15);
    expect(paces, hasLength(defaultTrainingZones.length));

    final endurance = paces.first;
    expect(endurance.zone.name, 'Endurance fondamentale');
    expect(endurance.minSpeedKmh, closeTo(9, 1e-9));
    expect(formatPace(endurance.slowestPace), '6:40');
    expect(formatPace(endurance.fastestPace), '5:43');

    final vmaCourte = paces.last;
    expect(formatPace(vmaCourte.fastestPace), '3:49');
  });

  test('zones personnalisées', () {
    final paces = trainingPaces(
      20,
      zones: const [TrainingZone('Test', 50, 100)],
    );
    expect(paces.single.minSpeedKmh, 10);
    expect(formatPace(paces.single.fastestPace), '3:00');
  });
}
