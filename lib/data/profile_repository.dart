import 'dart:io';

import '../domain/zones/zone_inputs.dart';
import '../domain/zones/zones.dart';
import 'json_file_store.dart';

/// Une version des zones : quand elles ont changé, et leurs valeurs.
class ZoneVersion {
  const ZoneVersion({required this.date, required this.zones});

  final DateTime date;
  final ZoneSet zones;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    ...zones.toJson(),
  };

  static ZoneVersion? fromJson(Map<String, Object?> json) {
    final zones = ZoneSet.fromJson(json);
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    return zones == null || date == null
        ? null
        : ZoneVersion(date: date, zones: zones);
  }
}

/// Ce que l'utilisateur a saisi pour ses zones.
class ProfileData {
  const ProfileData({
    this.manualVma,
    this.manualMaxHeartRate,
    this.manualRestHeartRate,
    this.birthYear,
    this.settings = const ZoneSettings(),
    this.versions = const [],
    this.seenVersions = 0,
  });

  final ManualValue<double>? manualVma;
  final ManualValue<int>? manualMaxHeartRate;
  final ManualValue<int>? manualRestHeartRate;
  final int? birthYear;
  final ZoneSettings settings;

  /// Historique des zones, la plus ancienne en premier.
  final List<ZoneVersion> versions;

  /// Nombre de versions déjà vues (alerte « tes zones ont changé »).
  final int seenVersions;
}

abstract interface class ProfileRepository {
  Future<ProfileData> read();

  /// `null` efface la saisie : la valeur automatique reprend.
  Future<void> setManualVma(double? value);
  Future<void> setManualMaxHeartRate(int? value);
  Future<void> setManualRestHeartRate(int? value);
  Future<void> setBirthYear(int? year);
  Future<void> setSettings(ZoneSettings settings);

  /// Ajoute une version si les zones ont changé ; `true` si ajoutée.
  Future<bool> recordVersion(ZoneSet zones, DateTime date);
  Future<void> markVersionsSeen();
}

class JsonProfileRepository implements ProfileRepository {
  JsonProfileRepository(Directory directory, {DateTime Function()? clock})
    : _store = JsonFileStore(File('${directory.path}/profile.json')),
      _clock = clock ?? DateTime.now;

  final JsonFileStore _store;
  final DateTime Function() _clock;

  static ManualValue<T>? _manual<T>(Object? json) {
    if (json case {'value': final T value, 'date': final String date}) {
      final d = DateTime.tryParse(date);
      if (d != null) return (value: value, date: d);
    }
    return null;
  }

  @override
  Future<ProfileData> read() async {
    final json = await _store.read() ?? {};
    final manualVma = json['manualVma'];
    return ProfileData(
      manualVma: switch (manualVma) {
        {'value': final num v, 'date': final String d} => (
          value: v.toDouble(),
          date: DateTime.parse(d),
        ),
        _ => null,
      },
      manualMaxHeartRate: _manual<int>(json['manualMaxHeartRate']),
      manualRestHeartRate: _manual<int>(json['manualRestHeartRate']),
      birthYear: json['birthYear'] as int?,
      settings: ZoneSettings.fromJson(
        json['settings'] as Map<String, Object?>?,
      ),
      versions: [
        for (final v in json['versions'] as List? ?? const [])
          if (v is Map<String, Object?>) ?ZoneVersion.fromJson(v),
      ],
      seenVersions: json['seenVersions'] as int? ?? 0,
    );
  }

  Future<void> _set(String key, Object? value) async {
    final current = await _store.read() ?? {};
    await _store.write({...current, 'version': 1, key: value});
  }

  Map<String, Object?>? _dated(num? value) => value == null
      ? null
      : {'value': value, 'date': _clock().toIso8601String()};

  @override
  Future<void> setManualVma(double? value) => _set('manualVma', _dated(value));

  @override
  Future<void> setManualMaxHeartRate(int? value) =>
      _set('manualMaxHeartRate', _dated(value));

  @override
  Future<void> setManualRestHeartRate(int? value) =>
      _set('manualRestHeartRate', _dated(value));

  @override
  Future<void> setBirthYear(int? year) => _set('birthYear', year);

  @override
  Future<void> setSettings(ZoneSettings settings) =>
      _set('settings', settings.toJson());

  @override
  Future<bool> recordVersion(ZoneSet zones, DateTime date) async {
    final data = await read();
    final last = data.versions.lastOrNull;
    if (last != null && last.zones.sameAs(zones)) return false;
    final versions = [...data.versions, ZoneVersion(date: date, zones: zones)];
    // On garde les 30 dernières versions.
    final kept = versions.skip(versions.length > 30 ? versions.length - 30 : 0);
    await _set('versions', [for (final v in kept) v.toJson()]);
    if (data.versions.isEmpty) await _set('seenVersions', 1);
    return true;
  }

  @override
  Future<void> markVersionsSeen() async =>
      _set('seenVersions', (await read()).versions.length);
}
