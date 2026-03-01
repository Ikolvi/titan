# Introduction to Titan

## What is Titan?

**Titan** (Total Integrated Transfer Architecture Network) is a uniquely powerful reactive state management architecture for Flutter and Dart. It combines fine-grained reactivity with structured scalability to deliver maximum performance with zero boilerplate.

## The Titan Lexicon

| Standard Term | Titan Name | Why |
|---------------|------------|-----|
| Store / Bloc | **Pillar** | Titans held up the sky; Pillars hold up your app |
| Dispatch / Add | **Strike** | Fast, decisive, powerful |
| State | **Core** | The indestructible center of the Pillar |
| Consumer | **Vestige** | The UI — a visible trace of the underlying power |
| Provider | **Beacon** | Shines state down to all children |

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
- ✅ **Structured scalability** — Pillars with lifecycle, middleware, DI
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
│              titan_bastion                    │
│  Vestige · Beacon · BeaconScope              │
│  VestigeRaw · context.pillar<P>()            │
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
- [Pillars](04-stores.md) — Organize state at scale
- [Flutter Integration](05-flutter-integration.md) — Vestige, Beacon, extensions

---

**Titan** is maintained by [Ikolvi](https://ikolvi.com) and licensed under the MIT License.
