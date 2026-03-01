import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import 'beacon.dart';

/// **Confluence** — Where multiple Pillars converge in a single builder.
///
/// `Confluence2` combines two typed Pillars into one reactive builder.
/// Like [Vestige], it auto-tracks which [Core]s and [Derived]s are read
/// and only rebuilds when those specific values change.
///
/// ## Why "Confluence"?
///
/// A confluence is where rivers meet. Confluence is where Pillars meet
/// in a single widget.
///
/// ## Usage
///
/// ```dart
/// Confluence2<AuthPillar, CartPillar>(
///   builder: (context, auth, cart) => Text(
///     '${auth.user.value?.name}: ${cart.itemCount.value} items',
///   ),
/// )
/// ```
///
/// ## Resolution Order
///
/// Each Pillar is resolved independently using the same order as [Vestige]:
/// 1. Nearest [Beacon] in the widget tree
/// 2. Global [Titan] registry
///
/// ## Variants
///
/// - [Confluence2] — 2 Pillars
/// - [Confluence3] — 3 Pillars
/// - [Confluence4] — 4 Pillars
class Confluence2<A extends Pillar, B extends Pillar> extends StatefulWidget {
  /// The builder that receives both typed Pillars.
  final Widget Function(BuildContext context, A pillarA, B pillarB) builder;

  /// Creates a Confluence that combines two Pillars.
  const Confluence2({super.key, required this.builder});

  @override
  State<Confluence2<A, B>> createState() => _Confluence2State<A, B>();
}

class _Confluence2State<A extends Pillar, B extends Pillar>
    extends State<Confluence2<A, B>> {
  late TitanEffect _effect;
  A? _pillarA;
  B? _pillarB;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = widget.builder(context, _pillarA as A, _pillarB as B);
      },
      onNotify: _onDependencyChanged,
      fireImmediately: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pillarA = _resolve<A>();
    _pillarB = _resolve<B>();
  }

  P _resolve<P extends Pillar>() {
    final beacon = BeaconScope.findPillar<P>(context);
    if (beacon != null) return beacon;

    final global = Titan.find<P>();
    if (global != null) return global;

    throw FlutterError(
      'Confluence2<$A, $B>: No $P found.\n\n'
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

/// **Confluence3** — Where three Pillars converge in a single builder.
///
/// ```dart
/// Confluence3<AuthPillar, CartPillar, ThemePillar>(
///   builder: (context, auth, cart, theme) => Text(
///     '${auth.user.value?.name} — ${cart.itemCount.value} items',
///   ),
/// )
/// ```
///
/// See [Confluence2] for details.
class Confluence3<A extends Pillar, B extends Pillar, C extends Pillar>
    extends StatefulWidget {
  /// The builder that receives three typed Pillars.
  final Widget Function(BuildContext context, A pillarA, B pillarB, C pillarC)
  builder;

  /// Creates a Confluence that combines three Pillars.
  const Confluence3({super.key, required this.builder});

  @override
  State<Confluence3<A, B, C>> createState() => _Confluence3State<A, B, C>();
}

class _Confluence3State<A extends Pillar, B extends Pillar, C extends Pillar>
    extends State<Confluence3<A, B, C>> {
  late TitanEffect _effect;
  A? _pillarA;
  B? _pillarB;
  C? _pillarC;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = widget.builder(
          context,
          _pillarA as A,
          _pillarB as B,
          _pillarC as C,
        );
      },
      onNotify: _onDependencyChanged,
      fireImmediately: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pillarA = _resolve<A>();
    _pillarB = _resolve<B>();
    _pillarC = _resolve<C>();
  }

  P _resolve<P extends Pillar>() {
    final beacon = BeaconScope.findPillar<P>(context);
    if (beacon != null) return beacon;

    final global = Titan.find<P>();
    if (global != null) return global;

    throw FlutterError(
      'Confluence3<$A, $B, $C>: No $P found.\n\n'
      'Either:\n'
      '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
      '  • Register globally: Titan.put($P())\n',
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

/// **Confluence4** — Where four Pillars converge in a single builder.
///
/// ```dart
/// Confluence4<AuthPillar, CartPillar, ThemePillar, NavPillar>(
///   builder: (context, auth, cart, theme, nav) => ...,
/// )
/// ```
///
/// See [Confluence2] for details.
class Confluence4<
  A extends Pillar,
  B extends Pillar,
  C extends Pillar,
  D extends Pillar
>
    extends StatefulWidget {
  /// The builder that receives four typed Pillars.
  final Widget Function(
    BuildContext context,
    A pillarA,
    B pillarB,
    C pillarC,
    D pillarD,
  )
  builder;

  /// Creates a Confluence that combines four Pillars.
  const Confluence4({super.key, required this.builder});

  @override
  State<Confluence4<A, B, C, D>> createState() =>
      _Confluence4State<A, B, C, D>();
}

class _Confluence4State<
  A extends Pillar,
  B extends Pillar,
  C extends Pillar,
  D extends Pillar
>
    extends State<Confluence4<A, B, C, D>> {
  late TitanEffect _effect;
  A? _pillarA;
  B? _pillarB;
  C? _pillarC;
  D? _pillarD;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = widget.builder(
          context,
          _pillarA as A,
          _pillarB as B,
          _pillarC as C,
          _pillarD as D,
        );
      },
      onNotify: _onDependencyChanged,
      fireImmediately: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pillarA = _resolve<A>();
    _pillarB = _resolve<B>();
    _pillarC = _resolve<C>();
    _pillarD = _resolve<D>();
  }

  P _resolve<P extends Pillar>() {
    final beacon = BeaconScope.findPillar<P>(context);
    if (beacon != null) return beacon;

    final global = Titan.find<P>();
    if (global != null) return global;

    throw FlutterError(
      'Confluence4<$A, $B, $C, $D>: No $P found.\n\n'
      'Either:\n'
      '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
      '  • Register globally: Titan.put($P())\n',
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
