# 0004 — Stockage local : fichier JSON

- **Date** : 2026-11-09
- **Statut** : accepté

## Contexte
L'historique contient quelques dizaines de tests par an (date, type, résultats,
setup utilisé). Tout reste sur le téléphone ; pas de compte ni de serveur.

## Options étudiées
1. **shared_preferences** : prévu pour des réglages, pas pour une liste qui grandit.
2. **Fichier JSON** : aucun paquet, lisible, tout tient en mémoire.
3. **SQLite (sqflite / drift)** : requêtes et migrations, mais surdimensionné ici
   (drift ajoute de la génération de code).

## Décision
Un fichier JSON dans le dossier Documents de l'app, derrière l'interface
`TestHistoryRepository`. Écriture atomique (fichier temporaire puis renommage) et
champ `version` pour pouvoir migrer le format. Les réglages simples (derniers
paramètres d'un test) vont dans le même fichier ou dans un second fichier JSON.

## Conséquences
- Lecture complète au démarrage : acceptable jusqu'à plusieurs milliers de tests.
- Si les besoins changent (requêtes, volume), on remplace l'implémentation
  sans toucher aux écrans.
- Un fichier corrompu ne doit pas planter l'app : on le met de côté et on repart vide.
