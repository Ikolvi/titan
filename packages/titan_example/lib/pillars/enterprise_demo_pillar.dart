import 'package:titan_basalt/titan_basalt.dart';
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
///   Sigil      — Feature flags\n///   Banner     — Reactive feature flags with rollout & rules
///   Sieve      — Reactive search, filter & sort
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

  // --------------- Banner (Reactive Feature Flags) ---------------

  /// Reactive feature flag registry with rollout, rules, and overrides.
  late final flags = banner(
    flags: [
      const BannerFlag(
        name: 'experimental-ui',
        description: 'New experimental quest UI',
      ),
      const BannerFlag(
        name: 'premium-quests',
        defaultValue: true,
        description: 'Premium quest tier',
      ),
      const BannerFlag(
        name: 'gradual-rollout',
        rollout: 0.5,
        description: 'Feature in 50% rollout',
      ),
    ],
    name: 'questboard',
  );

  /// Whether the experimental UI is enabled (reactive).
  late final showExperimentalUi = derived(
    () => flags['experimental-ui'].value,
    name: 'showExperimentalUi',
  );

  /// Toggle a banner flag override for demo purposes.
  void toggleBannerFlag(String flagName) {
    strike(() {
      if (flags.hasOverride(flagName)) {
        flags.clearOverride(flagName);
      } else {
        flags.setOverride(flagName, !flags.isEnabled(flagName));
      }
    });
  }

  // --------------- Sieve (Reactive Search/Filter/Sort) ---------------

  /// Reactive search, filter & sort engine for the quest list.
  late final questSearch = sieve<Map<String, dynamic>>(
    items: const [
      {'title': 'Dragon Hunt', 'difficulty': 5, 'region': 'Highlands'},
      {'title': 'Herb Gathering', 'difficulty': 1, 'region': 'Meadows'},
      {'title': 'Escort Mission', 'difficulty': 2, 'region': 'Roads'},
      {'title': 'Cave Exploration', 'difficulty': 3, 'region': 'Mountains'},
      {'title': 'Village Defense', 'difficulty': 4, 'region': 'Lowlands'},
      {'title': 'Royal Delivery', 'difficulty': 1, 'region': 'Capital'},
    ],
    textFields: [
      (q) => q['title'] as String,
      (q) => q['region'] as String,
    ],
    name: 'questSearch',
  );

  /// Filter quests by minimum difficulty.
  void filterByDifficulty(int minDifficulty) {
    strike(() {
      if (minDifficulty <= 1) {
        questSearch.removeWhere('difficulty');
      } else {
        questSearch.where(
          'difficulty',
          (q) => (q['difficulty'] as int) >= minDifficulty,
        );
      }
    });
  }

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

  // --------------- Nexus (Reactive Collections) ---------------

  /// An inventory of quest items, managed as a reactive list.
  late final inventory = nexusList<String>([
    'Sword of Dawn',
    'Iron Shield',
    'Health Potion',
  ], 'inventory');

  /// Hero ability scores stored in a reactive map.
  late final abilityScores = nexusMap<String, int>({
    'STR': 14,
    'DEX': 12,
    'CON': 13,
    'INT': 10,
    'WIS': 8,
  }, 'abilityScores');

  /// Active quest tags as a reactive set.
  late final questTags = nexusSet<String>({
    'active',
    'main-story',
  }, 'questTags');

  /// Derived: total inventory count.
  late final inventoryCount = derived(() => inventory.length);

  /// Derived: sum of all ability scores.
  late final totalAbilityScore = derived(
    () => abilityScores.values.fold(0, (a, b) => a + b),
  );

  /// Derived: number of active tags.
  late final tagCount = derived(() => questTags.length);

  /// Add a new item to inventory.
  void addInventoryItem(String item) => inventory.add(item);

  /// Remove an item from inventory by index.
  String removeInventoryItem(int index) => inventory.removeAt(index);

  /// Update an ability score.
  void setAbilityScore(String ability, int score) {
    abilityScores[ability] = score;
  }

  /// Toggle a quest tag.
  void toggleQuestTag(String tag) => questTags.toggle(tag);

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

  // --------------- Trove (Reactive Cache) ---------------

  /// Quest cache with 5-minute TTL and 50 entry max.
  late final questCache = trove<String, Quest>(
    defaultTtl: const Duration(minutes: 5),
    maxEntries: 50,
    onEvict: (key, value, reason) {
      log.debug('Cache evicted quest $key ($reason)');
    },
    name: 'quests',
  );

  /// Derived: summarised cache status for the UI.
  late final cacheStatus = derived(
    () =>
        '${questCache.size.value} cached, '
        '${questCache.hitRate.toStringAsFixed(0)}% hit rate',
  );

  /// Fetch a quest, returning from cache if available.
  Future<Quest> fetchCached(String questId) async {
    return await questCache.getOrPut(questId, () async {
      return await _api.fetchQuest(questId);
    });
  }

  /// Force-evict a quest from the cache.
  void evictQuest(String questId) => questCache.evict(questId);

  /// Clear the entire quest cache.
  void clearCache() => questCache.clear();

  // --------------- Moat (Rate Limiter) ---------------

  /// API rate limiter: max 5 requests per 2 seconds.
  late final apiLimiter = moat(
    maxTokens: 5,
    refillRate: const Duration(seconds: 2),
    onReject: () => log.warning('API rate limited!'),
    name: 'api',
  );

  /// Derived: remaining quota for the UI.
  late final quotaStatus = derived(
    () =>
        '${apiLimiter.remainingTokens.value}/${apiLimiter.maxTokens} '
        'tokens (${apiLimiter.rejections.value} rejected)',
  );

  /// Execute an API call through the rate limiter.
  Future<Quest?> fetchRateLimited(String questId) async {
    return await apiLimiter.guard(
      () => _api.fetchQuest(questId),
      onLimit: () => log.warning('Rate limited — try again later'),
    );
  }

  /// Burn all tokens to demonstrate rate limiting.
  void exhaustLimiter() {
    for (var i = 0; i < apiLimiter.maxTokens + 2; i++) {
      apiLimiter.tryConsume();
    }
  }

  // --------------- Omen (Reactive Async Derived) ---------------

  /// Reactive search term for Omen demo.
  late final omenQuery = core('');

  /// Reactive sort order.
  late final omenSort = core('name');

  /// Omen that auto-re-fetches when query or sort changes.
  late final omenResults = omen<List<String>>(
    () async {
      final q = omenQuery.value;
      final s = omenSort.value;
      // Simulate API call
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final items = [
        'Quest: Defend the Gate',
        'Quest: Forge the Blade',
        'Quest: Scout the Pass',
        'Quest: Guard the Vault',
        'Quest: Chart the Deeps',
      ].where((item) => q.isEmpty || item.toLowerCase().contains(q)).toList();
      if (s == 'name') {
        items.sort();
      } else {
        items.sort((a, b) => b.compareTo(a));
      }
      return items;
    },
    debounce: const Duration(milliseconds: 300),
    name: 'quest-search',
  );

  /// Derived: How many times the Omen has executed.
  late final omenExecStatus = derived(
    () => 'Executions: ${omenResults.executionCount.value}',
  );

  /// Change the search query.
  void updateOmenQuery(String q) => omenQuery.value = q;

  /// Toggle sort order.
  void toggleOmenSort() {
    omenSort.value = omenSort.value == 'name' ? 'reverse' : 'name';
  }

  // --------------- Pyre (Priority Task Queue) ---------------

  /// Priority task queue for background quest processing.
  late final taskQueue = pyre<String>(
    concurrency: 2,
    maxQueueSize: 20,
    maxRetries: 1,
    onTaskComplete: (taskId, result) => log.info('Task $taskId done: $result'),
    onTaskFailed: (taskId, error) => log.warning('Task $taskId failed: $error'),
    onDrained: () => log.info('All tasks drained'),
  );

  /// Derived: Progress display string.
  late final pyreProgressText = derived(() {
    final done = taskQueue.completedCount;
    final total = taskQueue.totalEnqueued;
    final pct = (taskQueue.progress * 100).toInt();
    return total == 0 ? 'No tasks' : '$done/$total ($pct%)';
  });

  /// Enqueue a simulated quest processing task.
  void enqueueQuestTask(String questName, {PyrePriority? priority}) {
    taskQueue.enqueue(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return 'Processed: $questName';
    }, priority: priority ?? PyrePriority.normal);
  }

  /// Enqueue a batch of sample tasks at various priorities.
  void enqueueSampleTasks() {
    enqueueQuestTask('Defend the Gate', priority: PyrePriority.critical);
    enqueueQuestTask('Forge the Blade', priority: PyrePriority.high);
    enqueueQuestTask('Scout the Pass', priority: PyrePriority.normal);
    enqueueQuestTask('Chart the Deeps', priority: PyrePriority.low);
    enqueueQuestTask('Guard the Vault', priority: PyrePriority.high);
  }

  // --------------- Mandate (Reactive Policy Engine) ---------------

  /// User role for permission checks.
  late final userRole = core('viewer');

  /// Whether the user is verified.
  late final isVerified = core(false);

  /// Whether editing is enabled (feature flag).
  late final editingEnabled = core(true);

  /// Edit access — all conditions must pass (allOf strategy).
  late final editAccess = mandate(
    name: 'editAccess',
    writs: [
      Writ(
        name: 'has-role',
        evaluate: () => userRole.value == 'editor' || userRole.value == 'admin',
        reason: 'Editor or admin role required',
      ),
      Writ(
        name: 'is-verified',
        evaluate: () => isVerified.value,
        reason: 'Email verification required',
      ),
      Writ(
        name: 'editing-on',
        evaluate: () => editingEnabled.value,
        reason: 'Editing is disabled',
      ),
    ],
  );

  /// View access — any condition passes (anyOf strategy).
  late final viewAccess = mandate(
    name: 'viewAccess',
    strategy: MandateStrategy.anyOf,
    writs: [
      Writ(
        name: 'is-public',
        evaluate: () => true, // simulated public quest
        reason: 'Quest is not public',
      ),
      Writ(
        name: 'is-member',
        evaluate: () => userRole.value != 'viewer',
        reason: 'Must be a member',
      ),
    ],
  );

  /// Derived: verdict summary text.
  late final editVerdictText = derived(() {
    final v = editAccess.verdict.value;
    switch (v) {
      case MandateGrant():
        return 'Access GRANTED';
      case MandateDenial(:final violations):
        final reasons = violations
            .map((v) => v.reason ?? v.writName)
            .join(', ');
        return 'DENIED: $reasons';
    }
  });

  /// Change the user's role.
  void setUserRole(String role) => userRole.value = role;

  /// Toggle email verification.
  void toggleVerification() => isVerified.value = !isVerified.value;

  /// Toggle editing feature flag.
  void toggleEditing() => editingEnabled.value = !editingEnabled.value;

  // --------------- Ledger (State Transactions) ---------------

  /// Gold balance for demo.
  late final goldBalance = core(1000);

  /// Item inventory for demo.
  late final itemCount = core(50);

  /// Last transaction result message.
  late final txResultMessage = core('No transactions yet');

  /// Transaction manager.
  late final txManager = ledger(maxHistory: 20, name: 'demo');

  /// Purchase items — atomic commit.
  void purchaseItems(int qty, int pricePerItem) {
    final totalCost = qty * pricePerItem;
    txManager.transactSync((tx) {
      tx.capture(goldBalance);
      tx.capture(itemCount);
      goldBalance.value -= totalCost;
      itemCount.value += qty;
      if (goldBalance.value < 0) {
        throw StateError('Insufficient gold');
      }
    }, name: 'purchase');
    txResultMessage.value =
        'Purchased $qty items for $totalCost gold (committed)';
  }

  /// Force a failed transaction to demo rollback.
  void failedPurchase() {
    try {
      txManager.transactSync((tx) {
        tx.capture(goldBalance);
        tx.capture(itemCount);
        goldBalance.value -= 99999;
        itemCount.value += 100;
        throw StateError('Payment declined');
      }, name: 'failed-purchase');
    } catch (_) {
      txResultMessage.value =
          'Transaction rolled back — gold: ${goldBalance.value}, items: ${itemCount.value}';
    }
  }

  /// Reset gold and items.
  void resetLedgerDemo() {
    goldBalance.value = 1000;
    itemCount.value = 50;
    txResultMessage.value = 'Reset complete';
  }

  // --------------- Portcullis (Circuit Breaker) ---------------

  /// Circuit breaker for external API calls.
  late final circuitBreaker = portcullis(
    failureThreshold: 3,
    resetTimeout: const Duration(seconds: 10),
    halfOpenMaxProbes: 1,
    name: 'quest-api',
  );

  /// Simulated call counter.
  late final callResult = core('No calls yet');

  /// Simulate a successful API call.
  Future<void> simulateSuccess() async {
    try {
      await circuitBreaker.protect(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 'ok';
      });
      callResult.value = 'Call succeeded!';
    } on PortcullisOpenException catch (e) {
      callResult.value =
          'BLOCKED: circuit open'
          '${e.remainingTimeout != null ? ' (resets in ${e.remainingTimeout!.inSeconds}s)' : ''}';
    }
  }

  /// Simulate a failing API call.
  Future<void> simulateFailure() async {
    try {
      await circuitBreaker.protect(() async {
        throw Exception('Service unavailable');
      });
    } on PortcullisOpenException catch (e) {
      callResult.value =
          'BLOCKED: circuit open'
          '${e.remainingTimeout != null ? ' (resets in ${e.remainingTimeout!.inSeconds}s)' : ''}';
    } catch (e) {
      callResult.value = 'Call failed: $e';
    }
  }

  /// Manually trip the breaker.
  void tripBreaker() {
    circuitBreaker.trip();
    callResult.value = 'Circuit manually tripped';
  }

  /// Manually reset the breaker.
  void resetBreaker() {
    circuitBreaker.reset();
    callResult.value = 'Circuit manually reset';
  }

  // --------------- Anvil (Dead Letter & Retry Queue) ---------------

  /// The dead letter & retry queue.
  late final retryQueue = anvil<String>(
    maxRetries: 3,
    backoff: AnvilBackoff.exponential(
      initial: const Duration(milliseconds: 500),
      multiplier: 2.0,
    ),
    name: 'quest-retry',
  );

  /// Result message for UI display.
  late final anvilResult = core('Tap a button to test the retry queue');

  /// Simulate a successful operation being enqueued.
  void enqueueSuccess() {
    retryQueue.enqueue(
      () async => 'Quest completed!',
      id: 'success-${DateTime.now().millisecondsSinceEpoch}',
      onSuccess: (result) {
        anvilResult.value = 'Succeeded: $result';
      },
    );
    anvilResult.value = 'Enqueued a successful operation...';
  }

  /// Simulate a failing operation that will be dead-lettered.
  void enqueueFailure() {
    retryQueue.enqueue(
      () async => throw Exception('Quest failed!'),
      id: 'fail-${DateTime.now().millisecondsSinceEpoch}',
      onDeadLetter: (entry) {
        anvilResult.value =
            'Dead lettered: ${entry.id} after ${entry.attempts} attempts';
      },
    );
    anvilResult.value = 'Enqueued a failing operation...';
  }

  /// Retry all dead-lettered entries.
  void retryDead() {
    final count = retryQueue.retryDeadLetters();
    anvilResult.value = 'Re-enqueued $count dead letters';
  }

  /// Purge all dead letters.
  void purgeDead() {
    final count = retryQueue.purge();
    anvilResult.value = 'Purged $count dead letters';
  }

  /// Clear all entries.
  void clearQueue() {
    retryQueue.clear();
    anvilResult.value = 'Queue cleared';
  }
}
