import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:titan/titan.dart';
import 'package:titan_bastion/src/widgets/beacon.dart';

// =============================================================================
// Spark — Hooks-style reactive widget that eliminates StatefulWidget boilerplate
// =============================================================================

/// A widget with hooks — eliminates [StatefulWidget] boilerplate entirely.
///
/// Spark provides React-style hooks that auto-manage lifecycle, disposal, and
/// reactive rebuilds in a single class. No `createState`, no manual `dispose`,
/// no `initState` ceremony.
///
/// ## Auto-Tracking
///
/// Spark uses the same auto-tracking engine as [Vestige]. Any [Core] or
/// [Derived] `.value` read inside [ignite] is automatically tracked. When
/// those values change, the Spark rebuilds — no manual listeners required.
///
/// ```dart
/// class HeroCard extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final hero = usePillar<HeroPillar>(context);
///     // Reading hero.name.value auto-tracks — changes rebuild this widget
///     return Text(hero.name.value);
///   }
/// }
/// ```
///
/// ## Why Spark?
///
/// **Before (StatefulWidget — 40+ lines):**
/// ```dart
/// class CounterWidget extends StatefulWidget {
///   @override
///   State<CounterWidget> createState() => _CounterWidgetState();
/// }
///
/// class _CounterWidgetState extends State<CounterWidget> {
///   late final _controller = TextEditingController();
///   int _count = 0;
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(children: [
///       TextField(controller: _controller),
///       Text('Count: $_count'),
///       ElevatedButton(
///         onPressed: () => setState(() => _count++),
///         child: Text('Increment'),
///       ),
///     ]);
///   }
/// }
/// ```
///
/// **After (Spark — 15 lines):**
/// ```dart
/// class CounterWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final count = useCore(0);
///     final controller = useTextController();
///
///     return Column(children: [
///       TextField(controller: controller),
///       Text('Count: ${count.value}'),
///       ElevatedButton(
///         onPressed: () => count.value++,
///         child: Text('Increment'),
///       ),
///     ]);
///   }
/// }
/// ```
///
/// ## Available Hooks
///
/// ### Reactive State
/// - [useCore] — Reactive mutable state, auto-tracks & rebuilds
/// - [useDerived] — Reactive computed value, auto-tracks dependencies
///
/// ### Lifecycle
/// - [useEffect] — Side effect with optional cleanup, runs on key changes
/// - [useMemo] — Memoized computation, recomputes only when keys change
/// - [useRef] — Mutable reference that does NOT trigger rebuilds
///
/// ### Flutter Controllers (auto-disposed)
/// - [useTextController] — [TextEditingController]
/// - [useAnimationController] — [AnimationController] with [TickerProvider]
/// - [useFocusNode] — [FocusNode]
/// - [useScrollController] — [ScrollController]
/// - [useTabController] — [TabController]
/// - [usePageController] — [PageController]
///
/// ### Titan Integration
/// - [usePillar] — Access a [Pillar] from the nearest [Beacon]
///
/// ## Rules
///
/// 1. **Always call hooks in the same order** — don't put hooks inside
///    conditionals or loops.
/// 2. **Only call hooks inside [ignite]** — not in callbacks or async code.
/// 3. Hooks are identified by call position, just like React hooks.
///
/// See also:
/// - [Vestige] for Pillar-scoped consumer widgets
/// - [Beacon] for providing Pillars to the widget tree
abstract class Spark extends StatefulWidget {
  /// Creates a Spark widget.
  const Spark({super.key});

  /// Build the widget using hooks.
  ///
  /// Call hooks like [useCore], [useTextController], [useEffect] etc.
  /// inside this method. Hooks auto-manage their lifecycle.
  Widget ignite(BuildContext context);

  @override
  State<Spark> createState() => SparkState();
}

/// The state for a [Spark] widget.
///
/// Provides [TickerProviderStateMixin] for animation controllers and
/// manages the hook lifecycle.
///
/// Normally you don't interact with this class directly — hooks access
/// it through [SparkState.current].
class SparkState extends State<Spark> with TickerProviderStateMixin {
  /// The currently active SparkState during [ignite].
  ///
  /// Used by hook functions to find the state they belong to.
  /// Only valid during [ignite] execution.
  static SparkState? current;

  final List<_HookState<dynamic>> _hooks = [];
  int _hookIndex = 0;
  bool _isFirstBuild = true;

  /// The auto-tracking effect that wraps [ignite] calls.
  ///
  /// Any [Core] or [Derived] `.value` read during [ignite] is automatically
  /// tracked. When those values change, the Spark rebuilds — just like
  /// [Vestige].
  late final TitanEffect _effect = TitanEffect(
    () {
      try {
        _cachedWidget = widget.ignite(context);
        _buildError = null;
      } catch (e, s) {
        _buildError = (error: e, stackTrace: s);
      }
    },
    onNotify: rebuild,
    fireImmediately: false,
  );

  Widget? _cachedWidget;
  ({Object error, StackTrace stackTrace})? _buildError;

  /// Register or retrieve a hook at the current position.
  ///
  /// On first build, [create] is called to make a new hook state.
  /// On rebuilds, the existing hook state is returned.
  // ignore: library_private_types_in_public_api
  T use<T extends _HookState<dynamic>>(T Function() create) {
    final index = _hookIndex++;

    if (_isFirstBuild) {
      final hook = create();
      hook._state = this;
      _hooks.add(hook);
      hook.init();
      return hook;
    }

    assert(
      index < _hooks.length,
      'Spark: More hooks called on rebuild than initial build. '
      'Do not call hooks inside conditionals, loops, or try/catch.',
    );

    return _hooks[index] as T;
  }

  @override
  Widget build(BuildContext context) {
    current = this;
    _hookIndex = 0;
    _effect.run();
    _isFirstBuild = false;
    current = null;

    // TitanEffect catches errors internally — rethrow so Flutter sees them.
    if (_buildError case final err?) {
      Error.throwWithStackTrace(err.error, err.stackTrace);
    }

    return _cachedWidget ?? const SizedBox.shrink();
  }

  @override
  void dispose() {
    _effect.dispose();
    // Dispose hooks in reverse order (most recently created first)
    for (var i = _hooks.length - 1; i >= 0; i--) {
      _hooks[i].dispose();
    }
    _hooks.clear();
    super.dispose();
  }

  /// Trigger a rebuild of this Spark widget.
  ///
  /// Called automatically when any tracked [Core] or [Derived] value changes.
  /// Also called by hooks (e.g., [useCore]) when their managed state mutates.
  void rebuild() {
    if (mounted) {
      // Defer setState if we're in persistent callbacks phase
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    }
  }
}

// =============================================================================
// Hook State Base Classes
// =============================================================================

/// Base class for all hook states.
///
/// Each hook call in [Spark.ignite] creates one [_HookState] instance on
/// the first build. That instance persists across rebuilds until the
/// Spark widget is disposed.
abstract class _HookState<T> {
  late SparkState _state;

  /// Called once after the hook is created.
  void init() {}

  /// Called when the Spark widget is disposed.
  void dispose() {}
}

// =============================================================================
// useCore — Reactive mutable state
// =============================================================================

/// Creates a reactive [Core] that auto-disposes with the [Spark] widget.
///
/// When the Core's value changes, the Spark widget automatically rebuilds.
///
/// ```dart
/// class CounterWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final count = useCore(0);
///     return Text('${count.value}');
///   }
/// }
/// ```
///
/// The [name] parameter is optional and used for debugging.
Core<T> useCore<T>(T initial, {String? name}) {
  final state = SparkState.current!;
  return state.use(() => _CoreHookState<T>(initial, name: name)).core;
}

class _CoreHookState<T> extends _HookState<T> {
  _CoreHookState(this._initial, {this.name});

  final T _initial;
  final String? name;
  late final Core<T> core;
  void Function()? _listener;

  @override
  void init() {
    core = TitanState<T>(_initial, name: name);
    _listener = () => _state.rebuild();
    core.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) {
      core.removeListener(_listener!);
    }
    core.dispose();
  }
}

// =============================================================================
// useDerived — Reactive computed value
// =============================================================================

/// Creates a reactive [Derived] that auto-tracks dependencies and
/// auto-disposes with the [Spark] widget.
///
/// When any tracked value changes, the derived value recomputes and the
/// Spark widget rebuilds.
///
/// ```dart
/// class SummaryWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final firstName = useCore('Kael');
///     final lastName = useCore('Stormborn');
///     final fullName = useDerived(() => '${firstName.value} ${lastName.value}');
///
///     return Text(fullName.value);
///   }
/// }
/// ```
Derived<T> useDerived<T>(T Function() compute, {String? name}) {
  final state = SparkState.current!;
  return state.use(() => _DerivedHookState<T>(compute, name: name)).derived;
}

class _DerivedHookState<T> extends _HookState<T> {
  _DerivedHookState(this._compute, {this.name});

  final T Function() _compute;
  final String? name;
  late final Derived<T> derived;
  void Function()? _listener;

  @override
  void init() {
    derived = TitanComputed<T>(_compute, name: name);
    _listener = () => _state.rebuild();
    derived.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) {
      derived.removeListener(_listener!);
    }
    derived.dispose();
  }
}

// =============================================================================
// useEffect — Side effects with cleanup
// =============================================================================

/// Runs a side effect that can optionally return a cleanup function.
///
/// - If [keys] is `null`, the effect runs on **every build**.
/// - If [keys] is `[]` (empty), the effect runs **once** (like `initState`).
/// - If [keys] contains values, the effect re-runs when any key changes.
///
/// ```dart
/// class TimerWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final seconds = useCore(0);
///
///     useEffect(() {
///       final timer = Timer.periodic(
///         Duration(seconds: 1),
///         (_) => seconds.value++,
///       );
///       return timer.cancel; // Cleanup
///     }, []); // Empty keys = run once
///
///     return Text('${seconds.value}s');
///   }
/// }
/// ```
void useEffect(Object? Function() effect, [List<Object?>? keys]) {
  final state = SparkState.current!;
  state.use(() => _EffectHookState(effect, keys)).maybeRerun(keys);
}

class _EffectHookState extends _HookState<void> {
  _EffectHookState(this._effect, this._keys);

  final Object? Function() _effect;
  List<Object?>? _keys;
  void Function()? _cleanup;
  bool _hasRunInitial = false;

  @override
  void init() {
    // Don't run here — maybeRerun handles the first execution too.
  }

  void maybeRerun(List<Object?>? newKeys) {
    if (!_hasRunInitial) {
      // First build — always run
      _hasRunInitial = true;
      _run();
      return;
    }

    if (newKeys == null) {
      // null keys = run every build
      _disposeCleanup();
      _run();
      return;
    }

    if (_keys == null) return;
    if (_keys!.length != newKeys.length || _keysChanged(_keys!, newKeys)) {
      _disposeCleanup();
      _keys = newKeys;
      _run();
    }
  }

  void _run() {
    final result = _effect();
    if (result is void Function()) {
      _cleanup = result;
    } else {
      _cleanup = null;
    }
  }

  void _disposeCleanup() {
    _cleanup?.call();
    _cleanup = null;
  }

  static bool _keysChanged(List<Object?> old, List<Object?> current) {
    for (var i = 0; i < old.length; i++) {
      if (old[i] != current[i]) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _disposeCleanup();
  }
}

// =============================================================================
// useMemo — Memoized computation
// =============================================================================

/// Memoizes an expensive computation. The value is recomputed only when
/// [keys] change.
///
/// ```dart
/// class ExpensiveWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final items = useCore<List<int>>([3, 1, 4, 1, 5]);
///     final sorted = useMemo(
///       () => List<int>.from(items.value)..sort(),
///       [items.value.length],
///     );
///
///     return Text('Sorted: $sorted');
///   }
/// }
/// ```
T useMemo<T>(T Function() factory, [List<Object?>? keys]) {
  final state = SparkState.current!;
  return state.use(() => _MemoHookState<T>(factory, keys)).maybeRecompute(keys);
}

class _MemoHookState<T> extends _HookState<T> {
  _MemoHookState(this._factory, this._keys);

  final T Function() _factory;
  List<Object?>? _keys;
  late T _value;

  @override
  void init() {
    _value = _factory();
  }

  T maybeRecompute(List<Object?>? newKeys) {
    if (newKeys == null) {
      // null keys = recompute every build
      _value = _factory();
      return _value;
    }

    if (_keys != null &&
        _keys!.length == newKeys.length &&
        !_EffectHookState._keysChanged(_keys!, newKeys)) {
      return _value; // Keys unchanged
    }

    _keys = newKeys;
    _value = _factory();
    return _value;
  }
}

// =============================================================================
// useRef — Mutable reference (no rebuild)
// =============================================================================

/// Creates a mutable reference that persists across rebuilds but does
/// **not** trigger rebuilds when changed.
///
/// Use for values you need to read in callbacks but don't need to display.
///
/// ```dart
/// class LoggerWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final clickCount = useRef(0);
///
///     return ElevatedButton(
///       onPressed: () {
///         clickCount.value++;
///         print('Clicked ${clickCount.value} times');
///       },
///       child: Text('Click me'),
///     );
///   }
/// }
/// ```
SparkRef<T> useRef<T>(T initial) {
  final state = SparkState.current!;
  return state.use(() => _RefHookState<T>(initial)).ref;
}

/// A mutable reference that does not trigger rebuilds.
///
/// Similar to React's `useRef` — holds a `.value` that can be read and
/// written freely without causing the widget to rebuild.
class SparkRef<T> {
  /// Creates a [SparkRef] with the given initial value.
  SparkRef(this.value);

  /// The current value. Setting this does NOT trigger a rebuild.
  T value;
}

class _RefHookState<T> extends _HookState<T> {
  _RefHookState(T initial) : ref = SparkRef<T>(initial);

  final SparkRef<T> ref;
}

// =============================================================================
// useTextController — Auto-disposed TextEditingController
// =============================================================================

/// Creates a [TextEditingController] that auto-disposes with the Spark.
///
/// ```dart
/// class SearchWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final controller = useTextController(text: 'initial');
///     final query = useCore('');
///
///     useEffect(() {
///       void onChanged() => query.value = controller.text;
///       controller.addListener(onChanged);
///       return () => controller.removeListener(onChanged);
///     }, []);
///
///     return TextField(controller: controller);
///   }
/// }
/// ```
TextEditingController useTextController({String? text}) {
  final state = SparkState.current!;
  return state.use(() => _TextControllerHookState(text: text)).controller;
}

class _TextControllerHookState extends _HookState<void> {
  _TextControllerHookState({this.text});

  final String? text;
  late final TextEditingController controller;

  @override
  void init() {
    controller = TextEditingController(text: text);
  }

  @override
  void dispose() {
    controller.dispose();
  }
}

// =============================================================================
// useAnimationController — Auto-disposed AnimationController
// =============================================================================

/// Creates an [AnimationController] that auto-disposes with the Spark.
///
/// The [TickerProvider] is provided automatically by the Spark's state.
///
/// ```dart
/// class FadeWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final animation = useAnimationController(
///       duration: Duration(milliseconds: 300),
///     );
///
///     useEffect(() {
///       animation.forward();
///       return null;
///     }, []);
///
///     return FadeTransition(
///       opacity: animation,
///       child: Text('Hello'),
///     );
///   }
/// }
/// ```
AnimationController useAnimationController({
  Duration? duration,
  Duration? reverseDuration,
  double initialValue = 0.0,
  double lowerBound = 0.0,
  double upperBound = 1.0,
  AnimationBehavior animationBehavior = AnimationBehavior.normal,
}) {
  final state = SparkState.current!;
  return state
      .use(
        () => _AnimationControllerHookState(
          duration: duration,
          reverseDuration: reverseDuration,
          initialValue: initialValue,
          lowerBound: lowerBound,
          upperBound: upperBound,
          animationBehavior: animationBehavior,
        ),
      )
      .controller;
}

class _AnimationControllerHookState extends _HookState<void> {
  _AnimationControllerHookState({
    this.duration,
    this.reverseDuration,
    this.initialValue = 0.0,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
    this.animationBehavior = AnimationBehavior.normal,
  });

  final Duration? duration;
  final Duration? reverseDuration;
  final double initialValue;
  final double lowerBound;
  final double upperBound;
  final AnimationBehavior animationBehavior;
  late final AnimationController controller;

  @override
  void init() {
    controller = AnimationController(
      vsync: _state,
      duration: duration,
      reverseDuration: reverseDuration,
      value: initialValue,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior,
    );
  }

  @override
  void dispose() {
    controller.dispose();
  }
}

// =============================================================================
// useFocusNode — Auto-disposed FocusNode
// =============================================================================

/// Creates a [FocusNode] that auto-disposes with the Spark.
///
/// ```dart
/// class InputWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final focusNode = useFocusNode();
///
///     useEffect(() {
///       focusNode.requestFocus();
///       return null;
///     }, []);
///
///     return TextField(focusNode: focusNode);
///   }
/// }
/// ```
FocusNode useFocusNode({
  String? debugLabel,
  FocusOnKeyEventCallback? onKeyEvent,
  bool skipTraversal = false,
  bool canRequestFocus = true,
  bool descendantsAreFocusable = true,
  bool descendantsAreTraversable = true,
}) {
  final state = SparkState.current!;
  return state
      .use(
        () => _FocusNodeHookState(
          debugLabel: debugLabel,
          onKeyEvent: onKeyEvent,
          skipTraversal: skipTraversal,
          canRequestFocus: canRequestFocus,
          descendantsAreFocusable: descendantsAreFocusable,
          descendantsAreTraversable: descendantsAreTraversable,
        ),
      )
      .focusNode;
}

class _FocusNodeHookState extends _HookState<void> {
  _FocusNodeHookState({
    this.debugLabel,
    this.onKeyEvent,
    this.skipTraversal = false,
    this.canRequestFocus = true,
    this.descendantsAreFocusable = true,
    this.descendantsAreTraversable = true,
  });

  final String? debugLabel;
  final FocusOnKeyEventCallback? onKeyEvent;
  final bool skipTraversal;
  final bool canRequestFocus;
  final bool descendantsAreFocusable;
  final bool descendantsAreTraversable;
  late final FocusNode focusNode;

  @override
  void init() {
    focusNode = FocusNode(
      debugLabel: debugLabel,
      onKeyEvent: onKeyEvent,
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
      descendantsAreFocusable: descendantsAreFocusable,
      descendantsAreTraversable: descendantsAreTraversable,
    );
  }

  @override
  void dispose() {
    focusNode.dispose();
  }
}

// =============================================================================
// useScrollController — Auto-disposed ScrollController
// =============================================================================

/// Creates a [ScrollController] that auto-disposes with the Spark.
///
/// ```dart
/// class ScrollWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final controller = useScrollController();
///     return ListView.builder(
///       controller: controller,
///       itemCount: 100,
///       itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
///     );
///   }
/// }
/// ```
ScrollController useScrollController({
  double initialScrollOffset = 0.0,
  bool keepScrollOffset = true,
  String? debugLabel,
}) {
  final state = SparkState.current!;
  return state
      .use(
        () => _ScrollControllerHookState(
          initialScrollOffset: initialScrollOffset,
          keepScrollOffset: keepScrollOffset,
          debugLabel: debugLabel,
        ),
      )
      .controller;
}

class _ScrollControllerHookState extends _HookState<void> {
  _ScrollControllerHookState({
    this.initialScrollOffset = 0.0,
    this.keepScrollOffset = true,
    this.debugLabel,
  });

  final double initialScrollOffset;
  final bool keepScrollOffset;
  final String? debugLabel;
  late final ScrollController controller;

  @override
  void init() {
    controller = ScrollController(
      initialScrollOffset: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }

  @override
  void dispose() {
    controller.dispose();
  }
}

// =============================================================================
// useTabController — Auto-disposed TabController
// =============================================================================

/// Creates a [TabController] that auto-disposes with the Spark.
///
/// ```dart
/// class TabbedWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final tabs = useTabController(length: 3);
///     return TabBar(controller: tabs, tabs: [...]);
///   }
/// }
/// ```
TabController useTabController({required int length, int initialIndex = 0}) {
  final state = SparkState.current!;
  return state
      .use(
        () =>
            _TabControllerHookState(length: length, initialIndex: initialIndex),
      )
      .controller;
}

class _TabControllerHookState extends _HookState<void> {
  _TabControllerHookState({required this.length, this.initialIndex = 0});

  final int length;
  final int initialIndex;
  late final TabController controller;

  @override
  void init() {
    controller = TabController(
      length: length,
      initialIndex: initialIndex,
      vsync: _state,
    );
  }

  @override
  void dispose() {
    controller.dispose();
  }
}

// =============================================================================
// usePageController — Auto-disposed PageController
// =============================================================================

/// Creates a [PageController] that auto-disposes with the Spark.
///
/// ```dart
/// class PagerWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final controller = usePageController();
///     return PageView(controller: controller, children: [...]);
///   }
/// }
/// ```
PageController usePageController({
  int initialPage = 0,
  bool keepPage = true,
  double viewportFraction = 1.0,
}) {
  final state = SparkState.current!;
  return state
      .use(
        () => _PageControllerHookState(
          initialPage: initialPage,
          keepPage: keepPage,
          viewportFraction: viewportFraction,
        ),
      )
      .controller;
}

class _PageControllerHookState extends _HookState<void> {
  _PageControllerHookState({
    this.initialPage = 0,
    this.keepPage = true,
    this.viewportFraction = 1.0,
  });

  final int initialPage;
  final bool keepPage;
  final double viewportFraction;
  late final PageController controller;

  @override
  void init() {
    controller = PageController(
      initialPage: initialPage,
      keepPage: keepPage,
      viewportFraction: viewportFraction,
    );
  }

  @override
  void dispose() {
    controller.dispose();
  }
}

// =============================================================================
// usePillar — Access a Pillar from the nearest Beacon
// =============================================================================

/// Accesses a [Pillar] of type [P] from the nearest [Beacon] ancestor.
///
/// This is the hooks equivalent of [Vestige] — it finds the Pillar in the
/// widget tree and causes the Spark to rebuild when the Pillar's tracked
/// state changes.
///
/// ```dart
/// class HeroDisplay extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final pillar = usePillar<HeroPillar>(context);
///     return Text('Hero: ${pillar.name.value}');
///   }
/// }
/// ```
///
/// **Note**: Unlike other hooks, [usePillar] requires [context] because it
/// reads from the widget tree via [Beacon].
P usePillar<P extends Pillar>(BuildContext context) {
  final state = SparkState.current!;
  return state.use(() => _PillarHookState<P>(context)).pillar;
}

class _PillarHookState<P extends Pillar> extends _HookState<void> {
  _PillarHookState(this._context);

  final BuildContext _context;
  late final P pillar;

  @override
  void init() {
    // Uses BeaconScope.of which checks Beacon (widget tree) first,
    // then falls back to Titan global DI, and throws if not found.
    pillar = BeaconScope.of<P>(_context);
  }
}
