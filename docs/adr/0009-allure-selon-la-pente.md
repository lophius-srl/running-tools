# 0009 — Simulateur : allure selon la pente

- **Date** : 2026-11-10
- **Statut** : accepté

## Contexte
Le simulateur donne une allure cible par section d'un parcours GPX, à partir
d'un objectif de temps ou d'une allure sur le plat. Il faut un modèle
« allure équivalente plat » : de combien ralentir en montée, accélérer en
descente.

## Options étudiées
1. **Règle fixe** (ex. +12 s/km par % de montée) : simple, mais linéaire
   alors que le coût grimpe plus vite sur les fortes pentes.
2. **Coût énergétique de Minetti et al. (2002)**, mesuré sur tapis de −45 %
   à +45 % : `C(i) = 155,4 i⁵ − 30,4 i⁴ − 43,3 i³ + 46,3 i² + 19,5 i + 3,6`
   (J/kg/m, i = pente). Pris tel quel, il promet en descente des gains
   irréalistes (−24 % de temps à −5 %) : en vrai, on freine et on protège
   ses jambes.
3. **Modèle « GAP » de Strava** : calé sur des données de fréquence
   cardiaque, mais non publié.

## Décision
Option 2, corrigée en descente :
- montée (i ≥ 0) : facteur d'allure = `C(i) / C(0)` (+5 % → ~29 % plus lent) ;
- descente : un tiers du gain théorique, `1 + (C(i)/C(0) − 1) / 3`
  (−5 % → ~8 % plus rapide), sans gain supplémentaire au-delà de −10 %.

Le calcul se fait tous les 10 m du profil lissé, puis :
- **objectif de temps** : allure plat = temps visé / distance « équivalent
  plat » (somme des 10 m × facteur) ;
- **allure de base** : temps = allure plat × distance équivalent plat.

Profil : altitudes rééchantillonnées tous les 10 m, moyenne glissante sur
100 m, dénivelé compté avec un seuil de 2 m (comme les montres). Sections :
pente moyenne sur 100 m, seuil ±2 %, portions de moins de 300 m absorbées
par leur voisine.

## Conséquences
- Modèle publié et vérifiable ; ne tient pas compte du terrain (sentier,
  marches), de la fatigue ni de la chaleur.
- Le tiers en descente est un choix prudent, ajustable si tes courses
  réelles montrent que tu descends plus vite.

## Références
Minetti A. E. et al., « Energy cost of walking and running at extreme uphill
and downhill slopes », J. Appl. Physiol. 93, 2002.
