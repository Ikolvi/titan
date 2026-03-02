# Introduction to Titan

## What is Titan?

**Titan** (Total Integrated Transfer Architecture Network) is a uniquely powerful reactive state management architecture for Flutter and Dart. It combines fine-grained reactivity with structured scalability to deliver maximum performance with zero boilerplate.

## The Titan Lexicon

| Standard Term | Titan Name | Why |
|---------------|------------|-----|
| Store / Bloc | **Pillar** | Titans held up the sky; Pillars hold up your app |
| State | **Core** | The indestructible center of the Pillar |
| Computed | **Derived** | Forged from existing Cores |
| Dispatch / Add | **Strike** | Fast, decisive, powerful |
| Side Effect | **Watcher** | Vigilant sentinel, always watching |
| Consumer Widget | **Vestige** | The UI — a visible trace of the underlying power |
| Provider Widget | **Beacon** | Shines state down to all children |
| Hooks Widget | **Spark** | Lightning-fast hooks (28 hooks available) |
| Reactive Observer | **Obs** | Ultra-simple auto-tracking builder |
| Global DI | **Titan** | `Titan.put()`, `Titan.get()`, `Titan.forge()` |
| Event Bus | **Herald** | Carries messages between Pillars |
| Middleware | **Conduit** | Intercepts value changes at Core level |
| State Selector | **Prism** | Fine-grained sub-value extraction |
| Reactive Collection | **Nexus** | In-place mutable lists, maps, sets |
| Responsive Layout | **Rampart** | Tiered layout adaptation by screen width |
| Router | **Atlas** | Maps all paths, bears the world |
| Route Guard | **Sentinel** | Protects passage into guarded routes |
| Auth Base Class | **Argus** | Hundred-eyed guardian of authentication |
| Performance Monitor | **Colossus** | Giant who watches over app performance |
| Debug Overlay | **Lens** | Runtime introspection and state inspection |

## Why Titan?

| Solution | Strength | Weakness |
|----------|----------|----------|
| **Provider** | Simple, Flutter-native | Limited scalability, widget-tree coupled |
| **Bloc** | Structured, testable | Excessive boilerplate, steep learning curve |
| **Riverpod** | Compile-safe, flexible | Complex API surface, many provider types |
| **GetX** | Easy to use | Poor testability, magic, anti-patterns |

**Titan takes the best from each:**

- ✅ **Fine-grained reactivity** — only rebuild what changed (auto-tracked)
- ✅ **Minimal boilerplate** — no event classes, no state classes
- ✅ **Structured scalability** — Pillars with lifecycle, observation, DI
- ✅ **Type-safe DI** — compile-time safety, scoped + global
- ✅ **Pure Dart core** — test everything without Flutter
- ✅ **Auto-tracking rebuilds** — Vestige detects exactly which Cores are used

## Core Philosophy

### 1. Progressive Complexity

```dart
// Start simple
class CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
}

// Scale up — lifecycle, watchers, derived state
class AuthPillar extends Pillar {
  late final user = core<User?>(null);
  late final isLoggedIn = derived(() => user.value != null);

  @override
  void onInit() {
    watch(() {
      if (isLoggedIn.value) analytics.track('logged_in');
    });
  }
}
```

### 2. Fine-Grained Reactivity

```dart
// Auto-tracks: only rebuilds when count.value changes
Vestige<CounterPillar>(
  builder: (context, c) => Text('${c.count.value}'),
)
```

### 3. Pure Dart Core

```dart
test('counter works', () {
  final pillar = CounterPillar();
  pillar.increment();
  expect(pillar.count.value, 1);
  pillar.dispose();
});
```

## Architecture Overview

```
┌──────────────────────────────────────────────┐
│              titan_colossus                   │
│  Colossus · Pulse · Stride · Vessel · Echo   │
│  Tremor · Decree · Shade · Phantom · Inscribe│
├──────────────────────────────────────────────┤
│              titan_argus                      │
│  Argus · Garrison · CoreRefresh              │
├──────────────────────────────────────────────┤
│              titan_atlas                      │
│  Atlas · Passage · Sanctum · Sentinel        │
│  Waypoint · Shift · Drift · Cartograph       │
├──────────────────────────────────────────────┤
│              titan_bastion                    │
│  Vestige · Beacon · Spark · Obs · Rampart    │
│  Confluence · Lens · VestigeRaw              │
├──────────────────────────────────────────────┤
│                   titan                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │   Core   │ │  Pillar  │ │      DI      │ │
│  │ State    │ │ Lifecycle│ │ Titan.put/get│ │
│  │ Computed │ │ core()   │ │ Container    │ │
│  │ Effect   │ │ derived()│ │ Module       │ │
│  │ Batch    │ │ strike() │ │              │ │
│  └──────────┘ └──────────┘ └──────────────┘ │
│  ┌──────────┐ ┌──────────────────────────┐   │
│  │  Async   │ │        Observer          │   │
│  │ Value    │ │ Logging · History        │   │
│  │ State    │ │ Time-Travel Debugging    │   │
│  └──────────┘ └──────────────────────────┘   │
└──────────────────────────────────────────────┘
```

## Quick Example

```dart
import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

// 1. Define a Pillar
class CounterPillar extends Pillar {
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);
  void increment() => strike(() => count.value++);
}

// 2. Provide via Beacon
void main() => runApp(
  Beacon(
    pillars: [CounterPillar.new],
    child: MaterialApp(home: CounterPage()),
  ),
);

// 3. Consume via Vestige
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Vestige<CounterPillar>(
          builder: (context, c) => Text('${c.count.value}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pillar<CounterPillar>().increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## Next Steps

- [Getting Started](02-getting-started.md) — Install and set up Titan
- [Core Concepts](03-core-concepts.md) — Core, Derived, Strike, Watch
- [Pillars](04-pillars.md) — Organize state at scale
- [Flutter Integration](05-flutter-integration.md) — Vestige, Beacon, Spark, Obs, Rampart
- [Atlas Routing](12-atlas-routing.md) — Declarative navigation with Passages, Sentinels, Sanctums
- [Argus Auth](13-argus-auth.md) — Authentication & authorization with Garrison guards
- [Colossus Monitoring](14-colossus-monitoring.md) — Enterprise performance monitoring

---

**Titan** is maintained by [Ikolvi](https://ikolvi.com) and licensed under the MIT License.
