# CLAUDE.md — Règles du projet

> Ce fichier est lu automatiquement par Claude Code (en local et dans GitHub Actions).

## Le projet
- **Nom** : Running Tools
- **But** : app iOS perso pour faire seul des tests de VMA/VO2max (Cooper, demi-Cooper,
  VAMEVAL, navette Luc Léger) : bips fiables, mesure des repères, résultats et historique.
- **Stack** : Flutter / Dart, iOS uniquement (signature gratuite « Personal Team » :
  aucune fonctionnalité réservée au compte payant). État : Riverpod. Stockage : JSON local.
  Audio : just_audio + audio_session + flutter_tts. AR : arkit_plugin. Pas de serveur.
- **Décisions d'architecture** : voir `docs/adr/`

## Commandes (toujours passer par le Makefile)
| Action | Commande |
|---|---|
| Installer | `make install` |
| Lancer en local | `make dev` |
| Lint / format | `make lint` / `make format` |
| Tests | `make test` |
| Build | `make build` |

La CI exécute exactement `make lint test build`. Si ça passe en local, ça passe en CI.

## Interactions avec GitHub (sobriété, obligatoire)
Un compte GitHub peut être suspendu après une activité trop automatisée (c'est arrivé sur running-coach).
Pour rester un usage « humain » :
- **Local d'abord** : tout se vérifie avec `make lint test build` avant le premier push. Un push par étape
  (fin du dev, fin de la QA, corrections de review), jamais un push par commit.
- **Pas de PR brouillon pour faire tourner la CI** : la PR s'ouvre une seule fois, quand le travail est prêt.
- **Pas de surveillance en boucle** : interdit `gh pr checks --watch`, `gh run watch` et les boucles sur l'API.
  Vérifier la CI une seule fois, au moins 3 minutes après le push (`gh pr checks <n°>`), sinon laisser l'humain regarder.
- **Créations en petit nombre** : au plus 20 issues par session, une par une, avec ≥ 30 s entre deux créations.
  Pas de script de création en masse. Au-delà, préparer les fichiers et laisser l'humain les créer.
- **Pas de commentaire automatique** : les reviews et rapports se donnent dans le terminal. Poster sur GitHub
  (`gh pr comment`, `gh pr review`, `gh issue comment`) seulement si l'humain le demande, une fois.
- **Ne jamais écrire `@claude`, `@dependabot` ni `@<login>`** dans un texte publié (déclenche des workflows/notifications).
- **Lecture plutôt qu'écriture** : préférer `git` local (`git diff main...HEAD`, `git log`) à l'API GitHub quand c'est possible.
- Si GitHub répond 403/429 ou « suspended » : s'arrêter immédiatement et prévenir l'humain, sans réessayer.


## Méthode de travail (obligatoire)
1. **Une issue = une branche = une PR.** Branche : `feat/<n°-issue>-court-titre`, `fix/<n°>-...`, `chore/...`.
2. **Jamais de commit direct sur `main`.**
3. **Commits conventionnels** : `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, `ci:`.
   `feat!:` ou `BREAKING CHANGE:` pour une rupture. (Le changelog et les versions en dépendent.)
4. **Petites PR** : viser moins de ~400 lignes modifiées. Sinon, découper l'issue.
5. Chaque PR contient `Closes #<n°>` pour que la carte avance seule dans GitHub Projects.
6. **Tests** : toute nouvelle logique a des tests. Un bug corrigé = un test qui le reproduit.
7. Avant d'ouvrir une PR : `make lint test build` doit passer.

## Conventions de code
- Noms explicites, fonctions courtes, pas de code mort ni de `console.log`/`print` de debug.
- Pas de secrets dans le code : variables d'environnement + `.env.example` tenu à jour.
- Toute décision technique structurante → un ADR dans `docs/adr/`.
- Style : `dart format` + `flutter_lints` (vérifiés par `make lint`).
- Langue : textes d'interface et commentaires en français, identifiants en anglais.
- Structure de `lib/` :
  | Dossier | Contenu | Règle |
  |---|---|---|
  | `domain/` | Protocoles, planning des bips, calculs VMA/VO2max/allures, distance | Dart pur : aucun import `package:flutter` ni plugin |
  | `audio/` | Rendu de la piste (pur) + `BeepPlayer`, synthèse vocale (natif) | Le natif reste derrière `BeepPlayer` |
  | `measure/` | `DistanceMeasurer` : ARKit et saisie manuelle | Le natif reste derrière l'interface |
  | `data/` | `TestHistoryRepository` et son implémentation JSON | |
  | `features/<écran>/` | Widgets et providers d'un écran | Pas de calcul métier ici |
- `test/` reproduit l'arborescence de `lib/`. Le domaine et le rendu audio sont testés
  unitairement ; les écrans avec de fausses versions des services (overrides Riverpod).
- Les services natifs (lecteur, ARKit, synthèse vocale) ne sont pas testés en CI :
  ils se valident sur iPhone (`flutter run --release`).

## Équipe d'agents (`.claude/agents/`)
| Agent | Rôle | Quand l'appeler |
|---|---|---|
| `product-owner` | Découpe une idée en issues avec critères d'acceptation | Nouvelle fonctionnalité |
| `architect` | Choix techniques, ADR, structure | Démarrage, choix structurant |
| `developer` | Implémente une issue, ouvre la PR | Une issue prête (`status: ready`) |
| `qa` | Écrit/complète les tests, cherche les cas limites | Avant ou pendant la PR |
| `reviewer` | Relit une PR selon la checklist | PR ouverte |

Le **propriétaire humain** du repo reste le lead : il valide les issues, relit et merge les PR.
Un agent ne merge jamais une PR et ne modifie jamais la CI ni les règles de branche sans demande explicite.
