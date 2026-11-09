import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../device/reminder_scheduler.dart';
import '../../domain/checklist.dart';

/// Modèles (fournis + perso) et checklists de course.
class ChecklistsState {
  const ChecklistsState({required this.templates, required this.races});

  final List<ChecklistTemplate> templates;
  final List<RaceChecklist> races;

  RaceChecklist? race(String id) => races.where((r) => r.id == id).firstOrNull;
}

class ChecklistsController extends AsyncNotifier<ChecklistsState> {
  @override
  Future<ChecklistsState> build() async {
    final repo = await ref.watch(checklistRepositoryProvider.future);
    return ChecklistsState(
      templates: [...builtInTemplates, ...await repo.templates()],
      races: await repo.races(),
    );
  }

  /// Enregistre et (re)programme le rappel ; `false` si le rappel n'a pas pu
  /// être programmé (autorisation refusée).
  Future<bool> saveRace(RaceChecklist race, {DateTime? now}) async {
    final repo = await ref.read(checklistRepositoryProvider.future);
    await repo.saveRace(race);
    final scheduled = await _reschedule(race, now ?? DateTime.now());
    ref.invalidateSelf();
    await future;
    return scheduled;
  }

  /// Modifications appliquées l'une après l'autre.
  Future<void> _pending = Future.value();

  /// Modifie les éléments de la checklist [id] à partir de sa DERNIÈRE
  /// version enregistrée : deux taps rapprochés ne s'écrasent pas.
  Future<void> edit(String id, RaceChecklist Function(RaceChecklist) change) {
    final next = _pending.then((_) async {
      final repo = await ref.read(checklistRepositoryProvider.future);
      final current = (await repo.races()).where((r) => r.id == id).firstOrNull;
      if (current == null) return;
      await repo.saveRace(change(current));
      ref.invalidateSelf();
      await future;
    });
    _pending = next;
    return next;
  }

  Future<void> deleteRace(String id) async {
    final repo = await ref.read(checklistRepositoryProvider.future);
    await repo.deleteRace(id);
    await ref
        .read(reminderSchedulerProvider)
        .cancel(reminderNotificationId(id));
    ref.invalidateSelf();
    await future;
  }

  Future<void> saveTemplate(ChecklistTemplate template) async {
    final repo = await ref.read(checklistRepositoryProvider.future);
    await repo.saveTemplate(template);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteTemplate(String id) async {
    final repo = await ref.read(checklistRepositoryProvider.future);
    await repo.deleteTemplate(id);
    ref.invalidateSelf();
    await future;
  }

  Future<bool> _reschedule(RaceChecklist race, DateTime now) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final id = reminderNotificationId(race.id);
    await scheduler.cancel(id);
    final at = race.reminderAt(now);
    if (at == null) return true;
    return scheduler.schedule(
      id: id,
      at: at,
      title: 'Demain : ${race.raceName}',
      body: 'Ta checklist est prête à vérifier.',
      payload: race.id,
    );
  }
}

final checklistsControllerProvider =
    AsyncNotifierProvider<ChecklistsController, ChecklistsState>(
      ChecklistsController.new,
    );
