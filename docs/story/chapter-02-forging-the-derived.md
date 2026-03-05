# Chapter II: Forging the Derived

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"The Cores held raw power — primal, unrefined. But a Titan's true mastery lay in what could be forged from them: truths that computed themselves, values that were always correct, always in sync, never stale."*

---

## The Problem with Manual Computation

The next morning, Kael opened Questboard and realized something was missing.

The QuestboardPillar held a list of quests. But the UI needed to show *filtered* views — active quests, completed quests, total glory earned. Kael's first instinct was to compute these manually:

```dart
// ❌ Don't do this — fragile, manual, error-prone
int getActiveCount() => quests.value.where((q) => !q.isCompleted).length;
int getGlory() => quests.value.where((q) => q.isCompleted).fold(0, (s, q) => s + q.glory);
```

This would work... once. But every time the UI called `getActiveCount()`, it would recompute from scratch. And worse — the UI wouldn't know *when* to recompute. It would have to rebuild the entire widget tree on every change, or Kael would have to manually track which computations depended on which state.

There had to be a better way. And there was.

---

## The Derived — Forged from Cores

A **Derived** is a reactive computed value. You write the computation once, and Titan auto-tracks which Cores are read inside it. When those Cores change, the Derived recomputes. When they don't, it serves a cached result.

Zero manual dependency tracking. Zero stale data.

```dart
class QuestboardPillar extends Pillar {
  late final quests = core(<Quest>[]);
  late final selectedQuestId = core<String?>(null);

  // Derived — automatically tracks `quests` and recomputes when it changes
  late final activeQuests = derived(
    () => quests.value.where((q) => !q.isCompleted).toList(),
  );

  late final completedQuests = derived(
    () => quests.value.where((q) => q.isCompleted).toList(),
  );

  late final totalGlory = derived(
    () => completedQuests.value.fold(0, (sum, q) => sum + q.glory),
  );

  late final activeCount = derived(() => activeQuests.value.length);
  late final completedCount = derived(() => completedQuests.value.length);

  late final selectedQuest = derived(
    () => quests.value.where((q) => q.id == selectedQuestId.value).firstOrNull,
  );

  void addQuest(Quest quest) => strike(() {
    quests.value = [...quests.value, quest];
  });

  void completeQuest(String id) => strike(() {
    quests.value = quests.value.map((q) {
      return q.id == id ? q.copyWith(isCompleted: true) : q;
    }).toList();
  });

  void selectQuest(String? id) => strike(() {
    selectedQuestId.value = id;
  });
}
```

Look at `totalGlory`. It reads from `completedQuests`, which itself reads from `quests`. Titan tracks this entire dependency chain automatically. Change `quests`, and everything downstream recalculates — but *only* what's affected.

```dart
final board = QuestboardPillar();
board.initialize();

// Add some quests
board.addQuest(Quest(id: '1', title: 'Fix the Login Bug', description: '...', glory: 30));
board.addQuest(Quest(id: '2', title: 'Write Unit Tests', description: '...', glory: 50));
board.addQuest(Quest(id: '3', title: 'Deploy to Production', description: '...', glory: 100));

print(board.activeCount.value);     // 3
print(board.completedCount.value);  // 0
print(board.totalGlory.value);      // 0

// Complete a quest
board.completeQuest('1');

print(board.activeCount.value);     // 2
print(board.completedCount.value);  // 1
print(board.totalGlory.value);      // 30   — auto-computed!

// Complete another
board.completeQuest('3');

print(board.activeCount.value);     // 1
print(board.completedCount.value);  // 2
print(board.totalGlory.value);      // 130  — 30 + 100, still auto-computed
```

Kael didn't write a single line of update logic for `totalGlory`. It just... knew.

---

## The Watch — The Sentinel That Observes

Derived values are for computing state. But sometimes you need **side effects** — actions that happen *in response to* state changes. Logging. Analytics. Syncing. Showing a toast.

For this, Titan provides the **Watch** — a reactive effect that re-runs whenever its tracked dependencies change.

```dart
class QuestboardPillar extends Pillar {
  late final quests = core(<Quest>[]);
  late final totalGlory = derived(
    () => quests.value.where((q) => q.isCompleted).fold(0, (sum, q) => sum + q.glory),
  );

  @override
  void onInit() {
    // This watcher auto-tracks `totalGlory` and re-runs when it changes
    watch(() {
      final glory = totalGlory.value;
      if (glory >= 500) {
        print('🏆 LEGENDARY STATUS ACHIEVED! Glory: $glory');
      } else if (glory >= 100) {
        print('⚔️  Rising champion! Glory: $glory');
      }
    });

    // Track active quest changes
    watch(() {
      final active = quests.value.where((q) => !q.isCompleted).length;
      print('📋 Active quests: $active');
    });
  }

  void addQuest(Quest quest) => strike(() {
    quests.value = [...quests.value, quest];
  });

  void completeQuest(String id) => strike(() {
    quests.value = quests.value.map((q) {
      return q.id == id ? q.copyWith(isCompleted: true) : q;
    }).toList();
  });
}
```

Watchers run **immediately** when created (to capture initial dependencies), then re-run whenever those dependencies change. They're automatically disposed with the Pillar — no manual cleanup needed.

---

## The Hero Grows

Kael expanded the HeroPillar from Chapter I, weaving in Derived values and Watchers:

```dart
class HeroPillar extends Pillar {
  late final heroName = core('Unknown Hero');
  late final questsCompleted = core(0);
  late final questsFailed = core(0);

  // Derived: computed from other Cores
  late final totalQuests = derived(
    () => questsCompleted.value + questsFailed.value,
  );

  late final successRate = derived(() {
    final total = totalQuests.value;
    if (total == 0) return 0.0;
    return questsCompleted.value / total;
  });

  late final rank = derived(() {
    final completed = questsCompleted.value;
    if (completed >= 50) return 'Titan';
    if (completed >= 25) return 'Champion';
    if (completed >= 10) return 'Veteran';
    if (completed >= 5) return 'Journeyman';
    return 'Apprentice';
  });

  late final statusLine = derived(
    () => '${heroName.value} the ${rank.value} — '
          '${questsCompleted.value} quests completed '
          '(${(successRate.value * 100).toStringAsFixed(0)}% success rate)',
  );

  @override
  void onInit() {
    // Watch for rank changes
    watch(() {
      print('⚡ Rank updated: ${rank.value}');
    });
  }

  void complete() => strike(() => questsCompleted.value++);
  void fail() => strike(() => questsFailed.value++);
}
```

```dart
final hero = HeroPillar();
hero.initialize();                 // prints: ⚡ Rank updated: Apprentice

hero.heroName.value = 'Kael';

for (var i = 0; i < 5; i++) {
  hero.complete();                 // At #5: prints: ⚡ Rank updated: Journeyman
}

print(hero.statusLine.value);
// 'Kael the Journeyman — 5 quests completed (100% success rate)'

hero.fail();
print(hero.successRate.value.toStringAsFixed(2)); // '0.83'
print(hero.statusLine.value);
// 'Kael the Journeyman — 5 quests completed (83% success rate)'
```

Notice how `statusLine` depends on `heroName`, `rank`, `questsCompleted`, and `successRate` — and `rank` itself depends on `questsCompleted`, and `successRate` depends on both `questsCompleted` and `questsFailed`. Titan resolves this entire dependency graph automatically, ensuring every Derived is evaluated in the correct order, with no redundant computations.

---

## The First Test

Kael was a believer in testing. The beauty of Pillars was that they were **plain Dart classes** — no Flutter required, no widget testing overhead:

```dart
import 'package:test/test.dart';

void main() {
  group('HeroPillar', () {
    late HeroPillar hero;

    setUp(() {
      hero = HeroPillar();
      hero.initialize();
    });

    tearDown(() => hero.dispose());

    test('starts as Apprentice', () {
      expect(hero.rank.value, 'Apprentice');
    });

    test('promotes to Journeyman at 5 quests', () {
      for (var i = 0; i < 5; i++) {
        hero.complete();
      }
      expect(hero.rank.value, 'Journeyman');
    });

    test('computes success rate correctly', () {
      hero.complete();
      hero.complete();
      hero.fail();
      expect(hero.successRate.value, closeTo(0.667, 0.001));
    });

    test('statusLine updates reactively', () {
      hero.heroName.value = 'Kael';
      hero.complete();
      expect(hero.statusLine.value, contains('Kael'));
      expect(hero.statusLine.value, contains('1 quests completed'));
    });
  });
}
```

Pure Dart. Lightning fast. No `WidgetTester`, no `pumpWidget`, no async hell. Kael ran the tests:

```bash
dart test
```

All green. The foundation was solid.

---

## What Kael Learned

| Concept | Titan Name | What It Does |
|---------|------------|--------------|
| Mutable state | **Core** | Reactive value, fine-grained, independent |
| Computed value | **Derived** | Auto-tracks dependencies, lazy, cached |
| Batched mutation | **Strike** | Groups changes, single notification cycle |
| Side effect | **Watch** | Re-runs when tracked dependencies change |
| State container | **Pillar** | Groups Cores + Derived + logic + lifecycle |

---

> *The Derived values held true — computed, cached, always in sync. Kael had reactive state, computed values, and side effects. But all of this existed in pure Dart. To bring it to life — to paint it on screen — the hero would need a Beacon.*

---

**Next:** [Chapter III — The Beacon Shines →](chapter-03-the-beacon-shines.md)

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| **II** | **Forging the Derived** ← You are here |
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
