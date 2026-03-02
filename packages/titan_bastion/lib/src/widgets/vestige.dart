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

  /// Optional condition to control when the widget rebuilds.
  ///
  /// When provided, the widget only rebuilds if [buildWhen] returns `true`.
  /// The callback is invoked each time a tracked dependency changes.
  /// Use this for fine-grained rebuild control beyond auto-tracking.
  ///
  /// ```dart
  /// Vestige<CounterPillar>(
  ///   buildWhen: (counter) => counter.count.peek() > 0,
  ///   builder: (context, counter) => Text('${counter.count.value}'),
  /// )
  /// ```
  final bool Function(P pillar)? buildWhen;

  /// Creates a Vestige that consumes a [Pillar] of type [P].
  const Vestige({super.key, required this.builder, this.buildWhen});

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
    final previousPillar = _pillar;

    // 1. Try Beacon (widget tree)
    final beaconPillar = BeaconScope.findPillar<P>(context);
    if (beaconPillar != null) {
      _pillar = beaconPillar;
    } else {
      // 2. Fall back to Titan (global registry)
      final globalPillar = Titan.find<P>();
      if (globalPillar != null) {
        _pillar = globalPillar;
      } else {
        throw FlutterError(
          'Vestige<$P>: No $P found.\n\n'
          'Either:\n'
          '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
          '  • Register globally: Titan.put($P())\n',
        );
      }
    }

    // Update auto-dispose reference count
    if (_pillar != previousPillar) {
      previousPillar?.unref();
      _pillar?.ref();
    }
  }

  void _onDependencyChanged() {
    if (!mounted) return;
    // Check buildWhen condition
    if (widget.buildWhen != null && _pillar != null) {
      if (!widget.buildWhen!(_pillar as P)) return;
    }
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
    _pillar?.unref();
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
  const VestigeRaw({super.key, required this.builder});

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

/// **VestigeListener** — Reacts to Pillar state changes without rebuilding.
///
/// Use for side effects like showing snackbars, navigating, or triggering
/// animations. Does **not** build UI — it fires a callback instead.
///
/// ## Usage
///
/// ```dart
/// VestigeListener<AuthPillar>(
///   listener: (context, auth) {
///     if (auth.isLoggedIn.value) {
///       Navigator.pushReplacementNamed(context, '/home');
///     }
///   },
///   child: LoginScreen(),
/// )
/// ```
///
/// ## With Condition
///
/// ```dart
/// VestigeListener<CartPillar>(
///   listenWhen: (cart) => cart.items.peek().isNotEmpty,
///   listener: (context, cart) {
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Cart updated!')),
///     );
///   },
///   child: CartScreen(),
/// )
/// ```
class VestigeListener<P extends Pillar> extends StatefulWidget {
  /// Called when tracked dependencies in the Pillar change.
  ///
  /// Use this for side effects — NOT for building UI.
  final void Function(BuildContext context, P pillar) listener;

  /// Optional condition to control when the listener fires.
  ///
  /// When provided, the listener only fires if [listenWhen] returns `true`.
  final bool Function(P pillar)? listenWhen;

  /// The child widget to render. Not affected by state changes.
  final Widget child;

  /// Creates a VestigeListener.
  const VestigeListener({
    super.key,
    required this.listener,
    required this.child,
    this.listenWhen,
  });

  @override
  State<VestigeListener<P>> createState() => _VestigeListenerState<P>();
}

class _VestigeListenerState<P extends Pillar>
    extends State<VestigeListener<P>> {
  late TitanEffect _effect;
  P? _pillar;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        // Track the same dependencies the listener would read
        widget.listener(context, _pillar as P);
      },
      onNotify: _onDependencyChanged,
      // Don't fire immediately — only on subsequent changes
      fireImmediately: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePillar();
    // Run effect once after first resolution to set up tracking
    if (_pillar != null) {
      _effect.run();
    }
  }

  void _resolvePillar() {
    final previousPillar = _pillar;

    final beaconPillar = BeaconScope.findPillar<P>(context);
    if (beaconPillar != null) {
      _pillar = beaconPillar;
    } else {
      final globalPillar = Titan.find<P>();
      if (globalPillar != null) {
        _pillar = globalPillar;
      } else {
        throw FlutterError(
          'VestigeListener<$P>: No $P found.\n\n'
          'Either:\n'
          '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
          '  • Register globally: Titan.put($P())\n',
        );
      }
    }

    // Update auto-dispose reference count
    if (_pillar != previousPillar) {
      previousPillar?.unref();
      _pillar?.ref();
    }
  }

  void _onDependencyChanged() {
    if (!mounted) return;
    if (widget.listenWhen != null && _pillar != null) {
      if (!widget.listenWhen!(_pillar as P)) return;
    }
    // Fire listener as side effect (post-frame to avoid build conflicts)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pillar != null) {
        widget.listener(context, _pillar as P);
      }
    });
  }

  @override
  void dispose() {
    _pillar?.unref();
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// **VestigeConsumer** — Combines building and listening in one widget.
///
/// A convenience widget that combines [Vestige] (build) and
/// [VestigeListener] (side effects) into a single widget, avoiding
/// nesting.
///
/// ## Usage
///
/// ```dart
/// VestigeConsumer<CartPillar>(
///   listener: (context, cart) {
///     if (cart.error.value != null) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text(cart.error.value!)),
///       );
///     }
///   },
///   builder: (context, cart) => CartView(items: cart.items.value),
/// )
/// ```
class VestigeConsumer<P extends Pillar> extends StatefulWidget {
  /// The builder function for UI rendering.
  final Widget Function(BuildContext context, P pillar) builder;

  /// Called when tracked dependencies change (for side effects).
  final void Function(BuildContext context, P pillar) listener;

  /// Optional condition to control when the listener fires.
  final bool Function(P pillar)? listenWhen;

  /// Optional condition to control when the widget rebuilds.
  final bool Function(P pillar)? buildWhen;

  /// Creates a VestigeConsumer.
  const VestigeConsumer({
    super.key,
    required this.builder,
    required this.listener,
    this.listenWhen,
    this.buildWhen,
  });

  @override
  State<VestigeConsumer<P>> createState() => _VestigeConsumerState<P>();
}

class _VestigeConsumerState<P extends Pillar>
    extends State<VestigeConsumer<P>> {
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
    final previousPillar = _pillar;

    final beaconPillar = BeaconScope.findPillar<P>(context);
    if (beaconPillar != null) {
      _pillar = beaconPillar;
    } else {
      final globalPillar = Titan.find<P>();
      if (globalPillar != null) {
        _pillar = globalPillar;
      } else {
        throw FlutterError(
          'VestigeConsumer<$P>: No $P found.\n\n'
          'Either:\n'
          '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
          '  • Register globally: Titan.put($P())\n',
        );
      }
    }

    // Update auto-dispose reference count
    if (_pillar != previousPillar) {
      previousPillar?.unref();
      _pillar?.ref();
    }
  }

  void _onDependencyChanged() {
    if (!mounted) return;

    // Fire listener (always, unless listenWhen prevents it)
    if (widget.listenWhen == null ||
        (_pillar != null && widget.listenWhen!(_pillar as P))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pillar != null) {
          widget.listener(context, _pillar as P);
        }
      });
    }

    // Rebuild UI (unless buildWhen prevents it)
    if (widget.buildWhen != null && _pillar != null) {
      if (!widget.buildWhen!(_pillar as P)) return;
    }

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
    _pillar?.unref();
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

// ---------------------------------------------------------------------------
// VestigeSelector — sub-value selection from a Pillar
// ---------------------------------------------------------------------------

/// **VestigeSelector** — Select a sub-value from a [Pillar] for fine-grained rebuilds.
///
/// Combines Pillar resolution (like [Vestige]) with explicit sub-value
/// selection and custom equality. Only rebuilds when the selected value
/// changes — not when other Pillar state changes.
///
/// This is Titan's equivalent of BLoC's `BlocSelector`.
///
/// ## Usage
///
/// ```dart
/// VestigeSelector<CartPillar, int>(
///   selector: (cart) => cart.items.value.length,
///   builder: (context, count) => Text('Items: $count'),
/// )
/// ```
///
/// ## Custom Equality
///
/// ```dart
/// VestigeSelector<SearchPillar, List<String>>(
///   selector: (search) => search.results.value,
///   equals: (a, b) => listEquals(a, b),
///   builder: (context, results) => ResultList(results: results),
/// )
/// ```
class VestigeSelector<P extends Pillar, T> extends StatefulWidget {
  /// Extracts the sub-value from the Pillar.
  final T Function(P pillar) selector;

  /// Builds the widget with the selected value.
  final Widget Function(BuildContext context, T value) builder;

  /// Optional custom equality for change detection.
  ///
  /// By default, uses `==`. Use for collections or custom objects
  /// where identity-based equality is insufficient.
  final bool Function(T previous, T next)? equals;

  /// Creates a VestigeSelector.
  const VestigeSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.equals,
  });

  @override
  State<VestigeSelector<P, T>> createState() => _VestigeSelectorState<P, T>();
}

class _VestigeSelectorState<P extends Pillar, T>
    extends State<VestigeSelector<P, T>> {
  late TitanEffect _effect;
  P? _pillar;
  late T _selectedValue;
  Widget? _cachedWidget;
  bool _isFirst = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        final newValue = widget.selector(_pillar as P);
        if (_isFirst || !_isEqual(_selectedValue, newValue)) {
          _selectedValue = newValue;
          _isFirst = false;
          _cachedWidget = widget.builder(context, _selectedValue);
        }
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
    final previousPillar = _pillar;

    final beaconPillar = BeaconScope.findPillar<P>(context);
    if (beaconPillar != null) {
      _pillar = beaconPillar;
    } else {
      final globalPillar = Titan.find<P>();
      if (globalPillar != null) {
        _pillar = globalPillar;
      } else {
        throw FlutterError(
          'VestigeSelector<$P, $T>: No $P found.\n\n'
          'Either:\n'
          '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
          '  • Register globally: Titan.put($P())\n',
        );
      }
    }

    // Update auto-dispose reference count
    if (_pillar != previousPillar) {
      previousPillar?.unref();
      _pillar?.ref();
    }
  }

  void _onDependencyChanged() {
    if (!mounted || _pillar == null) return;

    // Re-run selector to check if selected value actually changed
    final newValue = widget.selector(_pillar as P);
    if (!_isEqual(_selectedValue, newValue)) {
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _cachedWidget = null);
          }
        });
      } else {
        setState(() => _cachedWidget = null);
      }
    }
  }

  bool _isEqual(T a, T b) {
    if (widget.equals != null) return widget.equals!(a, b);
    return a == b;
  }

  @override
  void dispose() {
    _pillar?.unref();
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedWidget == null) {
      _effect.run();
    }
    return _cachedWidget ?? const SizedBox.shrink();
  }
}
