import 'package:flutter/material.dart';

/// Entrées de l'écran d'accueil.
enum HomeEntry {
  cooper('Cooper', '12 min, saisie de la distance', Icons.timer),
  halfCooper(
    'Demi-Cooper',
    '6 min, saisie de la distance',
    Icons.timer_outlined,
  ),
  vameval('VAMEVAL', 'Paliers sur piste, bips aux repères', Icons.stadium),
  lucLeger(
    'Navette Luc Léger',
    'Aller-retour, bips aux lignes',
    Icons.swap_horiz,
  ),
  history('Historique', 'Résultats et progression', Icons.show_chart),
  setup('Mise en place', 'Mesurer et placer les repères', Icons.straighten);

  const HomeEntry(this.label, this.subtitle, this.icon);

  final String label;
  final String subtitle;
  final IconData icon;

  static const tests = [cooper, halfCooper, vameval, lucLeger];
  static const tools = [history, setup];
}
