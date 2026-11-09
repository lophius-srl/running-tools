# 0005 — Merge par l'agent, sur demande explicite

- **Date** : 2026-11-09
- **Statut** : accepté (assouplit l'ADR 0001 sur le merge)

## Contexte
L'ADR 0001 réservait le merge à l'humain, et `.claude/settings.json` interdisait
`gh pr merge`. En pratique, le propriétaire relit les PR puis demande souvent à
l'agent d'enchaîner les merges (PR empilées, par exemple) : l'interdiction obligeait
à tout faire à la main.

## Options étudiées
1. **Garder l'interdiction** : sûr, mais répétitif pour des PR déjà relues.
2. **Autoriser le merge sans condition** : l'agent pourrait merger sans relecture.
3. **Autoriser le merge sur demande explicite** : le propriétaire garde la décision,
   l'agent exécute.

## Décision
L'agent principal peut lancer `gh pr merge`, uniquement quand le propriétaire le
demande explicitement pour des PR précises, et seulement si la CI est verte.
Les sous-agents (`developer`, `/work`) ne mergent jamais.

## Conséquences
- La règle `deny` sur `gh pr merge` est retirée ; la commande reste hors de la liste
  `allow`, donc Claude Code demande confirmation à chaque merge (sauf mode auto).
- La décision de merger reste humaine ; seule l'exécution est déléguée.
- Les règles de branche GitHub (PR et CI obligatoires) restent la protection finale.
