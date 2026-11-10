import 'dart:io';

import '../domain/ghost.dart';
import '../domain/gps_tracker.dart';
import 'json_file_store.dart';

/// Une course contre le fantôme, résumée (pas de trace).
class GhostRunSummary {
  const GhostRunSummary({
    required this.date,
    required this.ghostName,
    required this.alignment,
    required this.distanceM,
    required this.timeS,
    required this.gapS,
    required this.curve,
    this.rival,
  });

  final DateTime date;
  final String ghostName;
  final GhostAlignment alignment;
  final double distanceM;
  final double timeS;

  /// Écart final (> 0 : devant le fantôme).
  final double gapS;

  /// Écart (s) tous les 100 m.
  final List<(double distanceM, double gapS)> curve;

  /// Prénom de l'ami en duo, sinon `null` (fantôme).
  final String? rival;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'ghost': ghostName,
    'alignment': alignment.name,
    'distanceM': distanceM,
    'timeS': timeS,
    'gapS': gapS,
    'curve': [
      for (final (d, g) in curve) [d, g],
    ],
    if (rival != null) 'rival': rival,
  };

  static GhostRunSummary? fromJson(Map<String, Object?> json) {
    try {
      return GhostRunSummary(
        date: DateTime.parse(json['date']! as String),
        ghostName: json['ghost']! as String,
        alignment: GhostAlignment.values.byName(json['alignment']! as String),
        distanceM: (json['distanceM']! as num).toDouble(),
        timeS: (json['timeS']! as num).toDouble(),
        gapS: (json['gapS']! as num).toDouble(),
        rival: json['rival'] as String?,
        curve: [
          for (final p in json['curve']! as List)
            (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
      );
    } on Object {
      return null;
    }
  }
}

/// Un fantôme enregistré (GPX importé, activité Strava…).
class SavedGhost {
  const SavedGhost({
    required this.id,
    required this.name,
    required this.distanceM,
    required this.timeS,
    this.friend,
  });

  final String id;
  final String name;
  final double distanceM;
  final double timeS;

  /// Prénom de l'ami à qui appartient la sortie (duo), sinon `null`.
  final String? friend;
}

/// Prénoms des amis, sans doublon, par ordre alphabétique.
List<String> friendNames(Iterable<SavedGhost> ghosts) =>
    ({for (final g in ghosts) ?g.friend}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));

abstract interface class GhostRepository {
  /// Courses passées, la plus récente en premier.
  Future<List<GhostRunSummary>> runs();
  Future<void> addRun(GhostRunSummary run);

  Future<List<SavedGhost>> saved();
  Future<SavedGhost> save(Ghost ghost, {String? friend});
  Future<Ghost?> load(String id);
  Future<void> delete(String id);
}

class JsonGhostRepository implements GhostRepository {
  JsonGhostRepository(this.directory)
    : _runs = JsonFileStore(File('${directory.path}/ghost_runs.json')),
      _index = JsonFileStore(File('${directory.path}/ghosts.json'));

  final Directory directory;
  final JsonFileStore _runs;
  final JsonFileStore _index;

  JsonFileStore _ghostFile(String id) =>
      JsonFileStore(File('${directory.path}/ghost_$id.json'));

  @override
  Future<List<GhostRunSummary>> runs() async {
    final raw = (await _runs.read())?['runs'];
    return raw is List
        ? [
            for (final r in raw)
              if (r is Map<String, Object?>) ?GhostRunSummary.fromJson(r),
          ]
        : [];
  }

  @override
  Future<void> addRun(GhostRunSummary run) async => _runs.write({
    'version': 1,
    'runs': [
      for (final r in [run, ...await runs()]) r.toJson(),
    ],
  });

  @override
  Future<List<SavedGhost>> saved() async {
    final raw = (await _index.read())?['ghosts'];
    if (raw is! List) return [];
    return [
      for (final g in raw)
        if (g case {
          'id': final String id,
          'name': final String name,
          'distanceM': final num distanceM,
          'timeS': final num timeS,
        })
          SavedGhost(
            id: id,
            name: name,
            distanceM: distanceM.toDouble(),
            timeS: timeS.toDouble(),
            friend: g['friend'] as String?,
          ),
    ];
  }

  @override
  Future<SavedGhost> save(Ghost ghost, {String? friend}) async {
    final entry = SavedGhost(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: ghost.name,
      distanceM: ghost.totalDistanceM!,
      timeS: ghost.totalTimeS!,
      friend: friend,
    );
    await _ghostFile(entry.id).write({
      'version': 1,
      'name': ghost.name,
      'points': [
        for (final p in ghost.points)
          [p.timeS, p.distanceM, p.position?.latitude, p.position?.longitude],
      ],
    });
    await _writeIndex([entry, ...await saved()]);
    return entry;
  }

  @override
  Future<Ghost?> load(String id) async {
    final json = await _ghostFile(id).read();
    try {
      return Ghost(
        name: json!['name']! as String,
        points: [
          for (final p in json['points']! as List)
            GhostPoint(
              timeS: ((p as List)[0] as num).toDouble(),
              distanceM: (p[1] as num).toDouble(),
              position: p[2] == null
                  ? null
                  : GeoPoint(
                      (p[2] as num).toDouble(),
                      (p[3] as num).toDouble(),
                    ),
            ),
        ],
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> delete(String id) async {
    await _writeIndex([
      for (final g in await saved())
        if (g.id != id) g,
    ]);
    final file = File('${directory.path}/ghost_$id.json');
    if (file.existsSync()) await file.delete();
  }

  Future<void> _writeIndex(List<SavedGhost> ghosts) => _index.write({
    'version': 1,
    'ghosts': [
      for (final g in ghosts)
        {
          'id': g.id,
          'name': g.name,
          'distanceM': g.distanceM,
          'timeS': g.timeS,
          if (g.friend != null) 'friend': g.friend,
        },
    ],
  });
}
