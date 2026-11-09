import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/data/checklist_repository.dart';
import 'package:running_tools/domain/checklist.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('checklists'));
  tearDown(() => dir.deleteSync(recursive: true));

  RaceChecklist race(String id, DateTime date) => RaceChecklist.fromTemplate(
    builtInTemplates.first,
    id: id,
    raceName: id,
    raceDate: date,
  );

  test(
    'checklists triées par date, mise à jour en place, suppression',
    () async {
      final repo = JsonChecklistRepository(dir);
      await repo.saveRace(race('b', DateTime(2026, 12, 6)));
      await repo.saveRace(race('a', DateTime(2026, 11, 22)));
      await repo.saveRace(race('b', DateTime(2026, 12, 6)).toggle(0));

      final reread = await JsonChecklistRepository(dir).races();
      expect(reread.map((r) => r.id), ['a', 'b']);
      expect(reread.last.items.first.checked, isTrue);

      await repo.deleteRace('a');
      expect((await repo.races()).map((r) => r.id), ['b']);
    },
  );

  test('modèles perso, sans toucher aux checklists', () async {
    final repo = JsonChecklistRepository(dir);
    await repo.saveRace(race('a', DateTime(2026, 11, 22)));
    await repo.saveTemplate(
      const ChecklistTemplate(
        id: 'perso',
        name: 'Semi',
        items: [TemplateItem('Dossard')],
      ),
    );
    expect((await repo.templates()).single.name, 'Semi');
    expect(await repo.races(), hasLength(1));
    await repo.deleteTemplate('perso');
    expect(await repo.templates(), isEmpty);
  });
}
