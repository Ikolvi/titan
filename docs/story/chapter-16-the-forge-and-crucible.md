# Chapter XVI: The Forge & Crucible

*In which Kael tests every transition, captures every state, and learns that confidence grows from proof, not hope.*

> **Package:** Bulwark and Saga are in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use them.

---

"It works on my machine."

Those five words had burned Kael before. The quest submission Loom worked perfectly in development, but in staging, a race condition surfaced. A senior engineer told him: "If you can't reproduce it in a test, it didn't happen." Kael needed a testing harness — something that could watch state transitions, assert before-and-after conditions, and capture entire Pillar states for comparison.

He found three tools for the job: the **Crucible**, the **Snapshot**, and the **Bulwark**.

---

## The Crucible — Testing Harness

> *A crucible is a vessel for high-temperature testing. Titan's Crucible is a vessel for testing Pillars under pressure.*

The Crucible wraps any Pillar, initializes it automatically, and provides assertion helpers:

```dart
import 'package:titan/titan.dart';
import 'package:test/test.dart';

void main() {
  late Crucible<QuestListPillar> crucible;

  setUp(() {
    crucible = Crucible(() => QuestListPillar());
  });

  tearDown(() => crucible.dispose());

  test('initial state is correct', () {
    crucible.expectCore(crucible.pillar.searchQuery, '');
    crucible.expectCore(crucible.pillar.isLoading, false);
  });
}
```

### Tracking Core Changes Over Time

The Crucible can record every value a Core takes during a test:

```dart
test('search updates query and triggers fetch', () async {
  // Start tracking
  crucible.track(crucible.pillar.searchQuery);
  crucible.track(crucible.pillar.isLoading);

  // Perform the action
  await crucible.expectStrike(
    () => crucible.pillar.search('dragon'),
    before: () {
      crucible.expectCore(crucible.pillar.searchQuery, '');
    },
    after: () {
      crucible.expectCore(crucible.pillar.searchQuery, 'dragon');
    },
  );

  // Verify the full timeline of values
  final queryValues = crucible.valuesFor(crucible.pillar.searchQuery);
  expect(queryValues, ['dragon']);

  final loadingValues = crucible.valuesFor(crucible.pillar.isLoading);
  expect(loadingValues, containsAll([true, false]));
});
```

### Sync Strike Assertions

For synchronous mutations, `expectStrikeSync` runs before/after checks immediately:

```dart
test('strike batches updates atomically', () {
  crucible.expectStrikeSync(
    () => crucible.pillar.resetFilters(),
    before: () {
      // Set up preconditions
      crucible.pillar.searchQuery.value = 'old query';
    },
    after: () {
      crucible.expectCore(crucible.pillar.searchQuery, '');
    },
  );
});
```

### CoreChange Records

Every tracked change is timestamped:

```dart
final changes = crucible.changesFor(crucible.pillar.count);
for (final change in changes) {
  print('${change.core.name}: ${change.value} at ${change.timestamp}');
}
```

---

## Snapshots — Capture & Restore State

> *A Snapshot freezes a Pillar's state in time. Compare two Snapshots to see exactly what changed.*

Snapshots capture every named Core in a Pillar:

```dart
// Capture current state
final before = pillar.snapshot(label: 'before-mutation');

// Mutate
pillar.updateQuest('New Title', 42);

// Capture again
final after = pillar.snapshot(label: 'after-mutation');

// Compare
final diff = Snapshot.diff(before, after);
diff.forEach((name, values) {
  print('$name: ${values.$1} → ${values.$2}');
});
// title: Old Title → New Title
// count: 0 → 42
```

### Restoring State

Snapshots can restore a Pillar to a previous state — useful for testing rollbacks or implementing "reset to defaults":

```dart
// Save the clean state
final defaults = pillar.snapshot(label: 'defaults');

// ... user makes changes ...

// Reset to defaults (silent — no UI rebuild)
pillar.restore(defaults);

// Or restore with notifications (triggers reactive rebuilds)
pillar.restore(defaults, notify: true);
```

### Snapshot in Tests

Combined with the Crucible, Snapshots enable powerful state comparison:

```dart
test('saga compensates correctly on failure', () async {
  final before = crucible.pillar.snapshot(label: 'before');

  try {
    await crucible.pillar.runFailingSaga();
  } catch (_) {}

  final after = crucible.pillar.snapshot(label: 'after');

  // After compensation, state should match before
  final diff = Snapshot.diff(before, after);
  expect(diff, isEmpty, reason: 'Saga should have rolled back all changes');
});
```

---

## The Bulwark — Circuit Breaker

> ⚠️ **Deprecated:** Bulwark has been superseded by **Portcullis** ([Chapter XXXVII](chapter-37-the-portcullis-descends.md)), which provides a superset of Bulwark's functionality including `shouldTrip` predicates, `protect()` for function wrapping, and more granular state control. New code should use `portcullis()` instead.

> *A bulwark is a defensive wall. Titan's Bulwark protects your app from cascading failures.*

When an API endpoint fails repeatedly, you don't want to keep hammering it. The Bulwark implements the circuit breaker pattern:

```dart
class QuestApiPillar extends Pillar {
  late final apiBulwark = bulwark<List<Quest>>(
    failureThreshold: 3,
    resetTimeout: const Duration(seconds: 30),
    onOpen: (error) => log.error('API circuit opened: $error'),
    onClose: () => log.info('API circuit recovered'),
    onHalfOpen: () => log.info('Testing API recovery...'),
    name: 'quest-api',
  );

  Future<void> fetchQuests() async {
    try {
      final quests = await apiBulwark.call(() => api.getQuests());
      questList.value = quests;
    } on BulwarkOpenException catch (e) {
      // Circuit is open — don't even try
      log.warning(
        'API unavailable after ${e.failureCount} failures. '
        'Retry in 30 seconds.',
      );
    }
  }
}
```

### The Three States

```
     ┌────────┐     failure count       ┌──────┐
     │ Closed │ ──────>──────────────> │ Open │
     └───┬────┘  >= failureThreshold   └──┬───┘
         │                                 │
     success                          resetTimeout
         │                                 │
         │         ┌──────────┐            │
         └────<────│ Half-Open│ <──────────┘
                   └──────────┘
                    │         │
                 success    failure
                    │         │
                    ▼         ▼
                 Closed      Open
```

- **Closed**: Normal operation. Failures are counted. At `failureThreshold`, the circuit opens.
- **Open**: All calls throw `BulwarkOpenException` immediately. After `resetTimeout`, transitions to half-open.
- **Half-Open**: One call is allowed through. If it succeeds, the circuit closes. If it fails, it re-opens.

### Reactive State in the UI

Because the Bulwark's state is reactive, you can show circuit status:

```dart
Vestige<QuestApiPillar>(
  builder: (context, pillar) {
    if (pillar.apiBulwark.isOpen) {
      return const Banner(
        message: 'Server temporarily unavailable',
        icon: Icons.cloud_off,
      );
    }
    return const QuestListView();
  },
)
```

### Manual Controls

```dart
// Manually trip the circuit (e.g., during maintenance)
apiBulwark.trip();

// Manually reset (e.g., when service recovery is confirmed)
apiBulwark.reset();
```

---

## PillarScope — Scoped Overrides

> *Override Pillars for a subtree — perfect for testing, feature flags, and scoped DI.*

PillarScope lets you replace Pillar instances for a widget subtree without affecting the rest of the app:

```dart
// In tests or storybook-style previews
PillarScope(
  overrides: [mockQuestPillar, testHeroPillar],
  child: const QuestListScreen(),
)
```

Any `Vestige<QuestListPillar>` inside the subtree will receive `mockQuestPillar` instead of the globally registered one. The Pillars must already be initialized.

---

## What Kael Learned

The Crucible caught three bugs in the first test run. The Snapshot comparison proved that the Saga rollback was incomplete — one Core was leaking state. The Bulwark prevented 847 redundant API calls in the first hour of deployment.

"Tests aren't overhead," Kael wrote in the team wiki. "They're the Crucible that proves your architecture holds under fire."

But the CTO had a new requirement: "We need a full audit trail. Every state change, timestamped, with the user who caused it. Compliance needs it by Friday."

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
| **XVI** | **The Forge & Crucible** ← You are here |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
