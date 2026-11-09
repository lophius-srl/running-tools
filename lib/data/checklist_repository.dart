import 'dart:io';

import '../domain/checklist.dart';
import 'json_file_store.dart';

/// Modèles personnels et checklists de course.
abstract interface class ChecklistRepository {
  Future<List<ChecklistTemplate>> templates();
  Future<void> saveTemplate(ChecklistTemplate template);
  Future<void> deleteTemplate(String id);

  /// Checklists de course, de la plus proche à la plus lointaine.
  Future<List<RaceChecklist>> races();
  Future<void> saveRace(RaceChecklist race);
  Future<void> deleteRace(String id);
}

class JsonChecklistRepository implements ChecklistRepository {
  JsonChecklistRepository(Directory directory)
    : _store = JsonFileStore(File('${directory.path}/checklists.json'));

  final JsonFileStore _store;

  Future<Map<String, Object?>> _read() async => await _store.read() ?? {};

  Future<void> _write({
    List<ChecklistTemplate>? templates,
    List<RaceChecklist>? races,
  }) async {
    await _store.write({
      'version': 1,
      'templates': [
        for (final t in templates ?? await this.templates()) t.toJson(),
      ],
      'races': [for (final r in races ?? await this.races()) r.toJson()],
    });
  }

  @override
  Future<List<ChecklistTemplate>> templates() async {
    final raw = (await _read())['templates'];
    return raw is List
        ? [
            for (final t in raw)
              if (t is Map<String, Object?>) ?ChecklistTemplate.fromJson(t),
          ]
        : [];
  }

  @override
  Future<void> saveTemplate(ChecklistTemplate template) async => _write(
    templates: [
      for (final t in await templates())
        if (t.id != template.id) t,
      template,
    ],
  );

  @override
  Future<void> deleteTemplate(String id) async => _write(
    templates: [
      for (final t in await templates())
        if (t.id != id) t,
    ],
  );

  @override
  Future<List<RaceChecklist>> races() async {
    final raw = (await _read())['races'];
    return raw is List
        ? ([
            for (final r in raw)
              if (r is Map<String, Object?>) ?RaceChecklist.fromJson(r),
          ]..sort((a, b) => a.raceDate.compareTo(b.raceDate)))
        : [];
  }

  /// Ajoute, ou remplace la checklist de même id (en gardant sa place).
  @override
  Future<void> saveRace(RaceChecklist race) async {
    final current = await races();
    final index = current.indexWhere((r) => r.id == race.id);
    if (index >= 0) {
      current[index] = race;
    } else {
      current.add(race);
    }
    await _write(races: current);
  }

  @override
  Future<void> deleteRace(String id) async => _write(
    races: [
      for (final r in await races())
        if (r.id != id) r,
    ],
  );
}
