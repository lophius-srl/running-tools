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
  checklists('Checklists', 'Ne rien oublier le jour J', Icons.checklist, [
    Color(0xFF0EA5E9),
    Color(0xFF1E63E9),
  ]),
  ghost('Fantôme', 'Bats ta sortie de référence', Icons.person_outline, [
    Color(0xFF6D28D9),
    Color(0xFF1E63E9),
  ]),
  duo('Duo', 'En direct contre la sortie d’un ami', Icons.people, [
    Color(0xFFC026D3),
    Color(0xFF1E63E9),
  ]),
  simulator(
    'Simulateur de parcours',
    'Allure par section selon le relief',
    Icons.terrain,
    [Color(0xFF15803D), Color(0xFF1E63E9)],
  ),
  debrief('Débrief', 'Comment mieux gérer ta course', Icons.insights, [
    Color(0xFF0E7490),
    Color(0xFF1E63E9),
  ]),
  profile('Mon profil', 'VMA, FC max, FC de repos', Icons.badge, [
    Color(0xFF334155),
    Color(0xFF1E63E9),
  ]),
  zones('Mes zones', 'Allures et FC de Z1 à Z5', Icons.stacked_bar_chart, [
    Color(0xFF0B2A6F),
    Color(0xFF1E63E9),
  ]),
  goal('Mon objectif', 'La course qui organise ta préparation', Icons.flag, [
    Color(0xFFDB2777),
    Color(0xFF1E63E9),
  ]),
  gps('Suivi GPS', 'Vérifier distance et allure en direct', Icons.gps_fixed, [
    Color(0xFF0F766E),
    Color(0xFF1E63E9),
  ]),
  orthostatic('Test orthostatique', 'Ma forme au réveil', Icons.favorite, [
    Color(0xFFDB2777),
    Color(0xFF1E63E9),
  ]),
  lanes('Couloirs', 'Distance et allure par couloir', Icons.view_week, [
    Color(0xFF1E40AF),
    Color(0xFF0EA5E9),
  ]),
  workouts('Séances', 'Fractionné adapté à ta VMA', Icons.repeat, [
    Color(0xFF4338CA),
    Color(0xFF0EA5E9),
  ]),
  metronome('Métronome', 'Cadence de foulée', Icons.music_note, [
    Color(0xFF0F766E),
    Color(0xFF1E63E9),
  ]),
  multiTimer('Chrono', 'Plusieurs coureurs, un tap par tour', Icons.timer_10, [
    Color(0xFF1E63E9),
    Color(0xFF0B2A6F),
  ]),
  club('Test de groupe', 'VAMEVAL ou navette à plusieurs', Icons.groups, [
    Color(0xFF7C3AED),
    Color(0xFF1E63E9),
  ]),
  fartlek('Fartlek surprise', 'Accélérations au hasard', Icons.shuffle, [
    Color(0xFFDC2626),
    Color(0xFF1E63E9),
  ]),
  deck('Deck de fractionné', 'Tire tes efforts au hasard', Icons.style, [
    Color(0xFF7C3AED),
    Color(0xFF1E63E9),
  ]);

  const HomeEntry(this.label, this.subtitle, this.icon, this.gradient);

  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

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

/// Onglets : mon tableau de bord, ma préparation, moi.
enum HomeTab {
  home('Accueil', Icons.home_outlined, Icons.home),
  journey('Ma prépa', Icons.route_outlined, Icons.route),
  me('Moi', Icons.person_outline, Icons.person);

  const HomeTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Écrans rangés dans Moi.
  static const meEntries = [
    HomeEntry.profile,
    HomeEntry.zones,
    HomeEntry.history,
  ];

  /// Outils ponctuels (Moi > Boîte à outils).
  static const toolbox = [
    HomeEntry.lanes,
    HomeEntry.multiTimer,
    HomeEntry.club,
    HomeEntry.metronome,
    HomeEntry.gps,
  ];
}

/// Les 4 étapes de la préparation, chacune avec ses écrans.
enum JourneyStage {
  evaluate(
    'Évaluer',
    'Où j’en suis ?',
    Icons.speed,
    [
      HomeEntry.cooper,
      HomeEntry.halfCooper,
      HomeEntry.vameval,
      HomeEntry.lucLeger,
      HomeEntry.orthostatic,
      HomeEntry.setup,
    ],
    [Color(0xFF0B2A6F), Color(0xFF1E63E9)],
  ),
  train(
    'S’entraîner',
    'Comment je progresse ?',
    Icons.directions_run,
    [
      HomeEntry.workouts,
      HomeEntry.fartlek,
      HomeEntry.deck,
      HomeEntry.ghost,
      HomeEntry.duo,
    ],
    [Color(0xFF4338CA), Color(0xFF0EA5E9)],
  ),
  race(
    'Courir',
    'Comment je gère ma course ?',
    Icons.flag,
    [HomeEntry.goal, HomeEntry.simulator, HomeEntry.checklists],
    [Color(0xFFDB2777), Color(0xFF7C3AED)],
  ),
  analyze(
    'Analyser',
    'Qu’est-ce que je retiens ?',
    Icons.insights,
    [HomeEntry.debrief],
    [Color(0xFF0E7490), Color(0xFF1E63E9)],
  );

  const JourneyStage(
    this.label,
    this.question,
    this.icon,
    this.entries,
    this.gradient,
  );

  final String label;
  final String question;
  final IconData icon;
  final List<HomeEntry> entries;
  final List<Color> gradient;
}
