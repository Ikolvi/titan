# Chapter XL: The Sieve Filters

> *"Before the Sieve, every search was a journey into chaos — raw lists combed line by line, filters hand-built and hand-broken, sort orders tangled like yarn in the wind. Heroes deserved better. They deserved a single lens through which any collection could be queried, filtered, and ordered — all reactively, all in concert with the Pillar's rhythm."*

---

## The Problem

The Questboard had grown from a handful of quests to a vast archive — thousands of entries spanning every realm. Heroes scrolled endlessly, squinting at titles, trying to find the one quest that matched their skill, their region, and their current mood.

"We need search," Kael announced. "And filters. And sorting. And all of it needs to be instant — when a hero types a letter or slides a difficulty slider, the list should *react* immediately."

Lyra nodded. "That's three separate systems: text search, predicate filtering, and sort ordering. Building them separately means wiring three independent state listeners, debouncing queries, diffing output lists—"

"There must be a simpler way."

"There is." Lyra gestured toward a fine mesh of golden threads strung between two pillars. "The **Sieve**."

---

## The Sieve

A sieve separates the wanted from the unwanted. In Titan, `Sieve<T>` is a reactive search, filter, and sort engine that combines all three concerns into a single, Pillar-managed component:

```dart
class QuestPillar extends Pillar {
  late final search = sieve<Quest>(
    items: allQuests,
    textFields: [(q) => q.title, (q) => q.description],
    name: 'questSearch',
  );

  void filterByDifficulty(int min) {
    search.where('difficulty', (q) => q.difficulty >= min);
  }

  void onSearch(String text) {
    search.query.value = text;
  }
}
```

One declaration. Three capabilities. Fully reactive.

---

## How It Works

### Text Search

Text search scans every item's `textFields` for a case-insensitive substring match against the `query` Core:

```dart
// The hero types "dragon" into the search bar
search.query.value = 'dragon';
// Results instantly contain only quests whose title or description
// contains "dragon" — Dragon Hunt, Dragon Egg, etc.
```

The query itself is a reactive `Core<String>`. Any Vestige reading `search.results` rebuilds the moment the query changes.

### Predicate Filters

Named filters add conditions that stack with AND logic. Each filter is a function that returns `true` for items that should pass:

```dart
// Show only active quests
search.where('status', (q) => q.status == 'active');

// Show only hard quests (difficulty >= 4)
search.where('hard', (q) => q.difficulty >= 4);

// Results now show only active quests with difficulty >= 4
```

Filters can be replaced, removed, or cleared:

```dart
// Replace with a different difficulty threshold
search.where('hard', (q) => q.difficulty >= 3);

// Remove just the difficulty filter
search.removeWhere('hard');

// Remove all filters at once
search.clearFilters();
```

### Sorting

A single comparator controls the order of filtered results:

```dart
search.sortBy((a, b) => a.difficulty.compareTo(b.difficulty));
// Results sorted by difficulty ascending

search.sortBy(null); // Remove sort — return to source order
```

### Combined Pipeline

Search, filters, and sort form a pipeline: **source → text search → predicate filters → sort → results**. Every stage is reactive:

```dart
search.query.value = 'dragon';
search.where('active', (q) => q.status == 'active');
search.sortBy((a, b) => a.title.compareTo(b.title));

// Results: active quests matching "dragon", sorted alphabetically
```

---

## The Reactive Core

The Sieve's power comes from Titan's reactive dependency tracking. Internally, every input — the source `items`, the `query` string, and even the set of active filters — is tracked as a reactive dependency of the `results` Derived:

```
┌──────────────────────────────────────────────┐
│  items (Core<List<T>>)                       │
│  query (Core<String>)                        │──▶ results (Derived<List<T>>)
│  _filterVersion (Core<int>)                  │       │
└──────────────────────────────────────────────┘       ├─▶ resultCount
                                                       ├─▶ totalCount
                                                       └─▶ isFiltered
```

When a filter is added or removed, the internal `_filterVersion` counter bumps. The `results` Derived reads this counter, creating a dependency, so it recomputes automatically. No manual `notifyListeners()`, no streams to wire — just Titan's reactive engine doing what it does best.

---

## Reactive Outputs

Every output is a reactive `Derived` that triggers UI rebuilds:

| Property | Type | Description |
|----------|------|-------------|
| `results` | `Derived<List<T>>` | Filtered, searched, sorted items |
| `resultCount` | `Derived<int>` | Number of matching items |
| `totalCount` | `Derived<int>` | Total source items |
| `isFiltered` | `Derived<bool>` | Whether any filter/search is active |

```dart
// In a Vestige
Vestige<QuestPillar>(
  builder: (context, pillar) {
    final quests = pillar.search.results.value;
    final count = pillar.search.resultCount.value;
    final total = pillar.search.totalCount.value;
    final active = pillar.search.isFiltered.value;

    return Column(
      children: [
        Text('$count of $total quests${active ? " (filtered)" : ""}'),
        ...quests.map((q) => QuestTile(quest: q)),
      ],
    );
  },
)
```

---

## Filter Inspection

The Sieve exposes its filter state for debug tooling and UI feedback:

```dart
search.filterKeys;   // ['status', 'hard'] — active filter names
search.hasFilter('status'); // true
search.filterCount;  // 2

// Reset everything — clears query, filters, and sort
search.reset();
```

---

## Pillar Integration

Like every basalt feature, Sieve integrates with the Pillar lifecycle through the `sieve()` extension method:

```dart
class InventoryPillar extends Pillar {
  late final itemSearch = sieve<Item>(
    items: inventory,
    textFields: [(i) => i.name, (i) => i.description],
    name: 'inventory',
  );

  @override
  void onInit() {
    itemSearch; // Touch to initialize
  }
}
```

When the Pillar disposes, all Sieve nodes are cleaned up automatically. No memory leaks, no dangling subscriptions.

---

## The Questboard, Refined

With the Sieve in place, Kael rebuilt the quest browser:

```dart
class QuestBrowserPillar extends Pillar {
  late final questSearch = sieve<Quest>(
    items: quests,
    textFields: [(q) => q.title, (q) => q.description, (q) => q.region],
    name: 'questBrowser',
  );

  void filterByRegion(String region) {
    questSearch.where('region', (q) => q.region == region);
  }

  void filterByDifficulty(int min, int max) {
    questSearch.where(
      'difficulty',
      (q) => q.difficulty >= min && q.difficulty <= max,
    );
  }

  void sortByReward() {
    questSearch.sortBy((a, b) => b.reward.compareTo(a.reward));
  }
}
```

Heroes could now type "dragon" in the search bar, slide the difficulty filter to 4+, tap "Sort by Reward," and see exactly the quests they wanted — all updating in real time, each keystroke refining the results without a single network call.

---

## Performance

The Sieve is built for speed:

| Operation | 1K items | 10K items |
|-----------|----------|-----------|
| Filter | 30 µs | 297 µs |
| Text search | 163 µs | 1,652 µs |
| Sort | 189 µs | 1,397 µs |
| Combined | — | 986 µs |
| Create | 0.35 µs | — |

Linear scaling with dataset size. Sub-millisecond for typical mobile datasets. No jank, no frame drops.

---

## What Was Learned

1. **Three concerns, one component** — Search, filter, and sort are almost always needed together. Bundling them eliminates wiring mistakes.
2. **Version-tracked reactivity** — The `_filterVersion` pattern lets imperative operations (add/remove filter) trigger reactive recomputation without wrapping every predicate in a Core.
3. **Pipeline composability** — Each stage of the pipeline (text match → predicate AND → sort) is independent. You can use text search alone, filters alone, or any combination.
4. **Pillar lifecycle management** — `registerNodes()` ensures all seven reactive nodes are disposed with the Pillar. No manual cleanup needed.

The Sieve had proven its worth. No longer would heroes scroll through chaos. The Questboard was now a precision instrument — a fine mesh that caught exactly what was sought and let everything else pass through.

---

*Next: [Chapter XLI →](chapter-41-todo.md)*
