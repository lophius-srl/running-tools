# 0006 — Correcteur de couloir : formule utilisée

- **Date** : 2026-11-09
- **Statut** : accepté

## Contexte
Sur une piste de 400 m, un tour est plus long dans les couloirs extérieurs.
Le lièvre sonore, les séances et le chrono doivent en tenir compte.

## Options étudiées
1. **Approximation « + 2π × 1,22 m par couloir »** : simple, mais fausse de 0,63 m
   entre les couloirs 1 et 2 (mesure à 30 cm puis 20 cm du bord).
2. **Géométrie réglementaire** : exacte pour une piste standard.

## Décision
Piste standard World Athletics : lignes droites de 84,39 m, rayon de la lice
36,50 m, couloirs de 1,22 m (ligne de droite comprise).

- Rayon de la ligne de course : couloir 1 = 36,50 + 0,30 ; couloir n ≥ 2 =
  36,50 + 1,22 × (n − 1) + 0,20.
- Tour = 2 × 84,39 + 2π × rayon.

| Couloir | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Tour (m) | 400,00 | 407,04 | 414,70 | 422,37 | 430,03 | 437,70 | 445,37 | 453,03 |

Une distance « nominale » (comptée en couloir 1) est convertie avec le rapport
tour(n) / tour(1). C'est exact pour des tours complets et une moyenne pour une
fraction de tour (seuls les virages s'allongent).

## Conséquences
- Code : `lib/domain/track_lanes.dart`, valeurs de contrôle testées.
- Pistes non standard (autres rayons) : paramètres de `TrackGeometry` à exposer
  plus tard si besoin.
