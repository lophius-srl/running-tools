# 0007 — Suivi GPS en direct : filtrage et confidentialité

- **Date** : 2026-11-10
- **Statut** : accepté

## Contexte
Le fantôme et le duo ont besoin, pendant la séance, de la distance cumulée et
de la position courante, écran verrouillé. Le GPS d'un téléphone est bruité
(±3 à 10 m) et produit parfois des sauts de plusieurs centaines de mètres.

## Options étudiées
1. **Somme des distances entre points bruts** : surestime de 10 à 15 % (le
   bruit fait zigzaguer la trace) et compte la distance à l'arrêt.
2. **Lissage de la position seule** puis somme : encore ~9 % de trop sur
   nos traces simulées.
3. **Filtre de Kalman position + vitesse**, distance = vitesse lissée × temps :
   à moins de 3 % sur les mêmes traces.

## Décision
Option 3, en Dart pur (`domain/gps_tracker.dart`) :
- points rejetés si précision > 25 m, horodatage en arrière, ou vitesse
  implicite > 11 m/s (en tenant compte de la précision du point) ;
  après 5 rejets de vitesse d'affilée, on repart du GPS (l'estimation était
  fausse) sans compter le saut ;
- vitesse lissée < 1 m/s : arrêté, rien n'est compté ;
- côté iPhone (`geolocator`, MIT) : précision « navigation », activité
  « fitness », filtre de 3 m, pas de pause automatique, mode d'arrière-plan
  `location` avec l'indicateur bleu d'iOS. L'autorisation « pendant
  l'utilisation » suffit, car le suivi démarre app ouverte. Aucune capacité
  payante n'est requise (Personal Team).

**Aucune trace n'est enregistrée** : le suivi ne garde que l'état courant
(distance, position, précision). Seul un résumé de séance pourra aller dans
l'historique.

## Conséquences
- On perd ~1 % au démarrage, le temps que le filtre estime la vitesse.
- Les seuils sont réglables (`GpsFilterSettings`) si les essais réels le
  demandent.
- Le suivi s'arrête net à l'annulation de l'abonnement : pas de réveil après
  la séance.
