import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Un échantillon d'accélération sans gravité (m/s²).
typedef AccelSample = ({Duration time, double x, double y, double z});

abstract interface class AccelerometerSource {
  Stream<AccelSample> samples();
}

/// Accéléromètre de l'iPhone, environ 50 échantillons par seconde.
class SensorsPlusAccelerometer implements AccelerometerSource {
  @override
  Stream<AccelSample> samples() {
    final start = DateTime.now();
    return userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).map((e) => (time: e.timestamp.difference(start), x: e.x, y: e.y, z: e.z));
  }
}

final accelerometerProvider = Provider<AccelerometerSource>(
  (ref) => SensorsPlusAccelerometer(),
);
