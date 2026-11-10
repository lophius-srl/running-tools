# 0008 — Strava : export GPX plutôt que l'API

- **Date** : 2026-11-10
- **Statut** : accepté

## Contexte
Le fantôme et le duo veulent courir contre une sortie Strava. L'API Strava
passe par OAuth : l'échange du code contre un jeton demande le *client
secret* de l'application Strava. L'app n'a pas de serveur pour le garder.
Par ailleurs, l'API ne donne accès qu'aux activités de l'athlète connecté :
la sortie d'un ami n'y est pas accessible.

## Options étudiées
1. **Secret embarqué dans l'app** (injecté au build, hors git) : extractable
   du binaire, et un jeton à rafraîchir.
2. **Échange via le Worker de running-coach** : le secret reste côté serveur,
   mais l'app dépend alors d'un serveur.
3. **Pas d'API** : export GPX depuis strava.com (« Exporter le GPX » sur une
   activité), puis import dans l'app.

## Décision
Option 3, choisie par le propriétaire. L'import GPX existe déjà ; il sert
aussi pour la sortie d'un ami (qui exporte son GPX et l'envoie).

## Conséquences
- Aucun secret, aucun jeton, aucun réseau.
- Pas d'aide au choix automatique parmi les activités Strava (départ proche,
  distance proche) : on choisit parmi les fantômes déjà importés.
- Si le besoin revient, l'option 1 reste possible sans changer le domaine :
  une activité Strava (streams temps / distance / position) devient un
  `Ghost` comme un GPX.
