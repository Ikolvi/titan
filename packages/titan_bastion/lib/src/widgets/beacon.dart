import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

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

  /// The widget subtree that can access the Pillars via [Vestige].
  final Widget child;

  /// Creates a Beacon that provides Pillars to the widget subtree.
  const Beacon({
    super.key,
    required this.pillars,
    required this.child,
  });

  @override
  State<Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<Beacon> {
  final Map<Type, Pillar> _pillars = {};

  @override
  void initState() {
    super.initState();
    _createPillars();
  }

  void _createPillars() {
    for (final factory in widget.pillars) {
      final pillar = factory();
      _pillars[pillar.runtimeType] = pillar;
      pillar.initialize();
    }
  }

  @override
  void dispose() {
    for (final pillar in _pillars.values) {
      pillar.dispose();
    }
    _pillars.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BeaconInherited(
      pillars: _pillars,
      child: widget.child,
    );
  }
}

/// Internal InheritedWidget that holds the Pillar registry.
class _BeaconInherited extends InheritedWidget {
  final Map<Type, Pillar> pillars;

  const _BeaconInherited({
    required this.pillars,
    required super.child,
  });

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
    // Walk up the tree looking for Beacons that have our type
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is _BeaconInherited) {
        final pillar = widget.pillars[P];
        if (pillar != null) {
          _result = pillar;
          return false; // Stop walking
        }
      }
      return true; // Continue walking
    });

    final result = _result as P?;
    _result = null;
    return result;
  }

  // Workaround for returning values from visitAncestorElements
  static Pillar? _result;

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
