import 'dart:io';

import '../domain/fartlek.dart';
import 'json_file_store.dart';

/// Une séance fartlek déjà courue, rejouable à l'identique.
class RecentFartlek {
  const RecentFartlek({
    required this.date,
    required this.seed,
    required this.settings,
  });

  final DateTime date;
  final int seed;
  final FartlekSettings settings;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'seed': seed,
    'settings': settings.toJson(),
  };

  static RecentFartlek? fromJson(Map<String, Object?> json) {
    try {
      final settings = FartlekSettings.fromJson(
        json['settings']! as Map<String, Object?>,
      );
      if (settings == null) return null;
      return RecentFartlek(
        date: DateTime.parse(json['date']! as String),
        seed: json['seed']! as int,
        settings: settings,
      );
    } on Object {
      return null;
    }
  }
}

abstract interface class FartlekRepository {
  /// Séances récentes, la plus récente en premier.
  Future<List<RecentFartlek>> recent();
  Future<void> remember(RecentFartlek fartlek);
}

class JsonFartlekRepository implements FartlekRepository {
  JsonFartlekRepository(Directory directory, {this.limit = 10})
    : _store = JsonFileStore(File('${directory.path}/fartleks.json'));

  final int limit;
  final JsonFileStore _store;

  @override
  Future<List<RecentFartlek>> recent() async {
    final raw = (await _store.read())?['recent'];
    return raw is List
        ? [
            for (final r in raw)
              if (r is Map<String, Object?>) ?RecentFartlek.fromJson(r),
          ]
        : [];
  }

  @override
  Future<void> remember(RecentFartlek fartlek) async {
    final list = [
      fartlek,
      for (final r in await recent())
        if (r.seed != fartlek.seed) r,
    ];
    await _store.write({
      'version': 1,
      'recent': [for (final r in list.take(limit)) r.toJson()],
    });
  }
}
