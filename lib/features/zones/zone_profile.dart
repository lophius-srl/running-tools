import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_repository.dart';
import '../../data/providers.dart';
import '../../domain/zones/zone_inputs.dart';
import '../../domain/zones/zones.dart';

/// Profil et zones : tout ce que les écrans lisent, calculé à un seul
/// endroit.
class ZoneProfile {
  const ZoneProfile({
    required this.vma,
    required this.maxHeartRate,
    required this.restHeartRate,
    required this.data,
    required this.zones,
  });

  final ProfileValue<double>? vma;
  final ProfileValue<int>? maxHeartRate;
  final ProfileValue<int>? restHeartRate;
  final ProfileData data;
  final ZoneSet zones;

  List<ZoneVersion> get versions => data.versions;

  /// Différences avec la version précédente, vide s'il n'y en a pas.
  List<ZoneChange> get lastChanges => versions.length < 2
      ? const []
      : diffZones(versions[versions.length - 2].zones, versions.last.zones);

  /// Les zones ont changé depuis la dernière fois qu'on les a regardées.
  bool get hasUnseenChange => versions.length > data.seenVersions;
}

/// Seul point d'accès aux zones. À invalider après un test, une mesure
/// orthostatique ou une modification du profil.
final zoneProfileProvider = FutureProvider<ZoneProfile>((ref) async {
  final profiles = await ref.read(profileRepositoryProvider.future);
  final history = await ref.read(historyRepositoryProvider.future);
  final orthostatic = await ref.read(orthostaticRepositoryProvider.future);
  final preferences = await ref.read(preferencesRepositoryProvider.future);
  final now = DateTime.now();

  var data = await profiles.read();
  final latestTest = (await history.all()).firstOrNull;
  final observed = await preferences.maxHeartRate();
  final vma = resolveVma(
    manual: data.manualVma,
    latestTest: latestTest == null
        ? null
        : (
            vmaKmh: latestTest.vmaKmh,
            date: latestTest.date,
            kind: latestTest.kind.label,
          ),
  );
  final maxHr = resolveMaxHeartRate(
    manual: data.manualMaxHeartRate,
    observed: observed == null
        ? null
        : (value: observed, date: await preferences.maxHeartRateDate() ?? now),
    birthYear: data.birthYear,
    now: now,
  );
  final rest = resolveRestHeartRate(
    manual: data.manualRestHeartRate,
    lyingMeasures: [
      for (final r in await orthostatic.all()) (bpm: r.lyingBpm, date: r.date),
    ],
  );
  final zones = ZoneService.compute(
    vmaKmh: vma?.value,
    maxHeartRate: maxHr?.value,
    restHeartRate: rest?.value,
    settings: data.settings,
  );
  if ((zones.hasPace || zones.hasHeartRate) &&
      await profiles.recordVersion(zones, now)) {
    data = await profiles.read();
  }
  return ZoneProfile(
    vma: vma,
    maxHeartRate: maxHr,
    restHeartRate: rest,
    data: data,
    zones: zones,
  );
});
