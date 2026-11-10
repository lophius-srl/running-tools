import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

/// Une mesure de fréquence cardiaque datée.
typedef DatedHeartRate = ({DateTime at, int bpm});

/// Fréquences cardiaques enregistrées par l'appareil (Apple Santé).
abstract interface class HeartRateHistory {
  /// Demande l'accès en lecture ; `false` si refusé ou indisponible.
  Future<bool> authorize();

  /// Mesures entre [start] et [end], dans l'ordre chronologique.
  Future<List<DatedHeartRate>> between(DateTime start, DateTime end);
}

/// Lecture des fréquences cardiaques dans HealthKit.
class HealthKitHeartRateHistory implements HeartRateHistory {
  final _health = Health();
  static const _types = [HealthDataType.HEART_RATE];

  @override
  Future<bool> authorize() async {
    try {
      await _health.configure();
      return await _health.requestAuthorization(_types);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<DatedHeartRate>> between(DateTime start, DateTime end) async {
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );
    return [
      for (final p in points)
        if (p.value case NumericHealthValue(:final numericValue))
          (at: p.dateFrom, bpm: numericValue.round()),
    ]..sort((a, b) => a.at.compareTo(b.at));
  }
}

final heartRateHistoryProvider = Provider<HeartRateHistory>(
  (ref) => HealthKitHeartRateHistory(),
);
