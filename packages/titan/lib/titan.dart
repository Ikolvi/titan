/// Titan — Total Integrated Transfer Architecture Network
///
/// A uniquely powerful reactive state management architecture for Dart & Flutter.
///
/// ## The Titan Lexicon
///
/// | Concept | Titan Name | Why |
/// |---------|------------|-----|
/// | Store / Bloc | **Pillar** | Titans held up the sky; Pillars hold up your app |
/// | Dispatch / Add | **Strike** | Fast, decisive, powerful |
/// | State | **Core** | The indestructible center of the Pillar |
/// | Consumer | **Vestige** | The UI — a visible trace of underlying power |
/// | Provider | **Beacon** | Shines state down to all children |
///
/// ## Quick Start
///
/// ```dart
/// import 'package:titan_bastion/titan_bastion.dart';
///
/// class CounterPillar extends Pillar {
///   late final count = core(0);
///   late final doubled = derived(() => count.value * 2);
///   void increment() => strike(() => count.value++);
/// }
///
/// // Register globally
/// Titan.put(CounterPillar());
///
/// // Use in UI
/// Vestige<CounterPillar>(
///   builder: (context, counter) => Text('${counter.count.value}'),
/// )
/// ```
///
/// ## Primary API
///
/// - [Pillar] — Structured state module with lifecycle
/// - [Core] / [core] — Reactive mutable state
/// - [Derived] / [derived] — Reactive computed values
/// - [strike] — Batched state mutations
/// - [Titan] — Global Pillar registry & DI
/// - [Herald] — Cross-Pillar event bus
/// - [Vigil] — Centralized error tracking
///
/// ## Advanced API
///
/// - [TitanStore] — Legacy store pattern (superseded by Pillar)
/// - [TitanContainer] — Scoped dependency injection
/// - [AsyncValue] / [TitanAsyncState] — Async data handling
/// - [TitanObserver] — Global state monitoring
library;

// Primary API — Titan architecture
export 'src/api.dart';
export 'src/pillar/pillar.dart';
export 'src/events/herald.dart';
export 'src/errors/vigil.dart';
export 'src/logging/chronicle.dart';
export 'src/persistence/relic.dart';
export 'src/form/scroll.dart';
export 'src/data/codex.dart';
export 'src/data/quarry.dart';
export 'src/data/bulwark.dart';
export 'src/data/saga.dart';
export 'src/data/sigil.dart';
export 'src/data/aegis.dart';
export 'src/data/annals.dart';
export 'src/data/volley.dart';
export 'src/data/tether.dart';
export 'src/testing/snapshot.dart';

// Core reactive primitives
export 'src/core/reactive.dart';
export 'src/core/state.dart';
export 'src/core/computed.dart';
export 'src/core/conduit.dart';
export 'src/core/effect.dart';
export 'src/core/batch.dart';
export 'src/core/epoch.dart';
export 'src/core/flux.dart';
export 'src/core/extensions.dart';
export 'src/core/loom.dart';
export 'src/core/observer.dart';
export 'src/core/prism.dart';

// Store pattern (advanced / legacy)
export 'src/store/store.dart';

// Dependency injection
export 'src/di/container.dart';
export 'src/di/module.dart';

// Async support
export 'src/async/async_value.dart';
export 'src/async/async_state.dart';

// Utilities
export 'src/utils/titan_config.dart';

// Testing
export 'src/testing/crucible.dart';
