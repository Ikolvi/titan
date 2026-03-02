/// Titan Flutter — Reactive state management for Flutter.
///
/// ## The Titan Architecture
///
/// | Concept | Titan Name | Purpose |
/// |---------|------------|---------|
/// | Store / Bloc | **Pillar** | Structured state with lifecycle |
/// | State | **Core** | Reactive mutable value |
/// | Consumer | **Vestige** | Auto-tracking UI builder |
/// | Provider | **Beacon** | Scoped Pillar delivery |
/// | Dispatch | **Strike** | Batched state mutation |
///
/// ## Quick Start
///
/// ```dart
/// import 'package:titan_bastion/titan_bastion.dart';
///
/// // 1. Define a Pillar
/// class CounterPillar extends Pillar {
///   late final count = core(0);
///   late final doubled = derived(() => count.value * 2);
///   void increment() => strike(() => count.value++);
/// }
///
/// // 2. Register
/// Titan.put(CounterPillar());
///
/// // 3. Consume
/// Vestige<CounterPillar>(
///   builder: (context, counter) => Text('${counter.count.value}'),
/// )
/// ```
///
/// ## Organized App
///
/// ```dart
/// Beacon(
///   pillars: [CounterPillar.new, AuthPillar.new],
///   child: MaterialApp(
///     home: Vestige<CounterPillar>(
///       builder: (context, counter) => Scaffold(
///         body: Center(child: Text('${counter.count.value}')),
///         floatingActionButton: FloatingActionButton(
///           onPressed: counter.increment,
///           child: Icon(Icons.add),
///         ),
///       ),
///     ),
///   ),
/// )
/// ```
library;

// Re-export core titan package
export 'package:titan/titan.dart';

// Primary Widgets — The Titan Architecture
export 'src/widgets/vestige.dart';
export 'src/widgets/beacon.dart';
export 'src/widgets/confluence.dart';
export 'src/widgets/animated_vestige.dart';
export 'src/widgets/pillar_scope.dart';
export 'src/widgets/vestige_when.dart';
export 'src/widgets/rampart.dart';
export 'src/widgets/spark.dart';

// Advanced Widgets (legacy / specialized)
export 'src/widgets/obs.dart';
export 'src/widgets/titan_scope.dart';
export 'src/widgets/titan_builder.dart';
export 'src/widgets/titan_consumer.dart';
export 'src/widgets/titan_selector.dart';
export 'src/widgets/titan_async_builder.dart';

// Extensions
export 'src/extensions/context_extensions.dart';

// Mixins
export 'src/mixins/titan_state_mixin.dart';
