import '../models/quest.dart';

/// Simulated backend API for quests.
///
/// Adds realistic delays to simulate network requests.
class QuestApi {
  QuestApi._();
  static final instance = QuestApi._();

  /// All available quests (simulated database).
  final List<Quest> _quests = List.generate(
    42,
    (i) => Quest(
      id: 'quest-$i',
      title: _questTitles[i % _questTitles.length],
      description: _questDescriptions[i % _questDescriptions.length],
      difficulty: QuestDifficulty.values[i % QuestDifficulty.values.length],
      gloryReward:
          QuestDifficulty.values[i % QuestDifficulty.values.length].baseGlory,
    ),
  );

  /// Fetch a page of quests (for Codex pagination).
  Future<List<Quest>> fetchPage({
    required int page,
    required int pageSize,
  }) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final start = page * pageSize;
    if (start >= _quests.length) return [];

    final end = (start + pageSize) > _quests.length
        ? _quests.length
        : start + pageSize;
    return _quests.sublist(start, end);
  }

  /// Total number of quests.
  int get totalQuests => _quests.length;

  /// Fetch a single quest by ID (for Quarry data fetching).
  Future<Quest> fetchQuest(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return _quests.firstWhere(
      (q) => q.id == id,
      orElse: () => throw Exception('Quest "$id" not found'),
    );
  }

  /// Complete a quest (simulated mutation).
  Future<Quest> completeQuest(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final index = _quests.indexWhere((q) => q.id == id);
    if (index == -1) throw Exception('Quest "$id" not found');

    final updated = _quests[index].copyWith(isCompleted: true);
    _quests[index] = updated;
    return updated;
  }
}

const _questTitles = [
  'Slay the Bug Dragon',
  'Refactor the Ancient Monolith',
  'Deploy the Beacon Tower',
  'Map the Uncharted Module',
  'Forge the Universal Adapter',
  'Decrypt the Legacy Cipher',
  'Siege the Memory Leak Fortress',
  'Scout the Dependency Forest',
  'Tame the Async Hydra',
  'Awaken the Sleeping Test Suite',
  'Cleanse the Code Swamp',
  'Repair the Broken Pipeline',
  'Chart the API Gateway',
  'Banish the Null Phantom',
];

const _questDescriptions = [
  'A fearsome bug has been terrorizing the codebase. Track it down and eliminate it.',
  'The ancient monolith grows more unstable by the day. Break it into manageable modules.',
  'The team needs a Beacon Tower to signal state changes across the kingdom.',
  'An uncharted module lies deep in the dependency tree. Map its exports and imports.',
  'Forge an adapter that bridges the old world and the new. Compatibility is key.',
  'A legacy cipher blocks migration. Decrypt it to unlock the next release.',
  'Memory leaks have fortified within the app. Lay siege and reclaim those resources.',
  'The dependency forest is dense and tangled. Scout safe paths through it.',
  'The async hydra spawns futures faster than they resolve. Tame it with proper cancellation.',
  'The test suite sleeps. Awaken it to guard against regressions.',
  'Dead code and unused imports fester in the swamp. Cleanse it all.',
  'The CI pipeline broke again. Repair it before the next release.',
  'The API gateway is undocumented chaos. Chart every endpoint.',
  'Null values haunt the codebase. Banish them with sound null safety.',
];
