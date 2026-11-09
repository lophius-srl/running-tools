import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Empêche l'écran de se mettre en veille.
abstract interface class ScreenWakeLock {
  Future<void> enable();
  Future<void> disable();
}

class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final screenWakeLockProvider = Provider<ScreenWakeLock>(
  (ref) => WakelockPlusScreenWakeLock(),
);
