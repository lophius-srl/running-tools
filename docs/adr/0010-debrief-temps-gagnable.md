# 0010 — Débrief : estimation du temps gagnable

- **Date** : 2026-11-10
- **Statut** : accepté

## Contexte
Le débrief veut dire « à effort égal, tu aurais pu gagner X s en courant plus
régulièrement ». Il faut un modèle d'effort qui pénalise les variations
d'allure, sans quoi une allure irrégulière et une allure régulière de même
moyenne coûteraient la même chose.

## Options étudiées
1. **Coût linéaire en distance** (coût par mètre constant, Minetti) : aucune
   pénalité pour l'irrégularité, donc rien à gagner. Ne répond pas au besoin.
2. **Modèle vitesse critique / D′** : physiologiquement juste, mais il faut
   connaître sa vitesse critique et son D′, que l'app ne mesure pas.
3. **Coût convexe simple** : effort = Σ durée × vitesse^k, sur la vitesse
   corrigée de la pente. Accélérer coûte plus que ralentir ne rapporte.

## Décision
Option 3, avec k = 3 :
- la sortie est découpée en tronçons de 200 m (le bruit GPS se moyenne),
  chacun ramené en distance « équivalent plat » (modèle de pente, ADR 0009) ;
- effort total E = Σ Δt × v³, avec v la vitesse équivalent plat du tronçon ;
- à effort égal, l'allure régulière v* vérifie v*² = E / D (D = distance
  équivalent plat totale) ; temps régulier = D / v* ;
- temps gagnable = temps réel en mouvement − temps régulier (toujours ≥ 0).

Pas de calcul pour le fractionné (les variations y sont voulues).

Ordres de grandeur sur nos sorties de référence : allure régulière → 0 s ;
départ à 13,5 km/h sur 3 km puis 11,2 km/h sur 10 km → ~34 s ; même vitesse
sur une bosse de 60 m (6 km) → ~50 s.

## Conséquences
- Estimation, à présenter comme telle (« environ », « à effort égal »).
- k = 3 est un choix de modélisation, pas une mesure : plus k est grand,
  plus l'irrégularité « coûte ». Ajustable (`PacingAnalysis.effortExponent`)
  si les débriefs réels semblent trop sévères ou trop indulgents.
- Pauses exclues (temps en mouvement uniquement).
