import 'package:flutter/material.dart';

import '../../domain/stage_protocol.dart';
import '../../domain/test_record.dart';
import '../../domain/timed_test.dart';

/// Entrées de l'écran d'accueil.
enum HomeEntry {
  cooper('Cooper', 'Course de 12 min', Icons.timer, [
    Color(0xFF1E63E9),
    Color(0xFF0891B2),
  ]),
  halfCooper('Demi-Cooper', 'Course de 6 min', Icons.bolt, [
    Color(0xFF0284C7),
    Color(0xFF06B6D4),
  ]),
  vameval('VAMEVAL', 'Paliers sur piste', Icons.stadium, [
    Color(0xFF4338CA),
    Color(0xFF2563EB),
  ]),
  lucLeger('Luc Léger', 'Navette aller-retour', Icons.swap_horiz, [
    Color(0xFF0F766E),
    Color(0xFF0EA5E9),
  ]),
  history('Historique', 'Résultats et progression', Icons.show_chart, [
    Color(0xFF1E63E9),
    Color(0xFF38B6FF),
  ]),
  setup('Mise en place', 'Mesurer les repères', Icons.straighten, [
    Color(0xFF0B2A6F),
    Color(0xFF1E63E9),
  ]),
  lanes('Couloirs', 'Distance et allure par couloir', Icons.view_week, [
    Color(0xFF1E40AF),
    Color(0xFF0EA5E9),
  ]),
  workouts('Séances', 'Fractionné adapté à ta VMA', Icons.repeat, [
    Color(0xFF4338CA),
    Color(0xFF0EA5E9),
  ]);

  const HomeEntry(this.label, this.subtitle, this.icon, this.gradient);

  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  static const tests = [cooper, halfCooper, vameval, lucLeger];
  static const training = [workouts, lanes];
  static const tools = [history, setup];

  /// Entrée de l'accueil d'un test par paliers (pour reprendre ses couleurs).
  static HomeEntry ofStagedTest(StagedTest test) => switch (test) {
    StagedTest.vameval => vameval,
    StagedTest.lucLeger => lucLeger,
  };

  static HomeEntry ofKind(TestKind kind) => switch (kind) {
    TestKind.cooper => cooper,
    TestKind.halfCooper => halfCooper,
    TestKind.vameval => vameval,
    TestKind.lucLeger => lucLeger,
  };

  static HomeEntry ofTimedTest(TimedTest test) => switch (test) {
    TimedTest.cooper => cooper,
    TimedTest.halfCooper => halfCooper,
  };

  /// Test chronométré correspondant, s'il y en a un.
  TimedTest? get timedTest => switch (this) {
    cooper => TimedTest.cooper,
    halfCooper => TimedTest.halfCooper,
    _ => null,
  };

  /// Test par paliers correspondant, s'il y en a un.
  StagedTest? get stagedTest => switch (this) {
    vameval => StagedTest.vameval,
    lucLeger => StagedTest.lucLeger,
    _ => null,
  };
}
