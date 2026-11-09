import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/deck.dart';

/// Deck équilibré fourni + decks perso.
class DecksController extends AsyncNotifier<List<Deck>> {
  @override
  Future<List<Deck>> build() async {
    final repo = await ref.watch(deckRepositoryProvider.future);
    return [balancedDeck(), ...await repo.all()];
  }

  Future<void> save(Deck deck) async {
    final repo = await ref.read(deckRepositoryProvider.future);
    await repo.save(deck);
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(String id) async {
    final repo = await ref.read(deckRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final decksControllerProvider =
    AsyncNotifierProvider<DecksController, List<Deck>>(DecksController.new);
