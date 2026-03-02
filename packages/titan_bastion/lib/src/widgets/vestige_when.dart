import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import 'beacon.dart';

/// A condition-builder pair for [VestigeWhen].
///
/// When [condition] returns `true`, the corresponding [builder] is used
/// to render the widget. Conditions are evaluated in order — the first
/// match wins.
///
/// ```dart
/// WhenCase(
///   condition: (counter) => counter.count.value > 100,
///   builder: (context, counter) => Text('Over 100!'),
/// )
/// ```
class WhenCase<P extends Pillar> {
  /// The condition to test. Receives the Pillar and returns `true`
  /// if this case should be built.
  ///
  /// Reactive Cores read inside [condition] are automatically tracked
  /// for rebuild.
  final bool Function(P pillar) condition;

  /// The widget builder to use when [condition] is `true`.
  final Widget Function(BuildContext context, P pillar) builder;

  /// Creates a condition-builder pair.
  const WhenCase({required this.condition, required this.builder});
}

/// **VestigeWhen** — Conditional widget rendering based on Pillar state.
///
/// `VestigeWhen` evaluates a list of [WhenCase] conditions against a
/// Pillar's state and renders the first matching case. Like [Vestige],
/// it automatically tracks reactive dependencies and rebuilds only
/// when relevant [Core] values change.
///
/// ## Why "VestigeWhen"?
///
/// A vestige rendered conditionally — showing different traces of a
/// Pillar's power depending on its state.
///
/// ## Usage
///
/// ```dart
/// VestigeWhen<CounterPillar>(
///   cases: [
///     WhenCase(
///       condition: (p) => p.count.value < 0,
///       builder: (_, p) => Text('Negative: ${p.count.value}'),
///     ),
///     WhenCase(
///       condition: (p) => p.count.value == 0,
///       builder: (_, p) => Text('Zero'),
///     ),
///     WhenCase(
///       condition: (p) => p.count.value > 100,
///       builder: (_, p) => Text('Over 100!'),
///     ),
///   ],
///   orElse: (context, p) => Text('Count: ${p.count.value}'),
/// )
/// ```
///
/// ## Resolution Order
///
/// VestigeWhen finds the Pillar in the same order as [Vestige]:
/// 1. Nearest [Beacon] in the widget tree
/// 2. Global [Titan] registry
class VestigeWhen<P extends Pillar> extends StatefulWidget {
  /// The ordered list of condition-builder pairs.
  ///
  /// Evaluated top-to-bottom; first matching condition wins.
  final List<WhenCase<P>> cases;

  /// Fallback builder when no condition matches.
  ///
  /// If null, renders [SizedBox.shrink] when no case matches.
  final Widget Function(BuildContext context, P pillar)? orElse;

  /// Creates a VestigeWhen widget.
  const VestigeWhen({super.key, required this.cases, this.orElse});

  @override
  State<VestigeWhen<P>> createState() => _VestigeWhenState<P>();
}

class _VestigeWhenState<P extends Pillar> extends State<VestigeWhen<P>> {
  P? _pillar;
  final List<TitanEffect> _effects = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePillar();
  }

  void _resolvePillar() {
    // Try Beacon first, then Titan global registry
    final beaconPillar = BeaconScope.findPillar<P>(context);
    if (beaconPillar != null) {
      _pillar = beaconPillar;
    } else {
      _pillar = Titan.find<P>();
    }
  }

  @override
  void dispose() {
    _disposeEffects();
    super.dispose();
  }

  void _disposeEffects() {
    for (final e in _effects) {
      e.dispose();
    }
    _effects.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pillar = _pillar;
    if (pillar == null) {
      return const SizedBox.shrink();
    }

    // Dispose previous tracking effects
    _disposeEffects();

    // Create a tracking effect that triggers rebuild on dependency change
    final effect = TitanEffect(
      () {
        // Evaluate all conditions to establish reactive tracking
        for (final c in widget.cases) {
          c.condition(pillar);
        }
      },
      name: 'VestigeWhen<$P>',
      onNotify: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    _effects.add(effect);

    // Evaluate conditions
    for (final c in widget.cases) {
      if (c.condition(pillar)) {
        return c.builder(context, pillar);
      }
    }

    // No match — use orElse or empty
    return widget.orElse?.call(context, pillar) ?? const SizedBox.shrink();
  }
}
