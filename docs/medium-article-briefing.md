# Titan 1.0.0 — A Signal-Based Reactive Architecture for Dart & Flutter

*Total Integrated Transfer Architecture Network*

---

> *"Before the world had form, there was nothing but chaos — scattered state, tangled callbacks, widgets that rebuilt when they shouldn't have. Then a Titan raised the first Pillar, and the sky held steady."*

---

## What is Titan?

**Titan** is a high-performance, signal-based reactive state management architecture for Dart and Flutter. It replaces the boilerplate-heavy patterns of BLoC, Provider, and Riverpod with a fine-grained auto-tracking system where your UI rebuilds *only* when the exact values it reads change.

No event classes. No state mappers. No `context.watch`. Just declare state, use it, and let the engine figure out the rest.

## Installation

```yaml
dependencies:
  titan: ^1.0.0            # Core reactive engine
  titan_bastion: ^1.0.0    # Flutter widgets
  titan_atlas: ^1.0.0      # Routing & navigation (optional)
```

## Packages

| Package | pub.dev | What it does |
|---------|---------|--------------|
| [`titan`](https://pub.dev/packages/titan) | [![pub](https://img.shields.io/pub/v/titan.svg)](https://pub.dev/packages/titan) | Core Dart engine — Pillar, Core, Derived, Strike, Watch, and 15+ reactive primitives |
| [`titan_bastion`](https://pub.dev/packages/titan_bastion) | [![pub](https://img.shields.io/pub/v/titan_bastion.svg)](https://pub.dev/packages/titan_bastion) | Flutter widgets — Vestige, Beacon, Confluence, Lens, Spark (28 hooks), Obs, Rampart |
| [`titan_atlas`](https://pub.dev/packages/titan_atlas) | [![pub](https://img.shields.io/pub/v/titan_atlas.svg)](https://pub.dev/packages/titan_atlas) | Routing — Atlas, Passage, Sanctum, Sentinel, Shift, Cartograph |
| [`titan_argus`](https://pub.dev/packages/titan_argus) | [![pub](https://img.shields.io/pub/v/titan_argus.svg)](https://pub.dev/packages/titan_argus) | Auth — Argus, Garrison, CoreRefresh |
| [`titan_colossus`](https://pub.dev/packages/titan_colossus) | [![pub](https://img.shields.io/pub/v/titan_colossus.svg)](https://pub.dev/packages/titan_colossus) | Enterprise performance — Colossus, Pulse, Shade, Decree, Inscribe |

**Repository**: [github.com/Ikolvi/titan](https://github.com/Ikolvi/titan) · **License**: MIT · **Organization**: [Ikolvi](https://ikolvi.com)

---

## Quick Start (5 minutes)

### 1. Define a Pillar (your state module)

```dart
class CounterPillar extends Pillar {
  late final count = core(0);           // reactive state
  late final doubled = derived(() => count.value * 2);  // computed

  void increment() => strike(() => count.value++);
}
```

### 2. Provide it with a Beacon

```dart
Beacon(
  create: () => CounterPillar(),
  child: MyApp(),
)
```

### 3. Consume it with a Vestige

```dart
Vestige<CounterPillar>(
  builder: (context, pillar) => Text('${pillar.count.value}'),
)
```

That's it. The `Text` widget rebuilds *only* when `count` changes — not when `doubled` changes, not when unrelated state changes. Fine-grained by default.

---

## The Titan Lexicon

Titan uses mythology-inspired names. Here's the translation table:

| You already know | Titan calls it | Class |
|-----------------|---------------|-------|
| Store / Bloc | **Pillar** | `Pillar` |
| State | **Core** | `Core<T>` |
| Computed | **Derived** | `Derived<T>` |
| Dispatch | **Strike** | `strike()` |
| Side Effect | **Watcher** | `watch()` |
| Consumer Widget | **Vestige** | `Vestige<P>` |
| Provider Widget | **Beacon** | `Beacon` |
| Global DI | **Titan** | `Titan.put()` / `Titan.get()` |
| Hooks Widget | **Spark** | `Spark` |
| Event Bus | **Herald** | `Herald` |
| Router | **Atlas** | `Atlas` |
| Route | **Passage** | `Passage` |
| Route Guard | **Sentinel** | `Sentinel` |
| Shell Route | **Sanctum** | `Sanctum` |
| Undo/Redo | **Epoch** | `Epoch<T>` |
| Middleware | **Conduit** | `Conduit<T>` |
| State Selector | **Prism** | `Prism<T>` |
| Reactive Collection | **Nexus** | `NexusList<T>` / `NexusMap<K,V>` / `NexusSet<T>` |
| Debug Overlay | **Lens** | `Lens` |
| Persistence | **Relic** | `Relic` |
| Form Field | **Scroll** | `Scroll<T>` |
| Pagination | **Codex** | `Codex<T>` |
| Data Query | **Quarry** | `Quarry<T>` |

---

## Feature Highlights

### Hooks with Spark

Eliminate `StatefulWidget` boilerplate entirely:

```dart
class SearchWidget extends Spark {
  @override
  Widget ignite() {
    final query = useCore('');
    final controller = useTextController();
    final results = useDerived(() => searchItems(query.value));

    useEffect(() {
      controller.addListener(() => query.value = controller.text);
      return controller.dispose;
    }, []);

    return Column(children: [
      TextField(controller: controller),
      Text('Found: ${results.value.length}'),
    ]);
  }
}
```

13 hooks available: `useCore`, `useDerived`, `useEffect`, `useMemo`, `useRef`, `useStream`, `usePillar`, `useFuture`, `useCallback`, `useValueListenable`, `usePrevious`, `useReducer`, `useDebounced`, `useListenable`, `useAnimation`, `useIsMounted`, `useAppLifecycleState`, `useOnAppLifecycleStateChange`, `useAutomaticKeepAlive`, `useValueChanged`, `useValueNotifier`, `useStreamController`, `useTextController`, `useAnimationController`, `useFocusNode`, `useScrollController`, `useTabController`, `usePageController` — 28 hooks total.

### Reactive Collections with Nexus

Mutate lists, maps, and sets in-place — no spread operators, no copy-on-write:

```dart
class TodoPillar extends Pillar {
  late final todos = nexusList<Todo>([]);

  void add(Todo t) => todos.add(t);        // O(1), auto-notifies
  void reorder(int a, int b) => todos.swap(a, b);
}
```

### Fine-Grained Projections with Prism

Extract sub-values from complex state with memoized selectors:

```dart
late final userName = prism(userProfile, (p) => p.name);
// Rebuilds only when the name changes, ignoring avatar/email/etc.
```

### Middleware with Conduit

Intercept value changes at the Core level:

```dart
late final health = core(100, conduits: [
  ClampConduit(min: 0, max: 100),
  ValidateConduit((v) => v >= 0, 'Health cannot be negative'),
]);
```

### Full Routing with Atlas

```dart
Atlas(
  passages: [
    Passage('/', builder: (wp) => HomeScreen()),
    Passage('/quest/:id', builder: (wp) => QuestScreen(id: wp.runes['id']!)),
    Sanctum('/dashboard', builder: (wp, child) => DashboardShell(child: child),
      children: [
        Passage('/overview', builder: (wp) => OverviewTab()),
        Passage('/settings', builder: (wp) => SettingsTab()),
      ],
    ),
  ],
  sentinels: [Sentinel.only(['/dashboard'], guard: (wp) => isLoggedIn)],
)
```

---

## By the Numbers

| Metric | Value |
|--------|-------|
| Total tests | **1,474+** |
| Core (`titan`) | 811 tests |
| Flutter (`titan_bastion`) | 179 tests |
| Routing (`titan_atlas`) | 150 tests |
| Auth (`titan_argus`) | 57 tests |
| Performance (`titan_colossus`) | 277 tests |
| Benchmarks tracked | 30 performance metrics |
| Core operation latency | Sub-microsecond |
| Dart SDK | `^3.10.3` |
| Flutter | `>=3.10.0` |

---

## Learn by Story

Below is **The Chronicles of Titan** — a 28-chapter narrative tutorial where you build **Questboard** (a hero quest-tracking app) from scratch. Each chapter introduces real framework concepts through an engaging story.

| # | Chapter | You Will Learn |
|---|---------|---------------|
| I | **The First Pillar** | `Pillar`, `Core`, `Strike`, lifecycle |
| II | **Forging the Derived** | `Derived`, `Watch`, auto-tracking, testing |
| III | **The Beacon Shines** | `Beacon`, `Vestige`, Flutter integration |
| IV | **The Herald Rides** | `Herald`, cross-Pillar events, decoupling |
| V | **The Vigilant Watch** | `Vigil`, `Chronicle`, error tracking, logging |
| VI | **Turning Back the Epochs** | `Epoch`, undo/redo, `Flux`, debounce, throttle |
| VII | **The Atlas Unfurls** | `Atlas`, `Passage`, `Sentinel`, `Sanctum`, `Shift` |
| VIII | **The Relic Endures** | `Relic`, persistence, hydration |
| IX | **The Scroll Inscribes** | `Scroll`, `ScrollGroup`, form validation |
| X | **The Codex Opens** | `Codex`, pagination, infinite scrolling |
| XI | **The Quarry Yields** | `Quarry`, data fetching, SWR, retry |
| XII | **The Confluence Converges** | `Confluence2/3/4`, multi-Pillar consumers |
| XIII | **The Lens Reveals** | `Lens`, debug overlay, runtime introspection |
| XIV | **The Enterprise Arsenal** | `Aegis`, `Sigil`, guarded Watch, auto-dispose |
| XV | **The Loom Weaves** | `Loom`, finite state machines |
| XVI | **The Forge & Crucible** | `Crucible`, `Snapshot`, `Bulwark`, testing harness |
| XVII | **The Annals Record** | `Annals`, `Saga`, `Volley`, `Tether`, audit trail |
| XVIII | **The Conduit Flows** | `Conduit`, Core-level middleware |
| XIX | **The Prism Reveals** | `Prism`, fine-grained projections |
| XX | **The Nexus Connects** | `NexusList`, `NexusMap`, `NexusSet`, reactive collections |
| XXI | **The Spark Ignites** | `Spark`, hooks-style widgets, 28 hooks |
| XXII | **The Colossus Watches** | `Colossus`, `Pulse`, `Stride`, `Vessel`, `Echo` |
| XXIII | **The Inscribe Endures** | `Inscribe`, report export formats |
| XXIV | **The Shade Follows** | `Shade`, `Imprint`, gesture recording/replay |
| XXV | **The Vault Remembers** | `ShadeVault`, session persistence, auto-replay |
| XXVI | **The Colossus Turns Inward** | Dogfooding with Pillar/Core in Colossus widgets |
| XXVII | **The Sentinel Awakens** | `CoreRefresh`, reactive route re-evaluation |
| XXVIII | **The Argus Guards** | `Argus`, `guard()`, `signIn`/`signOut` contract |
| XXIX | **The Rampart Rises** | `Rampart`, responsive layouts, breakpoints |
| XXX | **The Cartograph Maps** | `Cartograph`, deep link parsing, named routes |

---

*Ready to raise your first Pillar? Let's begin.*
