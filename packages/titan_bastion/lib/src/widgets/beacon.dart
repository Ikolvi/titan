import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import 'titan_plugin.dart';

/// **Beacon** — Shines Pillar state down to all children.
///
/// `Beacon` is the scoped provider widget that creates [Pillar]
/// instances and makes them available to the widget subtree via
/// [Vestige] widgets.
///
/// ## Why "Beacon"?
///
/// A beacon shines light downward. Beacon shines your Pillar state
/// down to all descendant widgets.
///
/// ## Basic Usage
///
/// ```dart
/// Beacon(
///   pillars: [
///     CounterPillar.new,
///     AuthPillar.new,
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// ## With Constructor Arguments
///
/// ```dart
/// Beacon(
///   pillars: [
///     () => AuthPillar(api: ApiService()),
///     () => CartPillar(userId: currentUser.id),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// ## Scoped State
///
/// Beacons create and own their Pillars. When a Beacon is removed
/// from the tree, all its Pillars are automatically disposed.
///
/// ```dart
/// // Feature-level Beacon — Pillar lives only while this screen is mounted
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => Beacon(
///     pillars: [CheckoutPillar.new],
///     child: CheckoutScreen(),
///   ),
/// ));
/// ```
///
/// ## Nested Beacons
///
/// Beacons can be nested. Child Beacons inherit parent Pillar access:
///
/// ```dart
/// Beacon(
///   pillars: [AuthPillar.new],
///   child: Beacon(
///     pillars: [DashboardPillar.new],
///     child: DashboardScreen(), // Can access both AuthPillar & DashboardPillar
///   ),
/// )
/// ```
///
/// ## Vs BlocProvider
///
/// ```dart
/// // Bloc — verbose, one provider per bloc
/// MultiBlocProvider(
///   providers: [
///     BlocProvider(create: (_) => CounterBloc()),
///     BlocProvider(create: (_) => AuthBloc()),
///   ],
///   child: MyApp(),
/// )
///
/// // Titan — one Beacon, all Pillars
/// Beacon(
///   pillars: [CounterPillar.new, AuthPillar.new],
///   child: MyApp(),
/// )
/// ```
class Beacon extends StatefulWidget {
  /// Factory functions that create [Pillar] instances.
  ///
  /// Each factory is called once when the Beacon mounts. Pillars are
  /// automatically initialized and disposed with the Beacon.
  ///
  /// ```dart
  /// Beacon(
  ///   pillars: [
  ///     CounterPillar.new,           // No-arg constructor tear-off
  ///     () => AuthPillar(api: api),  // With arguments
  ///   ],
  ///   child: child,
  /// )
  /// ```
  final List<Pillar Function()> pillars;

  /// Pre-existing Pillar instances to provide.
  ///
  /// Unlike [pillars], these are NOT created by the Beacon and are
  /// NOT disposed when the Beacon unmounts. Use this for externally
  /// managed Pillars (e.g., from tests, from parent navigation).
  ///
  /// ```dart
  /// Beacon.value(
  ///   values: [existingPillar],
  ///   child: child,
  /// )
  /// ```
  final List<Pillar> values;

  /// Pillar overrides for testing.
  ///
  /// Replaces Pillars of the same [runtimeType] that would normally
  /// be created by [pillars] factories. This enables dependency
  /// injection in tests without modifying production code.
  ///
  /// ```dart
  /// // In tests:
  /// Beacon(
  ///   pillars: [AuthPillar.new],
  ///   overrides: [MockAuthPillar()],
  ///   child: child,
  /// )
  /// ```
  final List<Pillar>? overrides;

  /// Plugins that augment the Beacon with additional widget wrapping.
  ///
  /// Plugins are attached during `initState` and detached during
  /// `dispose`. Each plugin's [TitanPlugin.buildOverlay] wraps the
  /// child widget tree, enabling zero-refactoring integration of
  /// cross-cutting concerns like performance monitoring.
  ///
  /// ```dart
  /// Beacon(
  ///   pillars: [CounterPillar.new],
  ///   plugins: [
  ///     if (kDebugMode) ColossusPlugin(tremors: [...]),
  ///   ],
  ///   child: MaterialApp(...),
  /// )
  /// ```
  final List<TitanPlugin>? plugins;

  /// The widget subtree that can access the Pillars via [Vestige].
  final Widget child;

  /// Creates a Beacon that provides Pillars to the widget subtree.
  const Beacon({
    super.key,
    required this.pillars,
    required this.child,
    this.overrides,
    this.plugins,
  }) : values = const [];

  /// Creates a Beacon with pre-existing Pillar instances.
  ///
  /// These Pillars are NOT created or disposed by the Beacon.
  /// They must be initialized and managed externally.
  ///
  /// ```dart
  /// final counter = CounterPillar()..initialize();
  ///
  /// Beacon.value(
  ///   values: [counter],
  ///   child: MyWidget(),
  /// )
  /// ```
  const Beacon.value({
    super.key,
    required this.values,
    required this.child,
    this.overrides,
    this.plugins,
  }) : pillars = const [];

  @override
  State<Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<Beacon> {
  final Map<Type, Pillar> _pillars = {};
  final Set<Type> _ownedTypes = {}; // Types created by us (not values)

  @override
  void initState() {
    super.initState();
    _createPillars();

    // Attach plugins after Pillars are created
    final plugins = widget.plugins;
    if (plugins != null) {
      for (final plugin in plugins) {
        plugin.onAttach();
      }
    }
  }

  void _createPillars() {
    // Build override map for fast lookup
    final overrideMap = <Type, Pillar>{};
    if (widget.overrides != null) {
      for (final override in widget.overrides!) {
        overrideMap[override.runtimeType] = override;
      }
    }

    // Create Pillars from factories (or substitute overrides)
    for (final factory in widget.pillars) {
      final pillar = factory();
      final type = pillar.runtimeType;

      if (overrideMap.containsKey(type)) {
        // Use the override instead — dispose the factory-created one
        final override = overrideMap[type]!;
        _pillars[type] = override;
        _ownedTypes.add(type);
        override.initialize();
      } else {
        _pillars[type] = pillar;
        _ownedTypes.add(type);
        pillar.initialize();
      }
    }

    // Register value Pillars (not owned by this Beacon)
    for (final pillar in widget.values) {
      _pillars[pillar.runtimeType] = pillar;
      // Don't add to _ownedTypes — we don't dispose these
    }
  }

  @override
  void dispose() {
    // Dispose owned Pillars first
    for (final entry in _pillars.entries) {
      if (_ownedTypes.contains(entry.key)) {
        entry.value.dispose();
      }
    }
    _pillars.clear();
    _ownedTypes.clear();

    // Detach plugins after Pillars are disposed (reverse order)
    final plugins = widget.plugins;
    if (plugins != null) {
      for (final plugin in plugins.reversed) {
        plugin.onDetach();
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    // Apply plugin overlays inside the InheritedWidget scope
    final plugins = widget.plugins;
    if (plugins != null) {
      for (final plugin in plugins) {
        child = plugin.buildOverlay(context, child);
      }
    }

    return _BeaconInherited(pillars: _pillars, child: child);
  }
}

/// Internal InheritedWidget that holds the Pillar registry.
class _BeaconInherited extends InheritedWidget {
  final Map<Type, Pillar> pillars;

  const _BeaconInherited({required this.pillars, required super.child});

  @override
  bool updateShouldNotify(_BeaconInherited oldWidget) {
    return pillars != oldWidget.pillars;
  }
}

/// Provides static helpers for finding Pillars in the widget tree.
///
/// Used internally by [Vestige]. You can also use [BeaconContext]
/// extensions directly.
class BeaconScope {
  BeaconScope._();

  /// Finds a [Pillar] of type [P] from the nearest [Beacon] in the tree.
  ///
  /// Returns null if no Beacon provides a Pillar of type [P].
  static P? findPillar<P extends Pillar>(BuildContext context) {
    P? found;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is _BeaconInherited) {
        final pillar = widget.pillars[P];
        if (pillar != null) {
          found = pillar as P;
          return false; // Stop walking
        }
      }
      return true; // Continue walking
    });

    return found;
  }

  /// Finds a [Pillar] of type [P] or throws.
  ///
  /// Checks both [Beacon] (widget tree) and [Titan] (global registry).
  static P of<P extends Pillar>(BuildContext context) {
    final beaconPillar = findPillar<P>(context);
    if (beaconPillar != null) return beaconPillar;

    final globalPillar = Titan.find<P>();
    if (globalPillar != null) return globalPillar;

    throw FlutterError(
      'BeaconScope.of<$P>(): No $P found.\n\n'
      'Either:\n'
      '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
      '  • Register globally: Titan.put($P())\n',
    );
  }
}

/// Extension methods on [BuildContext] for accessing Pillars.
///
/// ```dart
/// // Get a Pillar (from Beacon or Titan)
/// final counter = context.pillar<CounterPillar>();
///
/// // Check availability
/// if (context.hasPillar<AuthPillar>()) { ... }
/// ```
extension BeaconContext on BuildContext {
  /// Retrieves a [Pillar] of type [P] from the nearest [Beacon] or
  /// the global [Titan] registry.
  ///
  /// Throws [FlutterError] if not found.
  P pillar<P extends Pillar>() => BeaconScope.of<P>(this);

  /// Checks if a [Pillar] of type [P] is available.
  bool hasPillar<P extends Pillar>() {
    return BeaconScope.findPillar<P>(this) != null || Titan.has<P>();
  }
}
