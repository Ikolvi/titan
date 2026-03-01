# Titan Bastion

**The Bastion — where Titan's power meets the screen**

Vestige, Beacon, and auto-tracking reactive UI — powered by the Pillar architecture.

[![pub package](https://img.shields.io/pub/v/titan_bastion.svg)](https://pub.dev/packages/titan_bastion)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Ikolvi/titan/blob/main/LICENSE)

## Quick Start

```yaml
dependencies:
  titan_bastion: ^0.0.1
```

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

**Auto-**Auto-**Auto-**Au a**Auto-**Auto-**Autbuilds when**Auto-**Auto.**

## Widgets

| Widget | Description |
|--------|-------------|
| **Vestige** | Auto-tracking consumer for a Pillar |
| | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | cyc| | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | cyc| | | | | |();| | | | | ocumen| | | 


 ll documenta ll documenta ll dokolvi/titan/docs](https://github.c ll dolvi/titan/tree/main/docs)

## License

MIT — [Ikolvi](https://ikolvi.com)
