import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/heart_rate_measurement.dart';

/// Une ceinture cardio trouvée lors de la recherche.
class HeartRateDevice {
  const HeartRateDevice({required this.id, required this.name});

  final String id;
  final String name;
}

/// Ceinture cardio Bluetooth (profil standard Heart Rate).
abstract interface class HeartRateMonitor {
  /// Ceintures visibles (mise à jour continue pendant la recherche).
  Stream<List<HeartRateDevice>> scan();
  Future<void> stopScan();
  Future<void> connect(HeartRateDevice device);

  /// Fréquence cardiaque reçue, en battements par minute.
  Stream<int> get bpm;
  Future<void> disconnect();
}

class BleHeartRateMonitor implements HeartRateMonitor {
  static final _service = Guid('180D');
  static final _measurement = Guid('2A37');

  final _bpm = StreamController<int>.broadcast();
  final _devices = <String, BluetoothDevice>{};
  BluetoothDevice? _connected;
  StreamSubscription<List<int>>? _notifications;

  @override
  Stream<List<HeartRateDevice>> scan() {
    FlutterBluePlus.startScan(
      withServices: [_service],
      timeout: const Duration(seconds: 20),
    );
    return FlutterBluePlus.onScanResults.map((results) {
      for (final r in results) {
        _devices[r.device.remoteId.str] = r.device;
      }
      return [
        for (final r in results)
          HeartRateDevice(
            id: r.device.remoteId.str,
            name: r.device.platformName.isEmpty
                ? 'Ceinture cardio'
                : r.device.platformName,
          ),
      ];
    });
  }

  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();

  @override
  Future<void> connect(HeartRateDevice device) async {
    await stopScan();
    final ble = _devices[device.id];
    if (ble == null) throw StateError('Ceinture introuvable');
    await ble.connect(timeout: const Duration(seconds: 15));
    final services = await ble.discoverServices();
    final characteristic = services
        .firstWhere((s) => s.uuid == _service)
        .characteristics
        .firstWhere((c) => c.uuid == _measurement);
    await _notifications?.cancel();
    _notifications = characteristic.onValueReceived.listen((bytes) {
      if (parseHeartRateMeasurement(bytes) case final bpm?) _bpm.add(bpm);
    });
    await characteristic.setNotifyValue(true);
    _connected = ble;
  }

  @override
  Stream<int> get bpm => _bpm.stream;

  @override
  Future<void> disconnect() async {
    await _notifications?.cancel();
    _notifications = null;
    await _connected?.disconnect();
    _connected = null;
  }
}

/// Crée un moniteur ; l'écran qui l'utilise le libère (déconnexion).
final heartRateMonitorFactoryProvider = Provider<HeartRateMonitor Function()>(
  (ref) => BleHeartRateMonitor.new,
);
