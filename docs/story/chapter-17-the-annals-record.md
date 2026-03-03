# Chapter XVII: The Annals Record

*In which Kael builds an audit trail, orchestrates workflows, and bridges Pillars with channels that answer back.*

> **Package:** Annals, Saga, Volley, and Tether are in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use them.

---

The CTO's email was two sentences: "We're pursuing SOC 2 compliance. I need a full audit trail of every state mutation by Friday."

Kael had logging. He had Vigil for errors. But neither told him *who* changed *what*, *when*, and *why*. He needed an immutable, queryable record of every reactive state change in the system. He needed the **Annals**.

---

## The Annals — Audit Trail

> *Annals are historical records kept for posterity. Titan's Annals record every Core mutation, timestamped and attributed.*

### Enabling Auditing

Annals are disabled by default. One line activates them:

```dart
void main() {
  // Enable with a 10,000-entry rolling buffer
  Annals.enable(maxEntries: 10000);

  runApp(const MyApp());
}
```

### Recording Mutations

Any Pillar can record mutations with full context:

```dart
class QuestPillar extends Pillar {
  late final title = core('', name: 'title');
  late final status = core('draft', name: 'status');

  void updateTitle(String newTitle, {required String userId}) {
    final old = title.value;
    title.value = newTitle;

    Annals.record(AnnalEntry(
      coreName: 'title',
      pillarType: 'QuestPillar',
      oldValue: old,
      newValue: newTitle,
      action: 'updateTitle',
      userId: userId,
      metadata: {'source': 'admin-panel'},
    ));
  }

  void publish({required String userId}) {
    final old = status.value;
    status.value = 'published';

    Annals.record(AnnalEntry(
      coreName: 'status',
      pillarType: 'QuestPillar',
      oldValue: old,
      newValue: 'published',
      action: 'publish',
      userId: userId,
    ));
  }
}
```

### Querying the Trail

The Annals support rich queries with combined filters:

```dart
// All mutations by a specific user
final userActions = Annals.query(userId: 'kael-42');

// All title changes in the last hour
final recentTitleChanges = Annals.query(
  coreName: 'title',
  after: DateTime.now().subtract(const Duration(hours: 1)),
);

// All actions by QuestPillar of type 'publish'
final publishes = Annals.query(
  pillarType: 'QuestPillar',
  action: 'publish',
  limit: 50,
);
```

### Exporting for Compliance

```dart
// Export as serializable maps — ready for JSON or CSV
final report = Annals.export(
  pillarType: 'QuestPillar',
  after: DateTime(2025, 1, 1),
);

// Send to compliance server
await complianceApi.submitAuditLog(report);
```

### Streaming Real-Time

The Annals stream is lazy — the underlying `StreamController` is only created on first `.stream` access, preventing resource waste when streaming isn't needed:

```dart
// React to mutations as they happen
Annals.stream.listen((entry) {
  if (entry.action == 'delete') {
    alertAdmin('${entry.userId} deleted ${entry.coreName}');
  }
});
```

### Cleanup

When your app shuts down or you need to release resources, dispose the Annals:

```dart
// Close the stream controller, clear entries, and disable auditing
Annals.dispose();
```

---

## The Saga — Multi-Step Workflows

> *In Norse mythology, sagas are epic tales of great deeds. Titan's Saga orchestrates multi-step async workflows with automatic rollback on failure.*

The quest publication process had five steps: validate → reserve ID → upload assets → register → notify subscribers. If step 4 failed, steps 1-3 needed to be undone. Kael needed a Saga:

```dart
class QuestPublishPillar extends Pillar {
  late final publishSaga = saga<String>(
    steps: [
      SagaStep(
        name: 'validate',
        execute: (prev) async {
          await api.validateQuest(questId);
          return questId;
        },
      ),
      SagaStep(
        name: 'reserve-id',
        execute: (prev) async {
          final id = await api.reservePublicId(prev!);
          return id;
        },
        compensate: (id) async {
          if (id != null) await api.releaseId(id);
        },
      ),
      SagaStep(
        name: 'upload-assets',
        execute: (prev) async {
          await api.uploadAssets(prev!);
          return prev;
        },
        compensate: (id) async {
          if (id != null) await api.deleteAssets(id);
        },
      ),
      SagaStep(
        name: 'register',
        execute: (prev) async {
          await api.registerQuest(prev!);
          return prev;
        },
        compensate: (id) async {
          if (id != null) await api.unregisterQuest(id);
        },
      ),
      SagaStep(
        name: 'notify',
        execute: (prev) async {
          await api.notifySubscribers(prev!);
          return prev;
        },
      ),
    ],
    onComplete: (result) => log.info('Published: $result'),
    onError: (error, step) => log.error('Publish failed at $step: $error'),
    onStepComplete: (name, index, total) {
      log.info('Step $name completed ($index/$total)');
    },
    onCompensationError: (error, stackTrace, stepName) {
      log.error('Compensation failed for $stepName: $error');
    },
    name: 'quest-publish',
  );
}
```

### Running and Monitoring

```dart
// Execute the workflow
final result = await pillar.publishSaga.run();

// Reactive progress tracking
Vestige<QuestPublishPillar>(
  builder: (context, pillar) {
    final saga = pillar.publishSaga;
    return switch (saga.status) {
      SagaStatus.idle => const PublishButton(),
      SagaStatus.running => Column(
          children: [
            LinearProgressIndicator(value: saga.progress),
            Text('Step: ${saga.currentStepName}'),
          ],
        ),
      SagaStatus.completed => const Icon(Icons.check),
      SagaStatus.compensating => const Text('Rolling back...'),
      SagaStatus.failed => Text('Failed: ${saga.error}'),
    };
  },
)
```

If step 3 ("upload-assets") throws, the Saga automatically calls `compensate` on steps 2 and 1 in reverse order — releasing the reserved ID and cleaning up any partial state.

### Compensation Error Tracking

Sometimes compensation steps themselves can fail. Instead of silently swallowing these errors, the Saga tracks them:

```dart
await saga.run();

if (saga.status == SagaStatus.failed) {
  // Check if any rollback steps also failed
  for (final err in saga.compensationErrors) {
    log.error('Rollback failed for ${err.stepName}: ${err.error}');
  }
}
```

Compensation errors are cleared automatically on each `run()` and `reset()`.

---

## The Volley — Batch Async Operations

> *A volley is a simultaneous barrage. Titan's Volley fires off batches of async tasks with concurrency control.*

Unlike Saga (sequential steps with rollback), Volley runs tasks **in parallel** with a concurrency limit:

```dart
class BulkOperationPillar extends Pillar {
  late final imageUploader = volley<String>(
    concurrency: 3, // at most 3 uploads at once
    maxRetries: 2, // retry failed tasks up to 2 times
    retryDelay: const Duration(seconds: 1),
    taskTimeout: const Duration(seconds: 30), // global timeout per task
    onTaskComplete: (name, value) => log.info('Done: $name → $value'),
    onTaskFailed: (name, error) => log.error('Failed: $name: $error'),
    name: 'image-upload',
  );

  Future<void> uploadAllImages(List<File> files) async {
    final tasks = files.map((f) => VolleyTask(
      name: f.name,
      execute: () => api.uploadImage(f),
      timeout: const Duration(seconds: 60), // per-task timeout override
    )).toList();

    final results = await imageUploader.execute(tasks);

    // Handle partial failures
    for (final result in results) {
      if (result.isSuccess) {
        log.info('Uploaded: ${result.taskName} → ${result.valueOrNull}');
      } else {
        log.error('Failed: ${result.taskName}: ${result.errorOrNull}');
      }
    }
  }
}
```

### Progress Tracking & Cancellation

```dart
// Reactive progress in UI
Vestige<BulkOperationPillar>(
  builder: (context, pillar) {
    final v = pillar.imageUploader;
    if (!v.isRunning) return const SizedBox.shrink();

    return Column(
      children: [
        LinearProgressIndicator(value: v.progress),
        Text('${v.completedCount} / ${v.totalCount}'
          ' (${v.successCount} ok, ${v.failedCount} failed)'),
        TextButton(
          onPressed: v.cancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  },
)
```

---

## The Tether — Request-Response Channels

> *A tether is a line that connects two things. Titan's Tether connects Pillars with bidirectional, typed communication.*

Herald events are fire-and-forget. But sometimes Pillar A needs to *ask* Pillar B a question and *wait for the answer*. That's what Tether does.

Tether is **instance-based** — each instance maintains its own registry of handlers with reactive state tracking. A global singleton `Tether.global` provides static convenience methods for app-wide channels.

### Global Convenience API

The simplest way to use Tether is through the global static methods:

```dart
// In QuestPillar — register a handler
class QuestPillar extends Pillar {
  @override
  void onInit() {
    Tether.registerGlobal<String, Quest?>(
      'getQuestById',
      (id) async => await api.fetchQuest(id),
      timeout: const Duration(seconds: 5),
    );
  }

  @override
  void onDispose() {
    Tether.unregisterGlobal('getQuestById');
  }
}

// In HeroPillar — call it
class HeroPillar extends Pillar {
  Future<void> loadActiveQuest(String questId) async {
    // Request-response: typed, async, with timeout
    final quest = await Tether.callGlobal<String, Quest?>(
      'getQuestById',
      questId,
    );

    if (quest != null) {
      activeQuest.value = quest;
    }
  }
}
```

### Instance-Based Usage with Pillar Integration

For scoped channels with lifecycle management and reactive observability, use a Tether instance via the `tether()` factory:

```dart
class OrderPillar extends Pillar {
  late final channels = tether(name: 'orders');

  @override
  void onInit() {
    channels.register<String, double>(
      'getPrice',
      (itemId) async => await pricingApi.getPrice(itemId),
    );
  }
}

// Reactive channel stats
print(channels.registeredCount); // 1
print(channels.callCount);      // number of calls made
print(channels.errorCount);     // number of failed calls
```

### Safe Calls

```dart
// Returns null if no handler is registered (instead of throwing)
final quest = await Tether.tryCallGlobal<String, Quest?>(
  'getQuestById',
  questId,
);
```

### Checking Availability

```dart
if (Tether.hasGlobal('getQuestById')) {
  // Safe to call
}

// All registered global tether names
print(Tether.globalNames); // {getQuestById, getUserProfile, ...}
```

---

## What Kael Learned

The Annals caught a privilege escalation bug on day one — a normal user was calling an admin-only mutation path. The Saga prevented data corruption during a deploy that killed the API mid-publish. The Volley uploaded 200 images in 12 seconds instead of 90. The Tether eliminated 400 lines of manual event-response pairing code.

"The enterprise isn't about complexity," Kael told the new junior developer. "It's about *controlled* complexity. Every tool in Titan has one job, and it does that job with precision."

The junior looked at the Questboard codebase — seventeen chapters of patterns, each building on the last. "Where do I start?"

Kael smiled. "At the First Pillar. It always starts with a Pillar."

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
| [IX](chapter-09-the-scroll-inscribes.md) | The Scroll Inscribes |
| [X](chapter-10-the-codex-opens.md) | The Codex Opens |
| [XI](chapter-11-the-quarry-yields.md) | The Quarry Yields |
| [XII](chapter-12-the-confluence-converges.md) | The Confluence Converges |
| [XIII](chapter-13-the-lens-reveals.md) | The Lens Reveals |
| [XIV](chapter-14-the-enterprise-arsenal.md) | The Enterprise Arsenal |
| [XV](chapter-15-the-loom-weaves.md) | The Loom Weaves |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| **XVII** | **The Annals Record** ← You are here |
| [XVIII](chapter-18-the-conduit-flows.md) | The Conduit Flows |
| [XIX](chapter-19-the-prism-reveals.md) | The Prism Reveals |
| [XX](chapter-20-the-nexus-connects.md) | The Nexus Connects |
| [XXI](chapter-21-the-spark-ignites.md) | The Spark Ignites |
