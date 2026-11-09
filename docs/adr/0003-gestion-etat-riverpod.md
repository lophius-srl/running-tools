# 0003 — Gestion d'état : Riverpod

- **Date** : 2026-11-09
- **Statut** : accepté

## Contexte
L'app a peu d'écrans mais plusieurs services natifs (lecteur audio, ARKit,
synthèse vocale, stockage) qu'on veut remplacer par des fausses versions dans
les tests. Une seule personne maintient le code.

## Options étudiées
1. **`setState` + `ChangeNotifier`** : aucun paquet, mais le passage des services
   entre écrans devient manuel et les tests d'écran plus lourds.
2. **provider** : simple, mais l'injection dépend de l'arbre de widgets.
3. **Riverpod (`flutter_riverpod`, sans génération de code)** : services déclarés
   une fois, remplaçables dans les tests via `overrides`, indépendants de l'arbre.
4. **Bloc** : robuste mais verbeux pour une app de cette taille.

## Décision
`flutter_riverpod`, sans `riverpod_generator` ni `build_runner` : chaque service
natif (`BeepPlayer`, `DistanceMeasurer`, `TestHistoryRepository`) est exposé par un
`Provider` et remplacé par une fausse version dans les tests.

## Conséquences
- Pas d'étape de génération de code : `make lint test build` reste simple.
- La logique métier reste en Dart pur dans `lib/domain/` et ne dépend pas de Riverpod.
- Les écrans simples peuvent garder un `setState` local.
