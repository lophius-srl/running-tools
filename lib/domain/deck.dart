import 'dart:math';

import 'workout.dart';

/// Famille d'une carte (pour l'affichage).
enum CardKind { distance, time, sprint, hill, joker }

/// Une carte d'effort.
class EffortCard {
  const EffortCard({
    required this.id,
    required this.title,
    required this.kind,
    required this.effort,
  });

  final String id;

  /// Texte de la carte (« 400 m à 95 % », « Joker »…).
  final String title;
  final CardKind kind;
  final Effort effort;

  /// Durée estimée pour une VMA donnée (distance : à l'allure cible).
  Duration durationFor(double vmaKmh) {
    final e = effort;
    if (e.duration case final d?) return d;
    final speed = vmaKmh * (e.percentVma ?? 100) / 100;
    return Duration(
      milliseconds: (e.distanceM! / (speed / 3.6) * 1000).round(),
    );
  }

  /// Points d'intensité : minutes d'effort × intensité relative × 10.
  int pointsFor(double vmaKmh) {
    final minutes = durationFor(vmaKmh).inMilliseconds / 60000;
    final intensity = (effort.percentVma ?? 100) / 100;
    return max(1, (minutes * intensity * 10).round());
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'effort': effort.toJson(),
  };

  static EffortCard? fromJson(Map<String, Object?> json) {
    try {
      return EffortCard(
        id: json['id']! as String,
        title: json['title']! as String,
        kind: CardKind.values.byName(json['kind']! as String),
        effort: Effort.fromJson(json['effort']! as Map<String, Object?>),
      );
    } on Object {
      return null;
    }
  }
}

/// Limite d'un deck : budget d'intensité OU durée d'effort cible.
sealed class DeckLimit {
  const DeckLimit();
}

class PointsLimit extends DeckLimit {
  const PointsLimit(this.points);

  final int points;
}

class DurationLimit extends DeckLimit {
  const DurationLimit(this.effortTime);

  /// Temps d'effort cumulé visé (récupérations non comprises).
  final Duration effortTime;
}

/// Un paquet de cartes et ses règles.
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.cards,
    required this.recovery,
    required this.limit,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final List<EffortCard> cards;

  /// Récupération intercalée automatiquement entre deux efforts.
  final Duration recovery;
  final DeckLimit limit;
  final bool builtIn;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'cards': [for (final c in cards) c.toJson()],
    'recoverySeconds': recovery.inSeconds,
    if (limit case PointsLimit(:final points)) 'points': points,
    if (limit case DurationLimit(:final effortTime))
      'effortSeconds': effortTime.inSeconds,
  };

  static Deck? fromJson(Map<String, Object?> json) {
    try {
      final points = json['points'] as int?;
      return Deck(
        id: json['id']! as String,
        name: json['name']! as String,
        cards: [
          for (final c in json['cards']! as List)
            ?EffortCard.fromJson(c as Map<String, Object?>),
        ],
        recovery: Duration(seconds: json['recoverySeconds']! as int),
        limit: points != null
            ? PointsLimit(points)
            : DurationLimit(Duration(seconds: json['effortSeconds']! as int)),
      );
    } on Object {
      return null;
    }
  }
}

/// Cartes tirées pour une séance : même graine + même deck = même tirage.
class DeckDraw {
  DeckDraw._(this.deck, this.seed, this.cards);

  /// Mélange le paquet puis tire les cartes dans l'ordre tant que la limite
  /// n'est pas dépassée (une carte qui ferait dépasser est sautée).
  factory DeckDraw.draw(
    Deck deck, {
    required int seed,
    required double vmaKmh,
  }) {
    final shuffled = [...deck.cards]..shuffle(Random(seed));
    final drawn = <EffortCard>[];
    var usedPoints = 0;
    var time = Duration.zero;
    for (final card in shuffled) {
      final p = card.pointsFor(vmaKmh);
      final d = card.durationFor(vmaKmh);
      final fits = switch (deck.limit) {
        PointsLimit(:final points) => usedPoints + p <= points,
        DurationLimit(:final effortTime) => time + d <= effortTime,
      };
      if (!fits) continue;
      drawn.add(card);
      usedPoints += p;
      time += d;
    }
    return DeckDraw._(deck, seed, List.unmodifiable(drawn));
  }

  final Deck deck;
  final int seed;
  final List<EffortCard> cards;

  /// Cartes du paquet non tirées.
  int get remainingInDeck => deck.cards.length - cards.length;

  /// La séance tirée, prête pour le plan, la bande-son et « Mes séances ».
  Workout toWorkout({required String id, required String name}) => Workout(
    id: id,
    name: name,
    sets: [
      for (final c in cards)
        WorkoutSet(
          reps: 1,
          effort: c.effort,
          recovery: Recovery.time(deck.recovery),
        ),
    ],
  );
}

/// Cartes prédéfinies.
const predefinedCards = [
  EffortCard(
    id: 'c-200',
    title: '200 m à 100 %',
    kind: CardKind.distance,
    effort: Effort.distance(200, percentVma: 100),
  ),
  EffortCard(
    id: 'c-300',
    title: '300 m à 98 %',
    kind: CardKind.distance,
    effort: Effort.distance(300, percentVma: 98),
  ),
  EffortCard(
    id: 'c-400',
    title: '400 m à 95 %',
    kind: CardKind.distance,
    effort: Effort.distance(400, percentVma: 95),
  ),
  EffortCard(
    id: 'c-600',
    title: '600 m à 92 %',
    kind: CardKind.distance,
    effort: Effort.distance(600, percentVma: 92),
  ),
  EffortCard(
    id: 'c-1000',
    title: '1000 m à 90 %',
    kind: CardKind.distance,
    effort: Effort.distance(1000, percentVma: 90),
  ),
  EffortCard(
    id: 'c-1min',
    title: '1 min vite',
    kind: CardKind.time,
    effort: Effort.time(Duration(minutes: 1), percentVma: 95),
  ),
  EffortCard(
    id: 'c-2min',
    title: '2 min vite',
    kind: CardKind.time,
    effort: Effort.time(Duration(minutes: 2), percentVma: 90),
  ),
  EffortCard(
    id: 'c-sprint',
    title: '30 s sprint',
    kind: CardKind.sprint,
    effort: Effort.time(Duration(seconds: 30), percentVma: 115),
  ),
  EffortCard(
    id: 'c-cote',
    title: 'Côte 45 s',
    kind: CardKind.hill,
    effort: Effort.time(Duration(seconds: 45)),
  ),
  EffortCard(
    id: 'c-joker',
    title: 'Joker : 1 min, choisis ton effort',
    kind: CardKind.joker,
    effort: Effort.time(Duration(minutes: 1)),
  ),
];

EffortCard _card(String id) => predefinedCards.firstWhere((c) => c.id == id);

/// Deck équilibré : distances, temps, sprints, côte et joker, ~12 min
/// d'effort, adapté à la VMA via les allures des cartes.
Deck balancedDeck() => Deck(
  id: 'deck-equilibre',
  name: 'Deck équilibré',
  builtIn: true,
  recovery: const Duration(minutes: 1, seconds: 30),
  limit: const DurationLimit(Duration(minutes: 12)),
  cards: [
    for (final id in [
      'c-200',
      'c-200',
      'c-400',
      'c-400',
      'c-600',
      'c-1min',
      'c-1min',
      'c-2min',
      'c-sprint',
      'c-sprint',
      'c-cote',
      'c-joker',
    ])
      _card(id),
  ],
);
