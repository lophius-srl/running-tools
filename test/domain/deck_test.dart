import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/deck.dart';
import 'package:running_tools/domain/workout.dart';

void main() {
  final deck = balancedDeck();
  EffortCard card(String id) => predefinedCards.firstWhere((c) => c.id == id);

  test('durée et points d\'une carte selon la VMA', () {
    // 400 m à 95 % de 15 km/h : 101 s.
    expect(card('c-400').durationFor(15).inMilliseconds, closeTo(101053, 1));
    expect(card('c-sprint').durationFor(15), const Duration(seconds: 30));
    // 1 min à 95 % : 9,5 → 10 points ; 30 s à 115 % : 5,75 → 6.
    expect(card('c-1min').pointsFor(15), 10);
    expect(card('c-sprint').pointsFor(15), 6);
  });

  test('même graine, même deck : même tirage', () {
    final a = DeckDraw.draw(deck, seed: 7, vmaKmh: 15);
    final b = DeckDraw.draw(deck, seed: 7, vmaKmh: 15);
    expect(a.cards.map((c) => c.id), b.cards.map((c) => c.id));
  });

  test('graines différentes : ordres différents', () {
    final orders = {
      for (final seed in [1, 2, 3, 4])
        DeckDraw.draw(
          deck,
          seed: seed,
          vmaKmh: 15,
        ).cards.map((c) => c.id).join(','),
    };
    expect(orders.length, greaterThan(1));
  });

  for (final seed in [1, 42, 1234]) {
    test('graine $seed : durée d\'effort cible respectée', () {
      final draw = DeckDraw.draw(deck, seed: seed, vmaKmh: 15);
      final total = draw.cards.fold(
        Duration.zero,
        (sum, c) => sum + c.durationFor(15),
      );
      expect(total, lessThanOrEqualTo(const Duration(minutes: 12)));
      expect(draw.cards, isNotEmpty);
      expect(draw.cards.length + draw.remainingInDeck, deck.cards.length);
    });
  }

  test('budget d\'intensité respecté', () {
    final limited = Deck(
      id: 'd',
      name: 'Budget',
      cards: deck.cards,
      recovery: const Duration(minutes: 1),
      limit: const PointsLimit(40),
    );
    final draw = DeckDraw.draw(limited, seed: 3, vmaKmh: 15);
    final points = draw.cards.fold(0, (sum, c) => sum + c.pointsFor(15));
    expect(points, lessThanOrEqualTo(40));
    expect(points, greaterThan(20));
  });

  test('séance tirée : une série par carte, récup intercalée', () {
    final draw = DeckDraw.draw(deck, seed: 9, vmaKmh: 15);
    final workout = draw.toWorkout(id: 'w', name: 'Deck du jour');
    expect(workout.sets, hasLength(draw.cards.length));
    expect(workout.sets.every((s) => s.reps == 1), isTrue);
    expect(
      workout.sets.first.recovery!.duration,
      const Duration(minutes: 1, seconds: 30),
    );
    expect(
      workout.sets.first.effort.distanceM,
      draw.cards.first.effort.distanceM,
    );
  });

  test('aller-retour JSON d\'un deck perso', () {
    final custom = Deck(
      id: 'perso',
      name: 'Mes cartes',
      cards: [
        card('c-400'),
        const EffortCard(
          id: 'perso-1',
          title: '800 m à 90 %',
          kind: CardKind.distance,
          effort: Effort.distance(800, percentVma: 90),
        ),
      ],
      recovery: const Duration(minutes: 2),
      limit: const PointsLimit(60),
    );
    final back = Deck.fromJson(custom.toJson())!;
    expect(back.cards.map((c) => c.title), ['400 m à 95 %', '800 m à 90 %']);
    expect(back.recovery, const Duration(minutes: 2));
    expect((back.limit as PointsLimit).points, 60);
    expect(back.builtIn, isFalse);
  });
}
