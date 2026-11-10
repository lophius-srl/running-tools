import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/gps_tracker.dart';

/// Résultat de la demande d'accès à la localisation.
enum LocationAccess { granted, denied, disabled }

/// Positions en direct, uniquement pendant une séance.
abstract interface class LocationSource {
  Future<LocationAccess> requestAccess();

  /// Démarre le suivi ; annuler l'abonnement l'arrête net.
  Stream<GpsFix> fixes();
}

/// GPS de l'iPhone. Réglages pensés pour la course : meilleure précision,
/// filtre de 3 m, pas de pause automatique, suivi écran verrouillé avec
/// l'indicateur bleu d'iOS.
class DeviceLocationSource implements LocationSource {
  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.disabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<GpsFix> fixes() =>
      Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 3,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        ),
      ).map(
        (p) => GpsFix(
          time: p.timestamp,
          position: GeoPoint(p.latitude, p.longitude),
          accuracyM: p.accuracy,
        ),
      );
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => DeviceLocationSource(),
);
