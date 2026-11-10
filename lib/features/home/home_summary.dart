import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/checklist.dart';
import '../../domain/orthostatic.dart';
import '../../domain/test_record.dart';

/// Ce que l'accueil montre d'un coup d'œil.
class HomeSummary {
  const HomeSummary({this.lastTest, this.form, this.nextRace});

  /// Construit le résumé à partir des données brutes (listes du plus
  /// récent au plus ancien pour les tests).
  factory HomeSummary.from({
    required List<TestRecord> tests,
    required List<OrthostaticResult> orthostatic,
    required List<RaceChecklist> races,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = races.where((r) => !r.raceDate.isBefore(today)).toList()
      ..sort((a, b) => a.raceDate.compareTo(b.raceDate));
    ({OrthostaticResult result, FormStatus status})? form;
    if (orthostatic.isNotEmpty) {
      final [latest, ...previous] = orthostatic;
      form = (
        result: latest,
        status: OrthostaticBaseline.of(previous).statusOf(latest),
      );
    }
    return HomeSummary(
      lastTest: tests.firstOrNull,
      form: form,
      nextRace: upcoming.firstOrNull,
    );
  }

  final TestRecord? lastTest;
  final ({OrthostaticResult result, FormStatus status})? form;
  final RaceChecklist? nextRace;
}

/// « aujourd'hui », « hier », « il y a 12 j ».
String agoText(DateTime date, DateTime now) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  return switch (days) {
    <= 0 => 'aujourd’hui',
    1 => 'hier',
    _ => 'il y a $days j',
  };
}

/// « aujourd'hui », « demain », « dans 9 j ».
String untilText(DateTime date, DateTime now) {
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  return switch (days) {
    <= 0 => 'aujourd’hui',
    1 => 'demain',
    _ => 'dans $days j',
  };
}

final homeSummaryProvider = FutureProvider<HomeSummary>((ref) async {
  final tests = await ref.read(historyRepositoryProvider.future);
  final orthostatic = await ref.read(orthostaticRepositoryProvider.future);
  final checklists = await ref.read(checklistRepositoryProvider.future);
  return HomeSummary.from(
    tests: await tests.all(),
    orthostatic: await orthostatic.all(),
    races: await checklists.races(),
    now: DateTime.now(),
  );
});
