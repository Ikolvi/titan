import 'package:titan_bastion/titan_bastion.dart';

import '../data/quest_api.dart';
import '../models/quest.dart';
import 'questboard_pillar.dart';

/// Quest List Pillar — paginated quest listing with Codex.
///
/// Demonstrates: Codex (pagination), Herald (emitting quest completion events),
/// Vigil (error capture), Chronicle (logging).
class QuestListPillar extends Pillar {
  final QuestApi _api;

  QuestListPillar({QuestApi? api}) : _api = api ?? QuestApi.instance;

  // --------------- Codex (Pagination) ---------------

  /// Paginated quest list — loads pages from the simulated API.
  late final quests = codex<Quest>(
    (request) async {
      final items = await _api.fetchPage(
        page: request.page,
        pageSize: request.pageSize,
      );
      return CodexPage(items: items, hasMore: items.length == request.pageSize);
    },
    pageSize: 10,
    name: 'quests',
  );

  // --------------- Lifecycle ---------------

  @override
  void onInit() {
    log.info('Quest list initialized');
    // Load the first page immediately
    quests.loadFirst();
  }

  // --------------- Actions ---------------

  /// Load the next page of quests.
  Future<void> loadMore() => quests.loadNext();

  /// Refresh the quest list from the beginning.
  Future<void> refresh() => quests.refresh();

  /// Complete a quest — updates the list and emits a Herald event.
  Future<void> completeQuest(Quest quest) async {
    try {
      final updated = await _api.completeQuest(quest.id);

      // Update the item in the Codex list
      strike(() {
        quests.items.value = quests.items.value
            .map((q) => q.id == updated.id ? updated : q)
            .toList();
      });

      // Emit Herald event so QuestboardPillar can award glory
      emit(QuestCompletedEvent(updated));

      log.info('Quest "${quest.title}" marked complete');
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'completeQuest');
    }
  }
}
