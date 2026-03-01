import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import 'beacon.dart';

/// **Vestige** — The visible trace of a Pillar's power in the UI.
///
/// `Vestige` is the primary widget for consuming [Pillar] state.
/// It automatically finds the typed Pillar from the nearest [Beacon]
/// or the global [Titan] registry, and rebuilds **only** when the
/// specific [Core]s accessed during build actually change.
///
/// ## Why "Vestige"?
///
/// A vestige is a visible trace of something powerful. Your UI is
/// the visible trace of your Pillar's state.
///
/// ## Basic Usage
///
/// ```dart
/// Vestige<CounterPillar>(
///   builder: (context, counter) => Text('${counter.count.value}'),
/// )
/// ```
///
/// ## Auto-Tracking Magic
///
/// Vestige tracks which [Core]s and [Derived]s you read during build
/// and only rebuilds when *those specific values* change. No selectors
/// needed — you get [BlocSelector]-level granularity for free.
///
/// ```dart
/// // Only rebuilds when count changes — NOT when name changes
/// Vestige<CounterPillar>(
///   builder: (context, counter) => Text('${counter.count.value}'),
/// )
///
/// // Only rebuilds when name changes — NOT when count changes
/// Vestige<CounterPillar>(
///   builder: (context, counter) => Text(counter.name.value),
/// )
/// ```
///
/// ## Resolution Order
///
/// Vestige finds the Pillar in this order:
/// 1. Nearest [Beacon] in the widget tree
/// 2. Global [Titan] registry
///
/// ## Vs Bloc
///
/// ```dart
/// // Bloc — 4 lines, no auto-tracking
/// BlocBuilder<CounterBloc, CounterState>(
///   builder: (context, state) => Text('${state.count}'),
/// )
///
/// // Titan — 3 lines, auto-tracked, surgical rebuilds
/// Vestige<CounterPillar>(
///   builder: (context, c) => Text('${c.count.value}'),
/// )
/// ```
class Vestige<P extends Pillar> extends StatefulWidget {
  /// The builder function that receives the typed [Pillar].
  ///
  /// Only the [Core]s and [Derived]s read inside this builder are
  /// tracked. When they change, the builder re-runs.
  final Widget Function(BuildContext context, P pillar) builder;

  /// Creates a Vestige that consumes a [Pillar] of type [P].
  const Vestige({
    super.key,
    required this.builder,
  });

  @override
  State<Vestige<P>> createState() => _VestigeState<P>();
}

class _VestigeState<P extends Pillar> extends State<Vestige<P>> {
  late TitanEffect _effect;
  P? _pillar;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = widget.builder(context, _pillar as P);
      },
      onNotify: _onDependencyChanged,
      fireImmediately: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePillar();
  }

  void _resolvePillar() {
    // 1. Try Beacon (widget tree)
    final beaconPillar = BeaconScope.findPillar<P>(context);
    if (beaconPillar != null) {
      _pillar = beaconPillar;
      return;
    }

    // 2. Fall back to Titan (global registry)
    final globalPillar = Titan.find<P>();
    if (globalPillar != null) {
      _pillar = globalPillar;
      return;
    }

    throw FlutterError(
      'Vestige<$P>: No $P found.\n\n'
      'Either:\n'
      '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
      '  • Register globally: Titan.put($P())\n',
    );
  }

  void _onDependencyChanged() {
    if (!mounted) return;
    // Defer setState when Flutter is in the build/layout/paint phase
    // to avoid "setState called during build" errors (e.g. when a
    // reactive value changes synchronously inside an itemBuilder).
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _needsRebuild = true);
        }
      });
    } else {
      setState(() => _needsRebuild = true);
    }
  }

  @override
  void dispose() {
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsRebuild) {
      _needsRebuild = false;
      _effect.run();
    }
    return _cachedWidget ?? const SizedBox.shrink();
  }
}

/// **VestigeRaw** — A raw reactive builder without Pillar typing.
///
/// For quick usage with standalone [Core]s (not inside a Pillar).
/// Auto-tracks any [Core] or [Derived] accessed during build.
///
/// ```dart
/// final count = core(0);
///
/// VestigeRaw(
///   builder: (context) => Text('${count.value}'),
/// )
/// ```
///
/// For Pillar-based apps, prefer [Vestige] instead.
class VestigeRaw extends StatefulWidget {
  /// The builder function. Cores read inside are auto-tracked.
  final Widget Function(BuildContext context) builder;

  /// Creates a raw reactive builder.
  const VestigeRaw({
    super.key,
    required this.builder,
  });

  @override
  State<VestigeRaw> createState() => _VestigeRawState();
}

class _VestigeRawState extends State<VestigeRaw> {
  late TitanEffect _effect;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = widget.builder(context);
      },
      onNotify: _onDependencyChanged,
      fireImmediately: false,
    );
  }

  void _onDependencyChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _needsRebuild = true);
        }
      });
    } else {
      setState(() => _needsRebuild = true);
    }
  }

  @override
  void dispose() {
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsRebuild) {
      _needsRebuild = false;
      _effect.run();
    }
    return _cachedWidget ?? const SizedBox.shrink();
  }
}
