# Chapter XIX: The Prism Reveals

*In which Kael discovers how to see only what matters — slicing complex state into focused projections that rebuild only when their narrow view of the world actually changes.*

---

Questboard had grown. A single `HeroPillar` now held everything about a hero — name, level, health, mana, equipment, quest log, achievement list, friend roster. The state was richly structured, like a crystal containing a thousand facets.

The problem was that every widget looking at that crystal saw *all* of it.

"Why does the health bar rebuild when the hero's name changes?" The junior developer's question was deceptively simple. Kael pulled up the `Vestige` — it was watching the entire `HeroPillar`, and any Core mutation triggered a rebuild of every connected widget.

He'd used `VestigeSelector` in some places, and `Derived` in others. But `VestigeSelector` was a Flutter widget — no good for pure Dart logic. And `Derived` auto-tracked everything it touched, making it hard to guarantee *exactly* which source it depended on.

What he needed was something more precise. A way to look at a complex Core and see only one facet. A lens that split white light into its component colors.

He needed a **Prism**.

---

## The Prism — Fine-Grained State Projection

> *A prism doesn't create light — it reveals what was always there. Titan's Prism doesn't create state — it projects a focused, memoized view of existing state, notifying dependents only when that specific view changes.*

While `Derived` auto-tracks any reactive value read during computation, a **Prism** provides explicit, type-safe projections from one or more source Cores:

```dart
class HeroPillar extends Pillar {
  late final hero = core(Hero(
    name: 'Kael',
    level: 10,
    health: 100,
    mana: 50,
    equipment: ['Sword of Dawn', 'Iron Shield'],
  ));

  // Each Prism watches the same Core, but only notifies
  // when its specific projection changes
  late final heroName   = prism(hero, (h) => h.name);
  late final heroLevel  = prism(hero, (h) => h.level);
  late final heroHealth = prism(hero, (h) => h.health);
  late final heroMana   = prism(hero, (h) => h.mana);
}
```

When `hero.value` changes to update health from `100` to `85`:
- `heroHealth` recomputes → value changed → notifies dependents
- `heroName` recomputes → value unchanged → **silent**
- `heroLevel` recomputes → value unchanged → **silent**
- `heroMana` recomputes → value unchanged → **silent**

"Four widgets watching four Prisms," Kael explained. "Three of them do nothing. Only the health bar rebuilds."

---

## Type-Safe Multi-Source Combining

The real power emerged when Kael needed to combine values from *multiple* Cores:

```dart
class QuestDashboardPillar extends Pillar {
  late final heroName = core('Kael');
  late final heroLevel = core(10);
  late final questCount = core(3);

  // Combine two sources — fully typed
  late final heroTitle = Prism.combine2(
    heroName, heroLevel,
    (name, level) => '$name the ${_rankFor(level)}',
  );

  // Combine three sources
  late final dashboardSummary = Prism.combine3(
    heroName, heroLevel, questCount,
    (name, level, quests) => '$name (Lv$level) — $quests active quests',
  );

  String _rankFor(int level) =>
    level >= 20 ? 'Legendary' :
    level >= 10 ? 'Veteran' :
    'Novice';
}
```

Each `combine` variant preserves full generic type information — no `dynamic` casts, no runtime surprises:

| Factory | Sources | Signature |
|---------|---------|-----------|
| `Prism.of` | 1 | `Prism.of<S, R>(source, selector)` |
| `Prism.combine2` | 2 | `Prism.combine2<A, B, R>(s1, s2, combiner)` |
| `Prism.combine3` | 3 | `Prism.combine3<A, B, C, R>(s1, s2, s3, combiner)` |
| `Prism.combine4` | 4 | `Prism.combine4<A, B, C, D, R>(s1, s2, s3, s4, combiner)` |

---

## Structural Equality — PrismEquals

A subtle bug taught Kael an important lesson. His hero had a list of achievements:

```dart
late final hero = core(Hero(
  achievements: ['First Blood', 'Dragon Slayer'],
  // ...
));

// This Prism projects the achievements list
late final achievements = prism(
  hero,
  (h) => h.achievements.toList(),
);
```

Every time the hero state updated — even when achievements didn't change — the Prism produced a *new* `List` instance. Different identity, same contents. The widget rebuilt every time.

The fix was `PrismEquals`:

```dart
late final achievements = prism(
  hero,
  (h) => h.achievements.toList(),
  equals: PrismEquals.list,
);
```

Now the Prism compared lists element-by-element instead of by identity. Same elements? No notification. Problem solved.

Titan ships three structural comparators:

| Comparator | Type | Compares |
|------------|------|----------|
| `PrismEquals.list<T>` | `List<T>` | Length + elements at each index |
| `PrismEquals.set<T>` | `Set<T>` | Length + `containsAll` |
| `PrismEquals.map<K,V>` | `Map<K,V>` | Length + keys + values |

---

## Composing Prisms

Prisms compose. A Prism can project from a `Derived` value, and Prisms can chain:

```dart
class InventoryPillar extends Pillar {
  late final items = core(<Item>[
    Item('Sword of Dawn', type: ItemType.weapon, power: 45),
    Item('Iron Shield', type: ItemType.armor, power: 30),
    Item('Health Potion', type: ItemType.consumable, power: 0),
  ]);

  // Derived computes all weapons
  late final weapons = derived(
    () => items.value.where((i) => i.type == ItemType.weapon).toList(),
  );

  // Prism projects from the Derived
  late final bestWeaponName = Prism.fromDerived(
    weapons,
    (weaponList) => weaponList.isEmpty
      ? 'None'
      : weaponList.reduce((a, b) => a.power > b.power ? a : b).name,
  );
}
```

Or chain Prisms directly:

```dart
// Source → Prism → Prism
final user = Core({'name': 'Kael', 'role': 'hero'});
final name = user.prism((u) => u['name'] as String);
final initial = Prism.fromDerived(name, (n) => n[0]); // 'K'
```

---

## The Extension — .prism()

For quick, ergonomic projections, every `Core` gains a `.prism()` method:

```dart
final user = Core(User(name: 'Kael', level: 10));

// Extension method — no static factory needed
final userName = user.prism((u) => u.name);
final isHighLevel = user.prism((u) => u.level > 15);
```

This is equivalent to `Prism.of(user, selector)` but reads more naturally as a method chain.

---

## Prism in Action — Questboard

Kael applied Prisms to the quest detail screen. Previously, the entire screen rebuilt whenever *any* quest field changed — title, description, reward, status, assignee. Now each section had its own Prism:

```dart
class QuestDetailPillar extends Pillar {
  late final quest = core(Quest(
    title: 'Defeat the Shadow Dragon',
    description: 'Venture into the Abyss...',
    reward: 500,
    status: QuestStatus.active,
    assignee: 'Kael',
  ));

  // Each widget watches exactly one projection
  late final questTitle    = prism(quest, (q) => q.title);
  late final questReward   = prism(quest, (q) => q.reward);
  late final questStatus   = prism(quest, (q) => q.status);
  late final questAssignee = prism(quest, (q) => q.assignee);

  // Combined projection for the header
  late final headerSummary = Prism.combine2(
    quest, core(DateTime.now()),
    (q, _) => '${q.title} — ${q.status.name}',
  );
}
```

The Vestige for the reward badge now only rebuilds when the reward changes. The status chip only rebuilds when the status changes. The title bar only rebuilds when the title changes. Everything else stays perfectly still.

"It's like each widget has blinders on," the PM observed. "It only sees the one thing it cares about."

"Exactly," Kael said. "And because Prism extends `TitanComputed`, it works seamlessly with Vestige, Derived, Watch — the entire reactive graph."

---

## Prism vs. Derived vs. VestigeSelector

The junior developer wanted clarity on when to use which:

| Use Case | Tool | Why |
|----------|------|-----|
| Compute from multiple reactive values | **Derived** | Auto-tracks all reads, lazy evaluation |
| Project a sub-value from a single Core | **Prism** | Explicit source, memoized, skip unchanged |
| Combine specific Cores with type safety | **Prism.combine** | No auto-tracking surprises |
| Widget-level selective rebuild | **VestigeSelector** | Flutter-only, no reusable logic |
| Collection projection with equality | **Prism + PrismEquals** | Structural comparison built in |

"Derived is for *computing new values* from the reactive graph," Kael summarized. "Prism is for *focusing on specific facets* of existing state. They're complementary."

---

The PM looked at the performance dashboard. Widget rebuilds had dropped by sixty percent after the Prism refactor. "And this is just projections?"

Kael nodded. "Fine-grained projections with memoization. The cheapest rebuild is the one that never happens."

The junior developer was already refactoring the hero profile screen, splitting the monolithic state observer into a constellation of precise Prisms. Each widget would see exactly what it needed — no more, no less.

"It's strange," she said, not looking up from the code. "The more you slice state apart, the simpler everything becomes."

Kael smiled. That was the Prism's lesson: complexity didn't come from having too much state. It came from seeing too much of it at once.

---

*The Prism teaches a fundamental truth: the best way to handle complex state isn't to simplify the state — it's to simplify how you look at it. Focus on the facet that matters, and the rest becomes invisible.*

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
| **XIX** | **The Prism Reveals** ← You are here |
| [XX](chapter-20-the-nexus-connects.md) | The Nexus Connects |
