# Chapter XX: The Nexus Connects

*In which Kael discovers that collections deserve their own reactive voice — lists that announce insertions, maps that whisper updates, and sets that toggle membership without copying the entire world.*

---

The performance dashboard was green. Prisms had eliminated unnecessary rebuilds. Conduits guarded every value. The hero profile was snappy.

Then Kael opened the quest board.

A hundred quests, rendered from a `Core<List<Quest>>`. When a new quest arrived from the server, the entire list was replaced. Every quest card rebuilt. The scroll position jumped. Animations stuttered.

"It's the copy-on-write," Kael muttered, staring at the flame chart. Adding one quest to a list of a hundred meant creating a *new* list of a hundred and one, assigning it to the Core, and notifying every dependent that the entire list had changed.

```dart
// The old way — O(n) copy on every mutation
late final quests = core<List<Quest>>([]);

void addQuest(Quest q) {
  quests.value = [...quests.value, q]; // Copy. Everything. Every. Time.
}
```

For small lists, it was fine. For a hundred quests? Noticeable. For a thousand inventory items? Painful. The Core extensions helped with syntax, but they still copied under the hood.

He needed collections that mutated in place and told their dependents *exactly what changed*.

He needed a **Nexus**.

---

## The Nexus — Reactive Collections

> *A Nexus is a meeting point — where reactive state meets collection semantics. Instead of replacing the whole collection to change one element, Nexus mutates in place and emits granular change records.*

### NexusList — The Reactive List

```dart
class QuestBoardPillar extends Pillar {
  // In-place reactive list — no copy-on-write
  late final quests = nexusList<Quest>([], 'quests');

  // Derived values auto-track NexusList reads
  late final activeCount = derived(
    () => quests.value.where((q) => q.isActive).length,
  );

  late final questCount = derived(() => quests.length);

  void addQuest(Quest quest) {
    quests.add(quest); // In-place O(1) amortized, one notification
  }

  void removeQuest(int index) {
    quests.removeAt(index); // In-place O(n), one notification
  }

  void completeQuest(int index) {
    quests[index] = quests[index].copyWith(isActive: false);
  }

  void sortByPriority() {
    quests.sort((a, b) => b.priority.compareTo(a.priority));
  }
}
```

Every mutation notifies dependents exactly once. `activeCount` and `questCount` recompute only when the list they track changes.

"One add, one notification," Kael explained. "Not one add, one copy, one notification."

---

### NexusMap — The Reactive Map

The party scores needed a map — hero names to point values, updated live during raids:

```dart
class RaidPillar extends Pillar {
  late final scores = nexusMap<String, int>({}, 'scores');

  late final topScore = derived(() {
    if (scores.isEmpty) return 0;
    return scores.values.reduce((a, b) => a > b ? a : b);
  });

  void recordDamage(String hero, int damage) {
    scores[hero] = (scores[hero] ?? 0) + damage;
  }

  void removeHero(String name) {
    scores.remove(name);
  }
}
```

`NexusMap` tracks reads — accessing `scores.isEmpty`, `scores.values`, or `scores[hero]` registers the map as a dependency. Mutations like `[]=`, `remove`, and `clear` notify dependents in place.

---

### NexusSet — The Reactive Set

Tags, filters, selections — a set was the natural choice for unique, unordered collections:

```dart
class FilterPillar extends Pillar {
  late final activeTags = nexusSet<String>({'all'}, 'tags');

  late final hasFilters = derived(() => activeTags.length > 1);

  void toggleTag(String tag) {
    activeTags.toggle(tag); // Add if absent, remove if present
  }

  void clearFilters() {
    activeTags.clear();
    activeTags.add('all');
  }

  Set<String> matchingTags(Set<String> available) {
    return activeTags.intersection(available);
  }
}
```

The `toggle` method was Kael's favorite. One call: add if absent, remove if present, notify exactly once.

---

## Change Records — Knowing What Happened

The real power wasn't just efficiency — it was *precision*. Every Nexus mutation records a `NexusChange` that dependents can inspect:

```dart
watch(() {
  // Read to establish dependency
  quests.length;

  // Inspect what just changed
  final change = quests.lastChange;
  if (change == null) return; // Initial run

  switch (change) {
    case NexusInsert(:final index, :final element):
      log.info('Quest added at $index: ${element.name}');
    case NexusRemove(:final index, :final element):
      log.info('Quest removed from $index: ${element.name}');
    case NexusUpdate(:final index, :final oldValue, :final newValue):
      log.info('Quest $index updated: ${oldValue.name} → ${newValue.name}');
    case NexusClear(:final previousLength):
      log.info('All $previousLength quests cleared');
    case NexusBatch(:final operation, :final count):
      log.info('Batch $operation affected $count elements');
  }
});
```

Dart's sealed classes and pattern matching made it exhaustive. The compiler ensured every change type was handled.

"The old list told you *that* something changed," Kael said. "A Nexus tells you *what* changed, *where* it changed, and *what was there before*."

---

## Maps and Sets Have Their Own Changes

Each collection type has its own change vocabulary:

```dart
// Map changes
watch(() {
  scores.length;
  final change = scores.lastChange;
  switch (change) {
    case NexusMapSet(:final key, :final isNew, :final oldValue, :final newValue):
      if (isNew) {
        log.info('New hero: $key with score $newValue');
      } else {
        log.info('$key score: $oldValue → $newValue');
      }
    case NexusMapRemove(:final key, :final value):
      log.info('$key removed (had $value)');
    // ... NexusClear, NexusBatch
    default:
      break;
  }
});

// Set changes
watch(() {
  activeTags.length;
  final change = activeTags.lastChange;
  switch (change) {
    case NexusSetAdd(:final element):
      log.info('Tag added: $element');
    case NexusSetRemove(:final element):
      log.info('Tag removed: $element');
    default:
      break;
  }
});
```

---

## Batch Compatibility

Nexus collections work seamlessly with `titanBatch` and Pillar's `strike`:

```dart
void resetBoard() => strike(() {
  quests.clear();
  scores.clear();
  activeTags.clear();
  activeTags.add('all');
  // Four mutations, one notification wave
});
```

Inside a batch, notifications are deferred until the batch completes. Four mutations, one repaint.

---

## Performance: Nexus vs Copy-on-Write

Kael ran the benchmark. For 10,000 list additions:

| Approach | Mechanism | Cost per Add |
|----------|-----------|-------------|
| `Core<List<T>>` + spread | Copy entire list | O(n) — grows with list size |
| `NexusList<T>.add()` | In-place mutation | O(1) amortized — constant |

For a list of 1,000 items, `Core<List>` copies 1,000 elements on *every mutation*. `NexusList` copies zero. As lists grew larger, the difference became orders of magnitude.

"This is the same list object," Kael pointed out. "No copies ever. Same identity, different contents. The reactive graph handles the rest."

```dart
final list = NexusList<int>(initial: [1, 2, 3]);
final ref1 = list.peek();
list.add(4);
final ref2 = list.peek();
assert(identical(ref1, ref2)); // Same list instance!
```

---

## Nexus in the Pillar

All three collection types are created through Pillar factory methods, ensuring proper lifecycle management:

```dart
class InventoryPillar extends Pillar {
  late final items = nexusList<Item>([], 'items');
  late final equipped = nexusSet<String>({}, 'equipped');
  late final stats = nexusMap<String, int>({'hp': 100}, 'stats');

  late final equippedCount = derived(() => equipped.length);
  late final totalWeight = derived(
    () => items.value.fold(0.0, (sum, item) => sum + item.weight),
  );
}
```

When the Pillar disposes, all Nexus collections are automatically disposed with it — no manual cleanup needed.

---

The quest board was transformed. A hundred quests scrolled smoothly. Adding a new quest triggered one insertion, one notification, one card appearing with a slide animation. The rest of the list stayed perfectly still.

"How much code changed?" the PM asked.

"One import, three type changes." Kael pulled up the diff. `Core<List<Quest>>` became `NexusList<Quest>`. The `value = [...spread]` pattern became direct method calls. Everything else — the `Derived` values, the `Vestige` widgets, the `watch` effects — worked identically.

"The reactive graph doesn't care whether the notification came from replacing a value or mutating in place," Kael explained. "It just knows something changed and propagates accordingly."

The junior developer looked up from the set algebra documentation. "So `intersection` doesn't modify the set?"

"Read-only. Returns a plain `Set`, no notifications. Only mutations notify."

She nodded, toggling filter tags on the quest board. Each tap added or removed a tag with `toggle()` — one method, two behaviors, zero confusion.

---

*The Nexus teaches a simple truth: collections aren't just containers for state — they are state. Give them a reactive voice, and they'll tell you exactly what changed. No copies. No waste. Just precision.*

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
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
| [XVIII](chapter-18-the-conduit-flows.md) | The Conduit Flows |
| [XIX](chapter-19-the-prism-reveals.md) | The Prism Reveals |
| **XX** | **The Nexus Connects** ← You are here |
| [XXI](chapter-21-the-spark-ignites.md) | The Spark Ignites |
