# Getting Started

## Prerequisites

- **Dart SDK** ^3.10.3
- **Flutter** >=3.10.0 (for `titan_bastion`)

## Installation

### Flutter Apps

```yaml
dependencies:
  titan_bastion: ^1.0.0
```

`titan_bastion` re-exports `titan` — you don't need both.

### Flutter Apps with Routing

```yaml
dependencies:
  titan_atlas: ^1.0.0
```

`titan_atlas` re-exports `titan` — add `titan_bastion` separately if you need Vestige/Beacon widgets outside of Atlas routes.

### Authentication & Authorization

```yaml
dependencies:
  titan_argus: ^1.0.0
```

`titan_argus` provides auth Pillar base class (Argus), route guards (Garrison), and reactive route re-evaluation (CoreRefresh). Re-exports `titan_atlas`.

### Performance Monitoring

```yaml
dependencies:
  titan_colossus: ^1.0.0
```

`titan_colossus` provides enterprise performance monitoring — frame tracking (Pulse), page load timing (Stride), memory monitoring (Vessel), rebuild counting (Echo), threshold alerts (Tremor), and reporting (Decree). Integrates with Lens via `ColossusLensTab` and with Atlas via `ColossusAtlasObserver`.

### Pure Dart Projects

```yaml
dependencies:
  titan: ^1.0.0
```

## Your First Titan App

### Step 1: Define a Pillar

A Pillar organizes related state and logic:

```dart
import 'package:titan_bastion/titan_bastion.dart';

class CounterPillar extends Pillar {
  // Core — reactive mutable state
  late final count = core(0);

  // Derived — auto-tracks dependencies, cached
  late final doubled = derived(() => count.value * 2);
  late final isEven = derived(() => count.value % 2 == 0);

  // Strike — batched mutations
  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
  void reset() => strike(() => count.value = 0);
}
```

### Step 2: Provide via Beacon

```dart
import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

void main() {
  runApp(
    Beacon(
      pillars: [CounterPillar.new],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Titan Counter',
      home: const CounterPage(),
    );
  }
}
```

### Step 3: Consume via Vestige

```dart
class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Titan Counter')),
      body: Center(
        child: Vestige<CounterPillar>(
          builder: (context, counter) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${counter.count.value}',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Text('Double: ${counter.doubled.value}'),
              Text('Even: ${counter.isEven.value}'),
            ],
          ),
        ),
      ),
      floatingActionButton: Builder(builder: (context) {
        final counter = context.pillar<CounterPillar>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              onPressed: counter.increment,
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              onPressed: counter.decrement,
              child: const Icon(Icons.remove),
            ),
          ],
        );
      }),
    );
  }
}
```

### Step 4: Test Your Pillar

Pillars are pure Dart — test without Flutter:

```dart
import 'package:test/test.dart';

void main() {
  test('counter increments', () {
    final pillar = CounterPillar();
    expect(pillar.count.value, 0);

    pillar.increment();
    expect(pillar.count.value, 1);
    expect(pillar.doubled.value, 2);
    expect(pillar.isEven.value, false);

    pillar.dispose();
  });

  test('counter resets', () {
    final pillar = CounterPillar();
    pillar.increment();
    pillar.increment();
    pillar.reset();
    expect(pillar.count.value, 0);
    pillar.dispose();
  });
}
```

## Standalone Usage (Without Pillars)

For simple cases, use reactive primitives directly:

```dart
// Standalone Cores
final counter = Core(0);
final doubled = Derived(() => counter.value * 2);

// In any widget with VestigeRaw
VestigeRaw(
  builder: (context) => Text('${counter.value} × 2 = ${doubled.value}'),
)
```

As your app grows, migrate to Pillars for better organization.

## Project Structure Recommendations

### Small Apps

```
lib/
├── main.dart
├── pillars/
│   └── counter_pillar.dart
└── pages/
    └── counter_page.dart
```

### Medium Apps

```
lib/
├── main.dart
├── pillars/
│   ├── auth_pillar.dart
│   ├── counter_pillar.dart
│   └── settings_pillar.dart
├── models/
│   ├── user.dart
│   └── settings.dart
├── services/
│   ├── auth_service.dart
│   └── api_service.dart
└── pages/
    ├── home/
    │   ├── home_page.dart
    │   └── widgets/
    ├── auth/
    │   └── login_page.dart
    └── settings/
        └── settings_page.dart
```

### Large Apps (Feature-Based)

```
lib/
├── main.dart
├── app/
│   └── app.dart
├── core/
│   ├── services/
│   │   └── api_client.dart
│   └── models/
│       └── user.dart
└── features/
    ├── auth/
    │   ├── auth_pillar.dart
    │   ├── auth_page.dart
    │   └── widgets/
    ├── dashboard/
    │   ├── dashboard_pillar.dart
    │   ├── dashboard_page.dart
    │   └── widgets/
    └── settings/
        ├── settings_pillar.dart
        └── settings_page.dart
```

## Next Steps

- [Core Concepts](03-core-concepts.md) — Deep dive into Core, Derived, Strike
- [Pillars](04-pillars.md) — Structured state management
- [Flutter Integration](05-flutter-integration.md) — Vestige, Beacon, extensions

---

[← Introduction](01-introduction.md) · [Core Concepts →](03-core-concepts.md)
