import 'package:flutter/material.dart';

import '../../app_theme.dart';

import '../../domain/stage_protocol.dart';
import '../../domain/test_record.dart';
import '../../domain/timed_test.dart';

/// Entrées de l'écran d'accueil.
enum HomeEntry {
  cooper('Cooper', 'Course de 12 min', Icons.timer),
  halfCooper('Demi-Cooper', 'Course de 6 min', Icons.bolt),
  vameval('VAMEVAL', 'Paliers sur piste', Icons.stadium),
  lucLeger('Luc Léger', 'Navette aller-retour', Icons.swap_horiz),
  history('Historique', 'Résultats et progression', Icons.show_chart),
  setup('Mise en place', 'Mesurer les repères', Icons.straighten),
  checklists('Checklists', 'Ne rien oublier le jour J', Icons.checklist),
  ghost('Fantôme', 'Bats ta sortie de référence', Icons.person_outline),
  duo('Duo', 'En direct contre la sortie d’un ami', Icons.people),
  simulator(
    'Simulateur de parcours',
    'Allure par section selon le relief',
    Icons.terrain,
  ),
  debrief('Débrief', 'Comment mieux gérer ta course', Icons.insights),
  profile('Mon profil', 'VMA, FC max, FC de repos', Icons.badge),
  zones('Mes zones', 'Allures et FC de Z1 à Z5', Icons.stacked_bar_chart),
  goal('Mon objectif', 'La course qui organise ta préparation', Icons.flag),
  gps('Suivi GPS', 'Vérifier distance et allure en direct', Icons.gps_fixed),
  orthostatic('Test orthostatique', 'Ma forme au réveil', Icons.favorite),
  lanes('Couloirs', 'Distance et allure par couloir', Icons.view_week),
  workouts('Séances', 'Fractionné adapté à ta VMA', Icons.repeat),
  metronome('Métronome', 'Cadence de foulée', Icons.music_note),
  multiTimer('Chrono', 'Plusieurs coureurs, un tap par tour', Icons.timer_10),
  club('Test de groupe', 'VAMEVAL ou navette à plusieurs', Icons.groups),
  fartlek('Fartlek surprise', 'Accélérations au hasard', Icons.shuffle),
  deck('Deck de fractionné', 'Tire tes efforts au hasard', Icons.style);

  const HomeEntry(this.label, this.subtitle, this.icon);

  final String label;
  final String subtitle;
  final IconData icon;

  /// Le dégradé de la marque : le même pour tous les écrans.
  List<Color> get gradient => AppGradients.brand;

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
  evaluate('Évaluer', 'Où j’en suis ?', Icons.speed, [
    HomeEntry.cooper,
    HomeEntry.halfCooper,
    HomeEntry.vameval,
    HomeEntry.lucLeger,
    HomeEntry.orthostatic,
    HomeEntry.setup,
  ]),
  train('S’entraîner', 'Comment je progresse ?', Icons.directions_run, [
    HomeEntry.workouts,
    HomeEntry.fartlek,
    HomeEntry.deck,
    HomeEntry.ghost,
    HomeEntry.duo,
  ]),
  race('Courir', 'Comment je gère ma course ?', Icons.flag, [
    HomeEntry.goal,
    HomeEntry.simulator,
    HomeEntry.checklists,
  ]),
  analyze('Analyser', 'Qu’est-ce que je retiens ?', Icons.insights, [
    HomeEntry.debrief,
  ]);

  const JourneyStage(this.label, this.question, this.icon, this.entries);

  final String label;
  final String question;
  final IconData icon;
  final List<HomeEntry> entries;

  List<Color> get gradient => AppGradients.brand;
}
