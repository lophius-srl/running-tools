import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/checklist.dart';

void main() {
  final trail = builtInTemplates.firstWhere((t) => t.id == 'tpl-trail');

  RaceChecklist race({ReminderTime? reminder}) => RaceChecklist.fromTemplate(
    trail,
    id: 'c1',
    raceName: 'Trail des Crêtes',
    raceDate: DateTime(2026, 11, 22, 8),
    reminder: reminder,
  );

  test('modèles fournis : route, trail, piste, sortie longue', () {
    expect(builtInTemplates.map((t) => t.name), [
      'Course sur route',
      'Trail',
      'Test VMA sur piste',
      'Sortie longue',
    ]);
    expect(trail.items.where((i) => i.mandatory), hasLength(8));
  });

  test('générée depuis un modèle : tout décoché, obligatoires repris', () {
    final c = race();
    expect(c.items, hasLength(trail.items.length));
    expect(c.checkedCount, 0);
    expect(c.progress, 0);
    expect(c.missingMandatory, hasLength(8));
  });

  test('cocher, progression, complet, tout décocher', () {
    var c = race();
    for (var i = 0; i < c.items.length; i++) {
      c = c.toggle(i);
    }
    expect(c.isComplete, isTrue);
    expect(c.progress, 1);
    expect(c.missingMandatory, isEmpty);

    c = c.toggle(0);
    expect(c.checkedCount, c.items.length - 1);
    expect(c.missingMandatory.single.label, 'Réserve d’eau (1 L minimum)');

    c = c.uncheckAll();
    expect(c.checkedCount, 0);
  });

  test('éléments ponctuels : ajout, doublon et vide ignorés, retrait', () {
    var c = race().addItem('  Bandeau  ');
    expect(c.items.last.label, 'Bandeau');
    expect(c.addItem('Bandeau').items, hasLength(c.items.length));
    expect(c.addItem('  ').items, hasLength(c.items.length));
    c = c.removeItem(c.items.length - 1);
    expect(c.items.any((i) => i.label == 'Bandeau'), isFalse);
  });

  test('rappel la veille à l\'heure choisie, sauf s\'il est passé', () {
    final c = race(reminder: (hour: 20, minute: 30));
    expect(c.reminderAt(DateTime(2026, 11, 9)), DateTime(2026, 11, 21, 20, 30));
    expect(c.reminderAt(DateTime(2026, 11, 21, 21)), isNull);
    expect(race().reminderAt(DateTime(2026, 11, 9)), isNull);
    expect(c.withReminder(null).reminder, isNull);
  });

  test('rappel la veille d\'une course un 1er du mois', () {
    final c = RaceChecklist.fromTemplate(
      trail,
      id: 'c2',
      raceName: 'x',
      raceDate: DateTime(2027, 3, 1, 9),
      reminder: (hour: 19, minute: 0),
    );
    expect(c.reminderAt(DateTime(2027)), DateTime(2027, 2, 28, 19));
  });

  test('aller-retour JSON (modèle et checklist)', () {
    final c = race(reminder: (hour: 20, minute: 0))
        .toggle(2)
        .addItem('Bandeau');
    final back = RaceChecklist.fromJson(c.toJson())!;
    expect(back.raceName, 'Trail des Crêtes');
    expect(back.raceDate, DateTime(2026, 11, 22, 8));
    expect(back.items[2].checked, isTrue);
    expect(back.items.first.mandatory, isTrue);
    expect(back.items.last.label, 'Bandeau');
    expect(back.reminder, (hour: 20, minute: 0));

    final t = ChecklistTemplate.fromJson(trail.copyWith(id: 'perso').toJson())!;
    expect(t.items.first.mandatory, isTrue);
    expect(t.builtIn, isFalse);
  });

  test('identifiant de notification stable et positif', () {
    expect(reminderNotificationId('c1'), reminderNotificationId('c1'));
    expect(reminderNotificationId('c1'), isNot(reminderNotificationId('c2')));
    expect(reminderNotificationId('c1'), greaterThanOrEqualTo(0));
  });
}
