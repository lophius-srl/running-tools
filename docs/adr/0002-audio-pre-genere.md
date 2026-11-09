# 0002 — Bips des tests : piste audio pré-générée

- **Date** : 2026-11-09
- **Statut** : accepté (validé par le spike audio, #7)

## Contexte
Les tests par paliers (VAMEVAL, Luc Léger) reposent sur des bips qui doivent tomber
au bon moment pendant 15 à 20 min : la moindre dérive fausse le résultat.
Le test se fait seul, téléphone en poche, souvent avec de la musique : l'audio doit
continuer écran verrouillé, en mode silencieux, et reprendre après un appel.

## Options étudiées
1. **Timers Dart + lecture d'un son court à chaque bip** : simple, mais la précision
   dépend de la boucle d'événements et des mises en veille d'iOS ; dérive possible.
2. **Piste complète pré-générée, jouée comme un fichier** : précision à l'échantillon,
   un seul lecteur à gérer, comportement iOS identique à une app de musique.
   Coût : génération de quelques secondes et un fichier d'environ 40 Mo.

## Décision
On pré-génère toute la piste du test en WAV, en Dart pur, puis on la lit avec
`just_audio` ; la session iOS est réglée avec `audio_session`.

- **Planning** : calculé en distance cumulée, vitesse constante par palier, un bip
  à chaque multiple de l'espacement ; les instants sont exacts puis arrondis à
  l'échantillon (pas de cumul d'erreurs).
- **Format** : mono, 16 bits, 22,05 kHz (≈ 40 Mo pour 15 min, fichier temporaire).
- **Annonces vocales** : `flutter_tts.synthesizeToFile` (WAV float 32 sur iOS),
  décodées et mixées dans la piste. Si la synthèse échoue, piste avec bips seuls.
  Régler `autoStopSharedSession(false)`, sinon flutter_tts coupe la session audio.
- **Session iOS** : catégorie `playback` (joue en mode silencieux),
  `mixWithOthers`, `duckOthers` en option, `UIBackgroundModes: audio`.
  Reprise après interruption gérée par `just_audio`.
- **Position** : palier en cours et « J'ai décroché » se calculent depuis la
  position de lecture, via le même planning.
- Le natif est isolé derrière l'interface `BeepPlayer`.

## Conséquences
- Avec `duckOthers`, la musique est baissée pendant **tout** le test, pas seulement
  pendant les bips (la session reste active en continu). C'est un réglage utilisateur.
- Changer un paramètre impose de régénérer la piste : on la met en cache tant que
  les réglages ne changent pas.
- Le planning et le rendu WAV sont testables unitairement sans appareil.
