import 'package:titan_bastion/titan_bastion.dart';

import '../data/quest_api.dart';
import '../models/quest.dart';

// ---------------------------------------------------------------------------
// Quest Status FSM — Loom states & events
// ---------------------------------------------------------------------------

/// States a quest can be in.
enum QuestStatus { available, claiming, active, completed, failed }

/// Events that drive quest status transitions.
enum QuestAction { claim, start, complete, fail, reset }

// ---------------------------------------------------------------------------
// Enterprise Demo Pillar
// ---------------------------------------------------------------------------

/// Demonstrates enterprise Titan features:
///   Loom       — Finite state machine for quest status
///   Bulwark    — Circuit breaker for resilient API calls
///   Saga       — Multi-step workflow (quest publish)
///   Volley     — Batch async operations
///   Sigil      — Feature flags
///   Aegis      — Retry with backoff
///   Annals     — Audit trail
///   Tether     — Request-response channels
///   Core ext   — toggle, increment extensions
///   onInitAsync — Async initialization
///   autoDispose — Auto cleanup
class EnterpriseDemoPillar extends Pillar {
  final QuestApi _api;

  EnterpriseDemoPillar({QuestApi? api}) : _api = api ?? QuestApi.instance;

  // --------------- Loom (Finite State Machine) ---------------

  /// Quest status state machine — only valid transitions are allowed.
  late final questStatus = loom<QuestStatus, QuestAction>(
    initial: QuestStatus.available,
    transitions: {
      (QuestStatus.available, QuestAction.claim): QuestStatus.claiming,
      (QuestStatus.claiming, QuestAction.start): QuestStatus.active,
      (QuestStatus.claiming, QuestAction.fail): QuestStatus.failed,
      (QuestStatus.active, QuestAction.complete): QuestStatus.completed,
      (QuestStatus.active, QuestAction.fail): QuestStatus.failed,
      (QuestStatus.completed, QuestAction.reset): QuestStatus.available,
      (QuestStatus.failed, QuestAction.reset): QuestStatus.available,
    },
    onEnter: {
      QuestStatus.active: () => log.info('Quest is now active!'),
      QuestStatus.completed: () => log.info('Quest completed!'),
    },
    onTransition: (from, event, to) {
      log.debug('Loom: $from --[$event]--> $to');

      // Record in Annals
      if (Annals.isEnabled) {
        Annals.record(
          AnnalEntry(
            coreName: 'questStatus',
            pillarType: 'EnterpriseDemoPillar',
            oldValue: from.name,
            newValue: to.name,
            action: event.name,
          ),
        );
      }
    },
    name: 'questStatus',
  );

  // --------------- Bulwark (Circuit Breaker) ---------------

  /// Circuit breaker protecting API calls.
  late final apiBreaker = bulwark<Quest>(
    failureThreshold: 3,
    resetTimeout: const Duration(seconds: 10),
    onOpen: (error) => log.error('Circuit OPEN: $error'),
    onClose: () => log.info('Circuit recovered'),
    onHalfOpen: () => log.info('Testing recovery...'),
    name: 'api-breaker',
  );

  /// Last fetched quest via the circuit breaker.
  late final protectedQuest = core<Quest?>(null, name: 'protectedQuest');

  // --------------- Saga (Multi-Step Workflow) ---------------

  /// Multi-step quest publish workflow with compensation.
  late final publishSaga = saga<String>(
    steps: [
      SagaStep(
        name: 'validate',
        execute: (prev) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          log.info('Saga: Validating quest...');
          return 'quest-42';
        },
      ),
      SagaStep(
        name: 'reserve-slot',
        execute: (prev) async {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          log.info('Saga: Reserving publication slot...');
          return prev;
        },
        compensate: (id) async {
          log.info('Saga: Releasing reserved slot for $id');
        },
      ),
      SagaStep(
        name: 'publish',
        execute: (prev) async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          // Simulate occasional failure for demonstration
          if (shouldFailSaga.value) {
            throw Exception('Publication server unavailable');
          }
          log.info('Saga: Published quest $prev');
          return prev;
        },
        compensate: (id) async {
          log.info('Saga: Unpublishing quest $id');
        },
      ),
    ],
    onComplete: (result) => log.info('Saga completed: $result'),
    onError: (error, step) => log.error('Saga failed at $step: $error'),
    onStepComplete: (name, index, total) {
      log.info('Saga step "$name" done ($index/$total)');
    },
    name: 'publish-saga',
  );

  /// Toggle to simulate saga failure.
  late final shouldFailSaga = core(false, name: 'shouldFailSaga');

  // --------------- Volley (Batch Async) ---------------

  /// Batch operation runner.
  late final batchRunner = volley<String>(concurrency: 2, name: 'batch-runner');

  // --------------- Core Extensions Demo ---------------

  /// Demo counter for Core extensions (increment/decrement).
  late final counter = core(0, name: 'counter');

  /// Demo toggle for Core extensions.
  late final isSpecialMode = core(false, name: 'isSpecialMode');

  /// Demo list for Core list extensions.
  late final tags = core<List<String>>([
    'combat',
    'stealth',
    'magic',
  ], name: 'tags');

  // --------------- Conduit (Core-Level Middleware) ---------------

  /// Quest reward with clamping — cannot go below 0 or above 10,000.
  late final questReward = core(
    100,
    name: 'questReward',
    conduits: [ClampConduit(min: 0, max: 10000)],
  );

  /// Hero name with trimming and lowercase transformation.
  late final heroNameInput = core(
    '',
    name: 'heroNameInput',
    conduits: [
      TransformConduit<String>((_, v) => v.trim()),
      TransformConduit<String>((_, v) => v.toLowerCase()),
    ],
  );

  /// Validated difficulty level — must be 1-5.
  late final difficulty = core(
    1,
    name: 'difficulty',
    conduits: [
      ValidateConduit<int>(
        (_, v) => (v < 1 || v > 5) ? 'Difficulty must be 1-5' : null,
      ),
    ],
  );

  // --------------- Sigil (Feature Flags) ---------------

  // --------------- Prism (Fine-Grained State Projections) ---------------

  /// Hero profile — a complex object stored in a single Core.
  late final heroProfile = core<Map<String, dynamic>>({
    'name': 'Kael',
    'level': 10,
    'health': 100,
    'mana': 50,
    'guild': 'Ironclad',
  }, name: 'heroProfile');

  /// Prism: Only the hero's name.
  late final prismName = prism<Map<String, dynamic>, String>(
    heroProfile,
    (h) => h['name'] as String,
    name: 'prismName',
  );

  /// Prism: Only the hero's level.
  late final prismLevel = prism<Map<String, dynamic>, int>(
    heroProfile,
    (h) => h['level'] as int,
    name: 'prismLevel',
  );

  /// Prism: Only the hero's health.
  late final prismHealth = prism<Map<String, dynamic>, int>(
    heroProfile,
    (h) => h['health'] as int,
    name: 'prismHealth',
  );

  /// Prism: Combined title from name + level (derived from source Core).
  late final prismTitle = prism<Map<String, dynamic>, String>(heroProfile, (h) {
    final name = h['name'] as String;
    final level = h['level'] as int;
    return '$name the ${level >= 20
        ? "Legendary"
        : level >= 10
        ? "Veteran"
        : "Novice"}';
  }, name: 'prismTitle');

  /// Counter tracking how many times each Prism notified.
  late final prismNotifyCount = core<Map<String, int>>({
    'name': 0,
    'level': 0,
    'health': 0,
    'title': 0,
  }, name: 'prismNotifyCount');

  /// Update hero profile with a specific field change.
  void updateHeroField(String field, dynamic value) {
    strike(() {
      final updated = Map<String, dynamic>.from(heroProfile.value);
      updated[field] = value;
      heroProfile.value = updated;
    });
  }

  /// Wire up Prism listeners to track notifications.
  void _initPrismListeners() {
    prismName.addListener(() {
      final counts = Map<String, int>.from(prismNotifyCount.value);
      counts['name'] = (counts['name'] ?? 0) + 1;
      prismNotifyCount.value = counts;
    });
    prismLevel.addListener(() {
      final counts = Map<String, int>.from(prismNotifyCount.value);
      counts['level'] = (counts['level'] ?? 0) + 1;
      prismNotifyCount.value = counts;
    });
    prismHealth.addListener(() {
      final counts = Map<String, int>.from(prismNotifyCount.value);
      counts['health'] = (counts['health'] ?? 0) + 1;
      prismNotifyCount.value = counts;
    });
    prismTitle.addListener(() {
      final counts = Map<String, int>.from(prismNotifyCount.value);
      counts['title'] = (counts['title'] ?? 0) + 1;
      prismNotifyCount.value = counts;
    });
  }

  // --------------- Sigil (Feature Flags) ---------------

  /// Whether the experimental publish feature is enabled.
  late final experimentalPublish = derived(
    () => Sigil.isEnabled('experimental_publish'),
    name: 'experimentalPublish',
  );

  // --------------- Lifecycle ---------------

  @override
  void onInit() {
    log.info('Enterprise Demo Pillar initialized');

    // Set up Sigil feature flags
    Sigil.register('experimental_publish', true);
    Sigil.register('batch_enabled', true);

    // Enable Annals audit trail
    Annals.enable(maxEntries: 100);

    // Register a Tether handler
    Tether.register<String, String>('getQuestTitle', (id) async {
      final quest = await _api.fetchQuest(id);
      return quest.title;
    }, timeout: const Duration(seconds: 5));

    // Set up Prism notification tracking
    _initPrismListeners();
  }

  @override
  Future<void> onInitAsync() async {
    // Simulate async initialization
    await Future<void>.delayed(const Duration(milliseconds: 800));
    log.info('Enterprise Demo async init complete');
  }

  @override
  void onDispose() {
    Tether.unregister('getQuestTitle');
    Annals.reset();
    Sigil.reset();
  }

  // --------------- Strikes (Actions) ---------------

  /// Fetch a quest through the circuit breaker.
  Future<void> fetchProtected(String questId) async {
    try {
      final quest = await apiBreaker.call(() => _api.fetchQuest(questId));
      protectedQuest.value = quest;
    } on BulwarkOpenException catch (e) {
      log.warning('API unavailable (${e.failureCount} consecutive failures)');
      captureError(e, action: 'fetchProtected');
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'fetchProtected');
    }
  }

  /// Run the quest publish saga.
  Future<void> runPublishSaga() async {
    if (publishSaga.isRunning) return;
    publishSaga.reset();
    await publishSaga.run();
  }

  /// Run a batch of simulated tasks.
  Future<void> runBatch() async {
    if (batchRunner.isRunning) return;
    batchRunner.reset();

    final tasks = List.generate(
      5,
      (i) => VolleyTask<String>(
        name: 'task-$i',
        execute: () async {
          await Future<void>.delayed(Duration(milliseconds: 300 + (i * 200)));
          if (i == 3) throw Exception('Task $i failed intentionally');
          return 'Result $i';
        },
      ),
    );

    await batchRunner.execute(tasks);
  }

  /// Call a Tether handler.
  Future<String?> getQuestTitle(String id) async {
    return Tether.tryCall<String, String>('getQuestTitle', id);
  }

  /// Use Aegis retry to fetch with exponential backoff.
  Future<Quest> fetchWithRetry(String questId) async {
    return Aegis.run(
      () => _api.fetchQuest(questId),
      maxAttempts: 3,
      baseDelay: const Duration(milliseconds: 200),
      strategy: BackoffStrategy.exponential,
      onRetry: (attempt, error, nextDelay) {
        log.warning('Aegis retry $attempt: $error');
      },
    );
  }
}
