<p align="center">
  <div style="width:100%; height:220px; overflow:hidden;">
    <img 
      src="assets/titan_banner.webp" 
      alt="Titan Banner" 
      style="width:100%; height:100%; object-fit:cover; object-position:center;"
    />
  </div>
</p>

# Titan

**Total Integrated Transfer Architecture Network**

A uniquely powerful reactive state management architecture for Flutter — structured scalability, zero boilerplate, surgical rebuilds.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%5E3.10-blue)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%5E3.38-blue)](https://flutter.dev)

---

## The Titan Lexicon

| Standard Term | Titan Name | Why |
|---------------|------------|-----|
| Store / Bloc | **Pillar** | Titans held up the sky; Pillars hold up your app |
| Dispatch / Add | **Strike** | Fast, decisive, powerful |
| State | **Core** | The indestructible center of the Pillar |
| Consumer | **Vestige** | The UI — a visible trace of the underlying power |
| Provider | **Beacon** | Shines state down to all children |
| Event Bus | **Herald** | Cross-Pillar messaging, no coupling |
| Error Tracking | **Vigil** | Centralized error capture & routing |
| Router | **Atlas** | Maps all paths, bears the world |
| Route | **Passage** | A way through to a destination |
| Shell Route | **Sanctum** | Inner chamber — persistent layout |
| Route Guard | **Sentinel** | Protects passage |
| Transition | **Shift** | Change of form/phase |
| Route State | **Waypoint** | Current position in the journey |
| Parameters | **Runes** | Ancient symbols carrying meaning |
| Redirect | **Drift** | Navigation shifts course |
| Logger | **Chronicle** | Records all that transpires |
| Undo/Redo State | **Epoch** | A distinct period in time |
| Stream Operators | **Flux** | Flow of reactive changes |
| Persistence | **Relic** | Preserved across ages |
| Form Field | **Scroll** | Reactive form field with validation, dirty tracking |
| Form Group | **ScrollGroup** | Aggregate form state across multiple Scrolls |
| Pagination | **Codex** | Paginated data with reactive state |
| Data Query | **Quarry** | Cached data fetching with stale-while-revalidate |
| Multi-Consumer | **Confluence** | Multi-Pillar consumer widget |
| Debug Overlay | **Lens** | In-app debug panel for Pillars, Herald, Vigil, Chronicle |
| Middleware | **Conduit** | Core-level pipeline — transform, validate, reject value changes |
| State Selector | **Prism** | Fine-grained, memoized state projections with structural equality |

---

## Quick Start

```bash
flutter pub add titan_bastion
```

Or see the latest version on [pub.dev](https://pub.dev/packages/titan_bastion/install).

### 1. Define a Pillar

```dart
import 'package:titan_bastion/titan_bastion.dart';

class CounterPillar extends Pillar {
  // Core — reactive mutable state (fine-grained, independent)
  late final count = core(0);

  // Derived — auto-computed from Cores, cached, lazy
  late final doubled = derived(() => count.value * 2);
  late final isEven = derived(() => count.value % 2 == 0);

  // Strike — batched, tracked mutations
  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
  void reset() => strike(() => count.value = 0);
}
```

### 2. Provide via Beacon

```dart
void main() => runApp(
  Beacon(
    pillars: [CounterPillar.new],
    child: const MyApp(),
  ),
);
```

### 3. Consume via Vestige

```dart
// Auto-tracks which Cores are read — only rebuilds when THOSE change
Vestige<CounterPillar>(
  builder: (context, counter) => Text('${counter.count.value}'),
)
```

**That's it. No event classes. No state classes. No boilerplate.**

---

## Why Titan?

| Feature | Provider | Bloc | Riverpod | GetX | **Titan** |
|---------|----------|------|----------|------|-----------|
| Fine-grained reactivity | ❌ | ❌ | ⚠️ | ⚠️ | ✅ |
| Zero boilerplate | ✅ | ❌ | ⚠️ | ✅ | ✅ |
| Auto-tracking rebuilds | ❌ | ❌ | ❌ | ❌ | ✅ |
| Structured scalability | ⚠️ | ✅ | ✅ | ❌ | ✅ |
| Lifecycle management | ❌ | ✅ | ✅ | ⚠️ | ✅ |
| Scoped + Global DI | ❌ | ⚠️ | ✅ | ❌ | ✅ |
| Cross-domain events | ❌ | ❌ | ❌ | ❌ | ✅ |
| Pure Dart core | ❌ | ✅ | ✅ | ❌ | ✅ |
| Undo/Redo built-in | ❌ | ❌ | ❌ | ❌ | ✅ |
| Persistence layer | ❌ | ⚠️ | ❌ | ❌ | ✅ |
| Structured logging | ❌ | ❌ | ❌ | ❌ | ✅ |
| Form management | ❌ | ❌ | ❌ | ❌ | ✅ Scroll + ScrollGroup |
| Pagination | ❌ | ❌ | ❌ | ❌ | ✅ Codex |
| Data fetching/caching | ❌ | ❌ | ❌ | ❌ | ✅ Quarry (SWR) |
| Multi-store consumer | ❌ | ✅ MultiBlocBuilder | ✅ Multiple watches | ❌ | ✅ Confluence |
| Debug overlay | ❌ | ❌ DevTools only | ❌ DevTools only | ❌ | ✅ Lens |
| State middleware | ❌ | ❌ | ❌ | ❌ | ✅ Conduit |

### Vs Bloc

```dart
// Bloc — 20+ lines: Event class, State class, mapEventToState, BlocProvider, BlocBuilder
class IncrementEvent extends CounterEvent {}
class CounterState { final int count; ... }
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  on<IncrementEvent>((event, emit) => emit(state.copyWith(count: state.count + 1)));
}

// Titan — 6 lines. Same scalability. No boilerplate.
class CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
}
```

### Vs Bloc Selectors

```dart
// Bloc — need BlocSelector for granular rebuilds
BlocSelector<CounterBloc, CounterState, int>(
  selector: (state) => state.count,
  builder: (context, count) => Text('$count'),
)

// Titan — auto-tracked. Only rebuilds when count.value changes. Free.
Vestige<CounterPillar>(
  builder: (context, c) => Text('${c.count.value}'),
)
```

---

## Complete Counter App

```dart
import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

class CounterPillar extends Pillar {
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);
  void increment() => strike(() => count.value++);
}

void main() => runApp(
  Beacon(
    pillars: [CounterPillar.new],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: Vestige<CounterPillar>(
            builder: (context, c) => Text(
              '${c.count.value}',
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
        floatingActionButton: Builder(builder: (context) {
          final c = context.pillar<CounterPillar>();
          return FloatingActionButton(
            onPressed: c.increment,
            child: const Icon(Icons.add),
          );
        }),
      ),
    ),
  ),
);
```

---

## Scaling Up

### Multiple Pillars

```dart
Beacon(
  pillars: [
    CounterPillar.new,
    AuthPillar.new,
    CartPillar.new,
  ],
  child: const MyApp(),
)
```

### Lifecycle Hooks

```dart
class AuthPillar extends Pillar {
  late final user = core<User?>(null);
  late final token = core<String?>(null);
  late final isLoggedIn = derived(() => user.value != null);

  @override
  void onInit() {
    // Reactive watcher — re-runs when tracked Cores change
    watch(() {
      if (isLoggedIn.value) {
        analytics.track('user_logged_in');
      }
    });
  }

  Future<void> login(String email, String password) async {
    final response = await api.login(email, password);
    strike(() {
      user.value = response.user;
      token.value = response.token;
    });
  }

  void logout() => strike(() {
    user.value = null;
    token.value = null;
  });

  @override
  void onDispose() {
    // Cleanup: close connections, cancel timers
  }
}
```

### Global DI (without Beacon)

```dart
void main() {
  Titan.put(AuthPillar());   // Auto-initialized
  Titan.put(CartPillar());
  runApp(const MyApp());
}

// Access anywhere
final auth = Titan.get<AuthPillar>();
```

### Scoped State

```dart
// Feature-level Beacon — Pillar lives only while screen is mounted
Navigator.push(context, MaterialPageRoute(
  builder: (_) => Beacon(
    pillars: [CheckoutPillar.new],
    child: CheckoutScreen(),
  ),
));
```

---

## Full API

| Concept | API | Description |
|---------|-----|-------------|
| **Pillar** | `class MyPillar extends Pillar` | Structured state module with lifecycle |
| **Core** | `late final x = core(value)` | Reactive mutable state (inside Pillar) |
| **Core** | `Core(value)` | Standalone reactive state |
| **Derived** | `late final x = derived(() => ...)` | Auto-computed value (inside Pillar) |
| **Derived** | `Derived(() => ...)` | Standalone computed value |
| **Strike** | `strike(() { ... })` | Batched state mutation |
| **Watch** | `watch(() { ... })` | Managed reactive side effect |
| **Vestige** | `Vestige<P>(builder: ...)` | Auto-tracking consumer widget |
| **Beacon** | `Beacon(pillars: [...], child: ...)` | Scoped Pillar provider |
| **Titan** | `Titan.put(p)` / `Titan.get<P>()` | Global Pillar registry |

---

## Testing — Pure Dart, No Flutter Required

```dart
test('auth pillar works', () {
  final auth = AuthPillar();
  expect(auth.isLoggedIn.value, false);

  auth.user.value = User(name: 'Alice');
  expect(auth.isLoggedIn.value, true);

  auth.dispose(); // Cleans up all managed Cores
});
```

---

## Atlas — Routing & Navigation

```bash
flutter pub add titan_atlas
```

```dart
import 'package:titan_atlas/titan_atlas.dart';

final atlas = Atlas(
  pillars: [AuthPillar.new],             // Global DI — no Beacon wrapper needed
  passages: [
    Passage('/', (_) => HomeScreen()),
    Passage('/profile/:id', (wp) => ProfileScreen(id: wp.intRune('id')!)),
    Passage('/checkout', (_) => CheckoutScreen(),
      pillars: [CheckoutPillar.new],     // Route-scoped — auto-disposed on leave
    ),
    Sanctum(
      shell: (child) => AppShell(child: child),
      passages: [
        Passage('/feed', (_) => FeedScreen()),
        Passage('/explore', (_) => ExploreScreen()),
      ],
    ),
  ],
  sentinels: [
    Sentinel((path, _) {
      final auth = Titan.get<AuthPillar>();
      return auth.isLoggedIn.value ? null : '/login';
    }),
  ],
  observers: [AtlasLoggingObserver()],
);

void main() => runApp(
  MaterialApp.router(routerConfig: atlas.config),
);

// Navigate anywhere
Atlas.to('/profile/42');
context.atlas.to('/profile/42');
Atlas.back();
```

See [Atlas Routing docs](docs/12-atlas-routing.md) for full guide.

---

## Advanced Features

Titan also includes advanced patterns for large-scale apps:

- **`AsyncValue`/`TitanAsyncState`** — Loading/error/data handling
- **`TitanObserver`** — Global state monitoring & time-travel debugging
- **`TitanContainer`** — Hierarchical DI containers

See the [full documentation](docs/) for details.

---

## Performance

Titan's reactive engine is built for speed. Benchmarks run automatically in CI on every push.

> **Run locally:** `cd packages/titan && dart run benchmark/benchmark.dart`

| Benchmark | Result | Detail |
|-----------|--------|--------|
| **Node Creation** (100K) | **0.04 µs/node** | 25M allocations/sec |
| **Notification Throughput** | **5.0M mutations/sec** | 1 listener × 10K mutations |
| **Batch Speedup** | **1.4×** | 100 states batched vs unbatched |
| **Deep Chain** (1000 deep) | **103 µs/propagation** | Full chain recompute |
| **Wide Fan-Out** (10K deps) | **1016 µs/propagation** | 1 source → 10K dependents |
| **Diamond Pattern** (1K) | **0.48 µs/diamond** | A→B, A→C, B+C→D |
| **Herald Events** (10 listeners) | **2.8M events/sec** | Cross-domain messaging |
| **Pillar Lifecycle** (10K) | **1.43 µs/pillar** | Create → init → dispose |
| **Epoch Overhead** | **~1.0× vs plain state** | Undo/redo history recording |
| **Vigil Capture** | **13M+ captures/sec** | Ring buffer error tracking |

<sup>Measured on Apple Silicon (M-series). CI results available in [GitHub Actions](../../actions) job summaries.</sup>

## Packages

| Package | Description |
|---------|-------------|
| [`titan`](packages/titan/) | Core reactive engine (pure Dart) |
| [`titan_bastion`](packages/titan_bastion/) | Flutter widgets & extensions |
| [`titan_atlas`](packages/titan_atlas/) | Routing & navigation (Atlas) |
| [`titan_example`](packages/titan_example/) | Example application |

## Documentation

| Document | Description |
|----------|-------------|
| [Introduction](docs/01-introduction.md) | What is Titan and why? |
| [Getting Started](docs/02-getting-started.md) | Installation and first app |
| [Core Concepts](docs/03-core-concepts.md) | Core, Derived, Strike, Watch |
| [Pillars](docs/04-stores.md) | Organized state management |
| [Flutter Integration](docs/05-flutter-integration.md) | Vestige, Beacon, extensions |
| [Oracle & Observation](docs/06-middleware.md) | State observation and monitoring |
| [Testing](docs/07-testing.md) | Testing guide |
| [Advanced Patterns](docs/08-advanced-patterns.md) | Forms, pagination, undo/redo |
| [API Reference](docs/09-api-reference.md) | Complete API reference |
| [Migration Guide](docs/10-migration-guide.md) | Migrate from Provider/Bloc/Riverpod/GetX |
| [Architecture](docs/11-architecture.md) | Internal design for contributors |
| [Atlas Routing](docs/12-atlas-routing.md) | Navigation with Passages, Sentinels, and Shifts |
| **[The Chronicles of Titan](docs/story/README.md)** | **Story-driven tutorial — learn by building Questboard** |

## Development

```bash
dart pub global activate fvm && dart pub global activate melos
fvm install && melos bootstrap
cd packages/titan && fvm flutter test
cd packages/titan_bastion && fvm flutter test
```

## License

MIT — [Ikolvi](https://ikolvi.com)
