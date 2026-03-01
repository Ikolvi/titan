/// Titan Bastion — Flutter widgets for Titan state management.
///
/// This example demonstrates:
/// - [Pillar] — Reactive state module
/// - [Beacon] — Widget-tree DI provider
/// - [Vestige] — Auto-tracking consumer widget
library;

import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

// ---------------------------------------------------------------------------
// Pillar — Reactive state
// ---------------------------------------------------------------------------

class CounterPillar extends Pillar {
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);

  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

void main() {
  runApp(
    // Beacon provides Pillar instances to the widget tree
    Beacon(
      pillars: [CounterPillar.new],
      child: const MaterialApp(home: CounterScreen()),
    ),
  );
}

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Titan Counter')),
      // Vestige auto-tracks which Cores are read and rebuilds on change
      body: Vestige<CounterPillar>(
        builder: (context, pillar) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${pillar.count.value}',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text('Doubled: ${pillar.doubled.value}'),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'increment',
            onPressed: () => context.pillar<CounterPillar>().increment(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'decrement',
            onPressed: () => context.pillar<CounterPillar>().decrement(),
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
