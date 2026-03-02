<p align="center">
  <img 
    src="https://raw.githubusercontent.com/Ikolvi/titan/main/assets/titan_banner.webp" 
    alt="Titan Banner" 
    width="100%"
  />
</p>

# Titan Bastion

**The Bastion — where Titan's power meets the screen**

Vestige, Beacon, and auto-tracking reactive UI — powered by the Pillar architecture.

[![pub package](https://img.shields.io/pub/v/titan_bastion.svg)](https://pub.dev/packages/titan_bastion)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Ikolvi/titan/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%5E3.38-blue)](https://flutter.dev)

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
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);

  void increment() => strike(() => count.value++);
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
Vestige<CounterPillar>(
  builder: (context, counter) => Text('${counter.count.value}'),
)
```

**Auto-tracking. Only rebuilds when read Cores change. No selectors needed.**

---

## Widgets

| Widget | Description |
|--------|-------------|
| **Vestige\<P\>** | Auto-tracking consumer — rebuilds only when read Cores change |
| **Beacon** | Scoped Pillar provider — creates, initializes, and auto-disposes |
| **Confluence2/3/4** | Multi-Pillar consumer widget |
| **Lens** | In-app debug panel |

### Vestige — Auto-Tracking Consumer

```dart
// Reads count.value → rebuilds only when count changes
Vestige<CounterPillar>(
  builder: (context, c) => Text('${c.count.value}'),
)

// Reads doubled.value → rebuilds only when doubled changes
Vestige<CounterPillar>(
  builder: (context, c) => Text('${c.doubled.value}'),
)
```

### Beacon — Scoped Provider

```dart
// Single Pillar
Beacon(
  pillars: [CounterPillar.new],
  child: const CounterScreen(),
)

// Multiple Pillars
Beacon(
  pillars: [
    CounterPillar.new,
    AuthPillar.new,
    CartPillar.new,
  ],
  child: const MyApp(),
)

// Feature-scoped (auto-disposes when widget unmounts)
Navigator.push(context, MaterialPageRoute(
  builder: (_) => Beacon(
    pillars: [CheckoutPillar.new],
    child: const CheckoutScreen(),
  ),
));
```

### Confluence — Multi-Pillar Consumer

```dart
Confluence2<AuthPillar, CartPillar>(
  builder: (context, auth, cart) => Text(
    '${auth.user.value?.name}: ${cart.itemCount.value} items',
  ),
)
```

Typed variants: `Confluence2`, `Confluence3`, `Confluence4`. Same auto-tracking as Vestige.

### Lens — Debug Overlay

```dart
Lens(
  enabled: kDebugMode,
  child: MaterialApp(home: MyApp()),
)
```

Shows real-time Pillar registrations, Herald events, Vigil errors, and Chronicle logs. Toggle with `Lens.show()`, `Lens.hide()`, `Lens.toggle()`.

### Context Extension

```dart
// Access Pillar from context
final counter = context.pillar<CounterPillar>();
counter.increment();
```

---

## Lifecycle

Beacon handles the full lifecycle:

1. **Creates** Pillar instances via factory functions
2. **Initializes** — calls `onInit()` for setup, watchers, subscriptions
3. **Provides** — makes Pillars available to descendants
4. **Disposes** — calls `onDispose()` and cleans up all Cores when widget unmounts

---

## Complete Example

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
            builder: (context, c) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Count: ${c.count.value}', style: const TextStyle(fontSize: 48)),
                Text('Doubled: ${c.doubled.value}'),
              ],
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

## Packages

| Package | Description |
|---------|-------------|
| [`titan`](https://pub.dev/packages/titan) | Core reactive engine — pure Dart |
| **`titan_bastion`** | Flutter widgets (this package) |
| [`titan_atlas`](https://pub.dev/packages/titan_atlas) | Routing & navigation (Atlas) |

## Documentation

| Guide | Link |
|-------|------|
| Introduction | [01-introduction.md](https://github.com/Ikolvi/titan/blob/main/docs/01-introduction.md) |
| Getting Started | [02-getting-started.md](https://github.com/Ikolvi/titan/blob/main/docs/02-getting-started.md) |
| Core Concepts | [03-core-concepts.md](https://github.com/Ikolvi/titan/blob/main/docs/03-core-concepts.md) |
| Pillars | [04-stores.md](https://github.com/Ikolvi/titan/blob/main/docs/04-stores.md) |
| Flutter Integration | [05-flutter-integration.md](https://github.com/Ikolvi/titan/blob/main/docs/05-flutter-integration.md) |
| Oracle & Observation | [06-middleware.md](https://github.com/Ikolvi/titan/blob/main/docs/06-middleware.md) |
| Testing | [07-testing.md](https://github.com/Ikolvi/titan/blob/main/docs/07-testing.md) |
| Advanced Patterns | [08-advanced-patterns.md](https://github.com/Ikolvi/titan/blob/main/docs/08-advanced-patterns.md) |
| API Reference | [09-api-reference.md](https://github.com/Ikolvi/titan/blob/main/docs/09-api-reference.md) |
| Migration Guide | [10-migration-guide.md](https://github.com/Ikolvi/titan/blob/main/docs/10-migration-guide.md) |
| Architecture | [11-architecture.md](https://github.com/Ikolvi/titan/blob/main/docs/11-architecture.md) |
| Atlas Routing | [12-atlas-routing.md](https://github.com/Ikolvi/titan/blob/main/docs/12-atlas-routing.md) |
| **Chronicles of Titan** | **[Story-driven tutorial](https://github.com/Ikolvi/titan/blob/main/docs/story/README.md)** |
| [Chapter IX: The Scroll Inscribes](../../docs/story/chapter-09-the-scroll-inscribes.md) | Form management with Scroll |
| [Chapter X: The Codex Opens](../../docs/story/chapter-10-the-codex-opens.md) | Pagination with Codex |
| [Chapter XI: The Quarry Yields](../../docs/story/chapter-11-the-quarry-yields.md) | Data fetching with Quarry |
| [Chapter XII: The Confluence Converges](../../docs/story/chapter-12-the-confluence-converges.md) | Multi-Pillar consumer |
| [Chapter XIII: The Lens Reveals](../../docs/story/chapter-13-the-lens-reveals.md) | Debug overlay |
| [Chapter XVIII: The Conduit Flows](../../docs/story/chapter-18-the-conduit-flows.md) | Core-level middleware |
| [Chapter XIX: The Prism Reveals](../../docs/story/chapter-19-the-prism-reveals.md) | Fine-grained state projections |

## License

MIT — [Ikolvi](https://ikolvi.com)
