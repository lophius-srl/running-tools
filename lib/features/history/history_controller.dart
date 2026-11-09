import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/test_record.dart';

/// Historique affiché, rechargé après chaque suppression.
class HistoryController extends AsyncNotifier<List<TestRecord>> {
  @override
  Future<List<TestRecord>> build() async {
    final repository = await ref.watch(historyRepositoryProvider.future);
    return repository.all();
  }

  Future<void> delete(String id) async {
    final repository = await ref.read(historyRepositoryProvider.future);
    await repository.delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<TestRecord>>(
      HistoryController.new,
    );
