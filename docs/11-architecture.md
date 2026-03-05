# Architecture

This document explains the internal architecture of Titan for contributors and advanced users.

## Reactive Graph

Titan's core is a **dependency graph** of reactive nodes. Each node is a source (Core/TitanState), derived (Derived/TitanComputed), or observer (TitanEffect).

```
Core("count")
   │
   ├── Derived("doubled")
   │      │
   │      └── TitanEffect (Vestige rebuild)
   │
   ├── Derived("isEven")
   │      │
   │      └── TitanEffect (Vestige rebuild)
   │
   └── TitanEffect (watch — logging)
```

### Dependency Tracking

Titan uses **automatic dependency tracking** (similar to Vue 3's reactivity system):

1. A global `ReactiveScope` maintains the "current tracker"
2. When a `TitanComputed` or `TitanEffect` evaluates, it sets itself as the current tracker
3. When any `TitanState.value` is read during evaluation, it calls `track()`
4. `track()` registers the current tracker as a dependent
5. When `TitanState.value` is set, `notifyDependents()` triggers all registered dependents

```dart
// Simplified internal flow
class ReactiveScope {
  static ReactiveNode? _currentTracker;

  static void track(ReactiveNode source) {
    if (_currentTracker != null) {
      source._dependents.add(_currentTracker!);
      _currentTracker!.onTracked(source);
    }
  }
}
```

### Change Propagation

When a Core value changes:

1. All direct dependents are notified via `onDependencyChanged()`
2. `TitanComputed` marks itself dirty and recomputes on next access
3. If the computed result changed, it propagates to its own dependents
4. `TitanEffect` re-runs its function, re-tracking new dependencies
5. Listeners (from `.listen()`) are invoked with the new value

### Glitch-Free Updates

Titan ensures **glitch-free** updates through:

1. **Batching** — Multiple changes in `strike()`/`titanBatch()` fire a single notification cycle
2. **Lazy evaluation** — Computed values only recompute when accessed
3. **Change detection** — Computed values only propagate if the result actually changed

---

## Package Architecture

```
┌──────────────────────────────────────────────┐
│              titan_colossus                   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │       Monitoring Layer               │   │
│  │  Colossus (orchestrator Pillar)      │   │
│  │  Pulse (frame timing)               │   │
│  │  Stride (page load timing)          │   │
│  │  Vessel (memory monitoring)         │   │
│  │  Echo (rebuild counting)            │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │       Alerting & Reporting           │   │
│  │  Tremor (threshold alerts)          │   │
│  │  Decree (performance reports)       │   │
│  │  Mark (metric data points)          │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │       Integration                    │   │
│  │  ColossusLensTab (Lens perf tab)    │   │
│  │  ColossusAtlasObserver (nav timing) │   │
│  └──────────────────────────────────────┘   │
├──────────────────────────────────────────────┤
│              titan_atlas                      │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │         Routing Layer                │   │
│  │  Atlas (router, static API)         │   │
│  │  Passage (route definitions)        │   │
│  │  Sanctum (shell / persistent layout)│   │
│  │  RouteTrie (O(k) trie matching)     │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │         Guard & Navigation           │   │
│  │  Sentinel (route guards)            │   │
│  │  Drift (global redirects)           │   │
│  │  Waypoint (resolved route state)    │   │
│  │  Shift (page transitions)           │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │         Integration                  │   │
│  │  AtlasObserver · HeraldAtlasObserver│   │
│  │  context.atlas (BuildContext ext)   │   │
│  │  Route-scoped Pillars (auto DI)     │   │
│  └──────────────────────────────────────┘   │
├──────────────────────────────────────────────┤
│              titan_argus                      │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │       Authentication Layer           │   │
│  │  Argus (auth Pillar base class)     │   │
│  │  Garrison (Sentinel factories)      │   │
│  │  CoreRefresh (ReactiveNode bridge)  │   │
│  └──────────────────────────────────────┘   │
├──────────────────────────────────────────────┤
│              titan_bastion                    │
│                                              │
│  ┌──────────────┐  ┌──────────────────────┐ │
│  │   Primary     │  │     Extensions       │ │
│  │ Vestige<P>    │  │ context.pillar<P>()  │ │
│  │ VestigeRaw    │  │ context.hasPillar<P>()│ │
│  │ Beacon        │  └──────────────────────┘ │
│  │ BeaconScope   │  ┌──────────────────────┐ │
│  ├──────────────┤  │      Legacy           │ │
│  │   Legacy      │  │ TitanStateMixin      │ │
│  │ TitanScope    │  └──────────────────────┘ │
│  │ TitanBuilder  │                           │
│  │ TitanConsumer │                           │
│  │ TitanSelector │                           │
│  │ AsyncBuilder  │                           │
│  └──────────────┘                            │
├──────────────────────────────────────────────┤
│                    titan                     │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │           Pillar Layer               │   │
│  │  Pillar (lifecycle, managed nodes)  │   │
│  │  core() / derived() / watch()       │   │
│  │  strike() / strikeAsync()           │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │           Core Layer                 │   │
│  │  ReactiveNode → TitanState           │   │
│  │               → TitanComputed        │   │
│  │               → TitanEffect          │   │
│  │  ReactiveScope (dependency tracking) │   │
│  │  Batch (update grouping)             │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │           API Layer                  │   │
│  │  Core<T> = TitanState<T> (typedef)  │   │
│  │  Derived<T> = TitanComputed<T>      │   │
│  │  strike() / strikeAsync() (aliases) │   │
│  │  Titan (global registry)            │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │         Legacy Store Layer           │   │
│  │  TitanStore (lifecycle, effects)    │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │              DI Layer                │   │
│  │  TitanContainer (registration)      │   │
│  │  TitanModule (grouping)             │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │            Async Layer               │   │
│  │  AsyncValue<T> (sealed states)      │   │
│  │  TitanAsyncState<T> (reactive)      │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │          Observer Layer              │   │
│  │  TitanObserver (abstract)           │   │
│  │  TitanLoggingObserver               │   │
│  │  TitanHistoryObserver               │   │
│  └──────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Package | Purpose |
|-------|---------|---------|
| **Pillar** | `titan` | Structured state organization with lifecycle |
| **Core** | `titan` | Reactive primitives and dependency tracking |
| **API** | `titan` | Public type aliases and global registry |
| **Legacy Store** | `titan` | TitanStore (legacy store pattern) |
| **DI** | `titan` | Dependency injection containers and modules |
| **Async** | `titan` | Asynchronous data modeling |
| **Observer** | `titan` | Global debugging and monitoring |
| **Primary Widgets** | `titan_bastion` | Vestige, Beacon, BeaconScope |
| **Legacy Widgets** | `titan_bastion` | TitanScope, TitanBuilder, TitanConsumer, etc. |
| **Extensions** | `titan_bastion` | BuildContext methods (pillar, hasPillar) |
| **Routing** | `titan_atlas` | Atlas, Passage, Sanctum, RouteTrie |
| **Guards** | `titan_atlas` | Sentinel, Drift, per-route redirects |
| **Auth** | `titan_argus` | Argus base class, Garrison factories, CoreRefresh |
| **Monitoring** | `titan_colossus` | Pulse, Stride, Vessel, Echo, Tremor, Decree |
| **Navigation** | `titan_atlas` | Waypoint, Shift, AtlasDelegate, AtlasParser |
| **Route Observers** | `titan_atlas` | AtlasObserver, HeraldAtlasObserver |
| **Route Integration** | `titan_atlas` | context.atlas, route-scoped Pillars |
| **Monitoring** | `titan_colossus` | Colossus, Pulse, Stride, Vessel, Echo |
| **Alerting** | `titan_colossus` | Tremor (threshold alerts) |
| **Reporting** | `titan_colossus` | Decree (reports), Mark (metrics) |
| **Perf Integration** | `titan_colossus` | ColossusLensTab, ColossusAtlasObserver |

---

## Pillar Internals

```dart
abstract class Pillar {
  final List<ReactiveNode> _managedNodes = [];
  final List<TitanEffect> _managedEffects = [];
  bool _isInitialized = false;
  bool _isDisposed = false;

  TitanState<T> core<T>(T initialValue, {...}) {
    final state = TitanState<T>(initialValue, ...);
    _managedNodes.add(state);   // Track for auto-disposal
    return state;
  }

  TitanComputed<T> derived<T>(T Function() compute, {...}) {
    final computed = TitanComputed<T>(compute, ...);
    _managedNodes.add(computed);
    return computed;
  }

  TitanEffect watch(dynamic Function() fn, {...}) {
    final effect = TitanEffect(fn, ...);
    _managedEffects.add(effect);
    return effect;
  }

  void strike(void Function() fn) => titanBatch(fn);

  void dispose() {
    for (final effect in _managedEffects) effect.dispose();
    for (final node in _managedNodes) node.dispose();
    onDispose();
    _isDisposed = true;
  }
}
```

Key design decision: `core()` and `derived()` are instance methods on Pillar. In `late final` field initializers like `late final count = core(0)`, Dart correctly resolves `core` to the Pillar's instance method (not any top-level function), ensuring managed lifecycle tracking.

---

## ReactiveNode Hierarchy

```dart
abstract class ReactiveNode {
  final Set<ReactiveNode> _dependents = {};
  final List<void Function(dynamic)> _listeners = [];

  void track();                    // Register current tracker
  void notifyDependents();         // Notify all dependents
  void onDependencyChanged();      // Handle dependency notification
  void onTracked(ReactiveNode s);  // Handle being tracked
  void dispose();                  // Cleanup
}

class TitanState<T> extends ReactiveNode {
  // Mutable value with change notification
  // value getter: calls track(), returns _value
  // value setter: checks equality, updates, notifies
}

class TitanComputed<T> extends ReactiveNode {
  // Lazy computed value with caching
  // Overrides onDependencyChanged to mark dirty
  // Overrides onTracked to track dependencies
}

class TitanEffect extends ReactiveNode {
  // Side effect with auto-tracking
  // Overrides onDependencyChanged to re-run (or call onNotify)
  // Overrides onTracked to track dependencies
}
```

---

## Widget Integration Model

### Vestige

Uses `TitanEffect` internally for auto-tracking:

```
Vestige<P>
  └── TitanEffect (fireImmediately: false, onNotify: setState)
        │
        ├── _resolvePillar() — finds P from Beacon or Titan
        │
        ├── build() calls effect.run()
        │     └── builder(context, pillar) runs
        │           └── reads core.value → tracking established
        │
        └── core changes → onNotify → setState → rebuild
              └── effect.run() → re-tracks dependencies
```

### Beacon

Uses InheritedWidget for Pillar propagation:

```
Beacon (StatefulWidget)
  ├── initState: creates Pillar instances, calls initialize()
  ├── _BeaconInherited (InheritedWidget)
  │     └── Map<Type, Pillar> registry
  │           └── child widget tree
  │                 └── Vestige finds Pillar via InheritedWidget
  └── dispose: disposes all Pillar instances
```

### Resolution Order (Vestige)

```
1. BeaconScope.findPillar<P>(context)
   └── Walks up to nearest _BeaconInherited
       └── Looks up P in Map<Type, Pillar>
2. Titan.find<P>()
   └── Looks up P in global registry
3. Throw FlutterError if not found
```

---

## Titan Global Registry

```dart
abstract final class Titan {
  static final Map<Type, dynamic> _instances = {};
  static final Map<Type, dynamic Function()> _factories = {};

  static void put<T extends Pillar>(T instance) {
    _instances[T] = instance;
    if (!instance.isInitialized) instance.initialize();
  }

  static void lazy<T extends Pillar>(T Function() factory) {
    _factories[T] = factory;
  }

  static T get<T extends Pillar>() {
    // Check instances → check factories → throw
  }

  static void remove<T extends Pillar>() {
    final instance = _instances.remove(T);
    if (instance is Pillar && !instance.isDisposed) instance.dispose();
  }

  static void reset() {
    // Dispose all instances, clear factories
  }
}
```

---

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Core read | O(1) | Direct value access |
| Core write | O(d) | d = number of direct dependents |
| Derived read (cached) | O(1) | Returns cached value |
| Derived recompute | O(c) | c = computation cost |
| Effect execution | O(e) | e = effect function cost |
| Batch notification | O(n) | n = unique affected nodes |
| Titan.get (cached) | O(1) | HashMap lookup |
| Pillar.core() | O(1) | Create + add to list |
| Pillar.dispose() | O(m) | m = managed nodes + effects |

### Memory

- Each Core holds one value + a set of dependents
- Each Derived holds cached value + dependency sets
- Each Pillar holds lists of managed nodes + effects
- Titan holds one instance per registered type
- Disposed nodes release all references

### Optimizations

1. **Lazy computation** — Derived values don't evaluate until read
2. **Change detection** — Derived values only propagate when actual result differs
3. **Batching** — strike()/titanBatch() = single notification cycle
4. **Auto-tracking** — Vestige only tracks Cores actually read in builder
5. **Widget caching** — Vestige caches widget until dependencies change
6. **Nullable Conduits** — `TitanState._conduits` is `null` when no Conduits are attached, avoiding an empty `List` allocation per Core
7. **Lazy isReady** — Pillar's `isReady` Core is a getter backed by a nullable field; only allocates a `TitanState<bool>` if user code reads it
8. **Sentinel Future** — `Pillar.onInitAsync()` returns a pre-completed `Future.value()` sentinel; `_runInitAsync()` detects it via `identical()` and skips async scheduling entirely for sync-only Pillars
9. **Notification fast-path** — `ReactiveNode.notifyDependents()` returns immediately when no dependents and no listeners, skipping flag overhead
10. **Observer fast-path** — `TitanObserver.notifyStateChanged()` returns immediately when no observers are registered, avoiding argument construction
11. **Pre-allocated results** — Saga (in `titan_basalt`) pre-allocates `_stepResults` with `List.filled(steps.length, null)` instead of growing a list per step

### Optimization Impact

Measured via CI benchmarks (see [BENCHMARKS.md](BENCHMARKS.md) for live trends):

| Optimization | Target | Before | After | Change |
|--------------|--------|--------|-------|--------|
| Nullable Conduits + Lazy isReady + Sentinel Future | Pillar Lifecycle | 8.46 µs | 4.23 µs | **-50%** |
| Notification fast-path + Observer fast-path | Diamond Pattern | 0.91 µs | 0.71 µs | **-22%** |
| Pre-allocated step results | Saga (`titan_basalt`) | 3.15 µs | 2.61 µs | **-17%** |

> **Noise floor**: Sub-100ns metrics (Node Creation, Core.toggle) exhibit 5-8x variance
> across runs due to GC pauses and CPU cache effects. The benchmark tracker applies a
> configurable noise floor (default 0.100 µs) to suppress false regression flags for these.

### Benchmark Infrastructure

Titan tracks 17 metrics across every CI run:

- **Runner**: `benchmark_ci.dart` outputs JSON with calibrated measurements
- **Tracker**: `benchmark_track.dart` runs 30 metrics locally with baseline comparison
- **Reporter**: `benchmark_ci_report.dart` generates [BENCHMARKS.md](BENCHMARKS.md) with:
  - Latest run table with trend arrows (▲ regression / ▼ improvement / ≈ stable)
  - History table showing all CI runs (up to 50)
  - Mermaid `xychart-beta` line charts for visual performance trends
- **CI**: GitHub Actions caches baseline, runs benchmarks, auto-commits the report

---

## SOLID Principles

### Single Responsibility
- `Core` → holds and notifies about a single value
- `Derived` → derives a single computed value
- `TitanEffect` → manages a single side effect
- `Pillar` → organizes a single domain's state

### Open/Closed
- Extensible via `TitanObserver` without modifying Pillar code
- Custom observers for monitoring without core changes

### Liskov Substitution
- All Pillars are interchangeable via `Titan.get<T>()`
- Mock Pillars can replace real ones in tests

### Interface Segregation
- `ReactiveNode` defines minimal interface for reactive primitives
- `Pillar` exposes only `core()`/`derived()`/`strike()`/`watch()`

### Dependency Inversion
- Core package has zero Flutter dependency
- Pillars depend on abstractions
- Titan registry decouples creation from usage

---

## Contributing

### Development Setup

```bash
git clone git@github.com:Ikolvi/titan.git
cd titan
dart pub global activate melos
melos bootstrap
cd packages/titan && flutter test
cd packages/titan_bastion && flutter test
```

### Code Style

- Follow existing code style (enforced by `analysis_options.yaml`)
- All public APIs must have dartdoc comments
- Every new feature must have tests
- Use `name` parameter for debugging in reactive nodes

### Pull Request Checklist

- [ ] Tests pass (`flutter test` in all packages)
- [ ] No analysis issues (`dart analyze`)
- [ ] Public APIs documented
- [ ] CHANGELOG.md updated
- [ ] Breaking changes noted (if any)

---

[← Migration Guide](10-migration-guide.md) · [Introduction →](01-introduction.md)
