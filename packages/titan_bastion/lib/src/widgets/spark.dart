import 'dart:async';

import 'package:flutter/foundation.dart';
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
/// ### Async
/// - [useStream] — Subscribe to a [Stream], returns [AsyncValue] snapshot
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

  // -------------------------------------------------------------------------
  // Extension hooks — allow external packages to enhance Spark behavior
  // -------------------------------------------------------------------------

  /// Factory for creating [TextEditingController] instances.
  ///
  /// When set, [useTextController] delegates to this factory instead of
  /// creating a plain [TextEditingController]. This allows packages like
  /// `titan_colossus` to provide recording-aware controllers (e.g.
  /// [ShadeTextController]) without coupling `titan_bastion` to
  /// `titan_colossus`.
  ///
  /// **Performance**: When `null` (the default), zero overhead.
  /// When set, the factory runs once per [useTextController] call
  /// during the first build — subsequent rebuilds reuse the controller.
  ///
  /// ```dart
  /// // Registered by Colossus.init()
  /// Spark.textControllerFactory = ({String? text}) {
  ///   return ShadeTextController(shade: shade, text: text);
  /// };
  /// ```
  static TextEditingController Function({String? text})? textControllerFactory;

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
  /// Uses a stack to support nested Spark builds (e.g., via
  /// OverlayEntry or LayoutBuilder).
  static SparkState? current;

  /// Stack of parent SparkStates for nested build safety.
  static final List<SparkState?> _currentStack = [];

  final List<_HookState<dynamic>> _hooks = [];
  int _hookIndex = 0;
  bool _isFirstBuild = true;

  /// Guard flag: only re-run [ignite] when a reactive dependency changed,
  /// the widget received new props, or this is the first build.
  /// Parent-triggered rebuilds that don't change anything skip [ignite]
  /// entirely and return the cached widget — matching [Vestige] behavior.
  bool _needsRebuild = true;

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
  void didUpdateWidget(covariant Spark oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent rebuilt us with (possibly) new props — must re-run ignite
    // so hooks see updated widget fields.
    _needsRebuild = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsRebuild && !_isFirstBuild) {
      // No reactive dep changed and no widget prop change — return cached.
      return _cachedWidget ?? const SizedBox.shrink();
    }
    _needsRebuild = false;

    // Push/pop for nested Spark builds (stack-safe)
    _currentStack.add(current);
    current = this;
    _hookIndex = 0;
    _effect.run();
    _isFirstBuild = false;
    current = _currentStack.removeLast();

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
      _needsRebuild = true;
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

/// Shared keys-comparison helper used by [useEffect], [useMemo], and
/// [useStream] hooks.
bool _sparkKeysChanged(List<Object?> old, List<Object?> current) {
  for (var i = 0; i < old.length; i++) {
    if (old[i] != current[i]) return true;
  }
  return false;
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

  @override
  void init() {
    // No explicit listener needed — the TitanEffect auto-tracking in
    // SparkState.build() already tracks Core reads during ignite() and
    // triggers rebuild() when they change. Adding a separate listener
    // would cause redundant setState calls on every mutation.
    core = TitanState<T>(_initial, name: name);
  }

  @override
  void dispose() {
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

  @override
  void init() {
    // No explicit listener needed — the TitanEffect auto-tracking in
    // SparkState.build() already tracks Derived reads during ignite()
    // and triggers rebuild() when computed values change.
    derived = TitanComputed<T>(_compute, name: name);
  }

  @override
  void dispose() {
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
    if (identical(_keys, newKeys)) return; // fast-path for const lists
    if (_keys!.length != newKeys.length || _sparkKeysChanged(_keys!, newKeys)) {
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

    if (identical(_keys, newKeys)) return _value; // fast-path for const lists
    if (_keys != null &&
        _keys!.length == newKeys.length &&
        !_sparkKeysChanged(_keys!, newKeys)) {
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
    final factory = Spark.textControllerFactory;
    controller = factory != null
        ? factory(text: text)
        : TextEditingController(text: text);
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

// =============================================================================
// useStream — Subscribe to a Stream with auto-cleanup
// =============================================================================

/// Subscribes to a [Stream] and returns the latest [AsyncValue] snapshot.
///
/// The subscription is created on the first build and auto-cancelled when
/// the [Spark] widget is disposed. If [keys] change, the previous
/// subscription is cancelled and a new one is created for the current stream.
///
/// Returns an [AsyncValue] with the current state of the stream:
/// - [AsyncValue.loading] — no data yet (initial state)
/// - [AsyncValue.data] — latest emitted value
/// - [AsyncValue.error] — stream error
///
/// The Spark automatically rebuilds when the stream emits a new value,
/// an error, or completes.
///
/// ```dart
/// class LiveFeed extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final snapshot = useStream(myStream);
///
///     return switch (snapshot) {
///       AsyncData(:final data) => Text('Value: $data'),
///       AsyncError(:final error) => Text('Error: $error'),
///       _ => CircularProgressIndicator(),
///     };
///   }
/// }
/// ```
///
/// Use [keys] to re-subscribe when the stream source changes:
///
/// ```dart
/// class UserStream extends Spark {
///   const UserStream({required this.userId});
///   final String userId;
///
///   @override
///   Widget ignite(BuildContext context) {
///     final snapshot = useStream(
///       fetchUserStream(userId),
///       keys: [userId],
///     );
///     return Text(snapshot.dataOrNull?.name ?? 'Loading...');
///   }
/// }
/// ```
///
/// Provide [initialData] to avoid a loading state on first build:
///
/// ```dart
/// final snapshot = useStream(stream, initialData: 'default');
/// // snapshot starts as AsyncData('default') instead of AsyncLoading
/// ```
AsyncValue<T> useStream<T>(
  Stream<T> stream, {
  T? initialData,
  List<Object?>? keys,
}) {
  final state = SparkState.current!;
  final hook = state.use(
    () => _StreamHookState<T>(stream, initialData: initialData, keys: keys),
  );
  hook.maybeResubscribe(stream, keys);
  return hook.snapshot;
}

/// Hook state for [useStream].
///
/// Manages a [StreamSubscription] that auto-cancels on dispose or
/// when [keys] change (triggering a re-subscription).
class _StreamHookState<T> extends _HookState<T> {
  _StreamHookState(this._stream, {T? initialData, List<Object?>? keys})
    : _keys = keys,
      snapshot = initialData != null
          ? AsyncValue<T>.data(initialData)
          : AsyncValue<T>.loading();

  Stream<T> _stream;
  List<Object?>? _keys;
  AsyncValue<T> snapshot;
  StreamSubscription<T>? _subscription;

  @override
  void init() {
    _subscribe();
  }

  /// Re-subscribes if [keys] have changed since the last build.
  void maybeResubscribe(Stream<T> stream, List<Object?>? newKeys) {
    if (newKeys == null) return; // null keys = subscribe once, never change
    if (_keys == null) return;
    if (identical(_keys, newKeys)) return; // fast-path for const lists
    if (_keys!.length != newKeys.length || _sparkKeysChanged(_keys!, newKeys)) {
      _keys = newKeys;
      _stream = stream;
      _cancelSubscription();
      snapshot = AsyncValue<T>.loading();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = _stream.listen(
      (data) {
        snapshot = AsyncValue<T>.data(data);
        _state.rebuild();
      },
      onError: (Object error, StackTrace stackTrace) {
        snapshot = AsyncValue<T>.error(error, stackTrace);
        _state.rebuild();
      },
    );
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _cancelSubscription();
  }
}

// =============================================================================
// useFuture — Subscribe to a Future with auto-cleanup
// =============================================================================

/// Subscribes to a [Future] and returns the latest [AsyncValue] snapshot.
///
/// The future is resolved on the first build and the Spark rebuilds when
/// the result arrives. If [keys] change, the previous result is discarded
/// and the new future is awaited.
///
/// Returns an [AsyncValue] with the current state:
/// - [AsyncValue.loading] — future not yet resolved
/// - [AsyncValue.data] — future completed with a value
/// - [AsyncValue.error] — future completed with an error
///
/// ```dart
/// class UserProfile extends Spark {
///   const UserProfile({required this.userId});
///   final String userId;
///
///   @override
///   Widget ignite(BuildContext context) {
///     final snapshot = useFuture(
///       fetchUser(userId),
///       keys: [userId],
///     );
///
///     return switch (snapshot) {
///       AsyncData(:final data) => Text('Hello, ${data.name}'),
///       AsyncError(:final error) => Text('Error: $error'),
///       _ => const CircularProgressIndicator(),
///     };
///   }
/// }
/// ```
///
/// Provide [initialData] to avoid a loading state on first build:
///
/// ```dart
/// final snapshot = useFuture(future, initialData: cachedUser);
/// ```
AsyncValue<T> useFuture<T>(
  Future<T> future, {
  T? initialData,
  List<Object?>? keys,
}) {
  final state = SparkState.current!;
  final hook = state.use(
    () => _FutureHookState<T>(future, initialData: initialData, keys: keys),
  );
  hook.maybeResubscribe(future, keys);
  return hook.snapshot;
}

class _FutureHookState<T> extends _HookState<T> {
  _FutureHookState(this._future, {T? initialData, List<Object?>? keys})
    : _keys = keys,
      snapshot = initialData != null
          ? AsyncValue<T>.data(initialData)
          : AsyncValue<T>.loading();

  Future<T> _future;
  List<Object?>? _keys;
  AsyncValue<T> snapshot;

  /// Monotonically increasing token to discard stale completions.
  int _token = 0;

  @override
  void init() {
    _subscribe();
  }

  void maybeResubscribe(Future<T> future, List<Object?>? newKeys) {
    if (newKeys == null) return;
    if (_keys == null) return;
    if (identical(_keys, newKeys)) return;
    if (_keys!.length != newKeys.length || _sparkKeysChanged(_keys!, newKeys)) {
      _keys = newKeys;
      _future = future;
      snapshot = AsyncValue<T>.loading();
      _subscribe();
    }
  }

  void _subscribe() {
    final myToken = ++_token;
    _future.then(
      (data) {
        if (myToken != _token) return; // Stale — new future replaced us
        snapshot = AsyncValue<T>.data(data);
        _state.rebuild();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (myToken != _token) return;
        snapshot = AsyncValue<T>.error(error, stackTrace);
        _state.rebuild();
      },
    );
  }
}

// =============================================================================
// useCallback — Memoized callback to prevent child rebuilds
// =============================================================================

/// Memoizes a callback function, returning the same instance until
/// [keys] change.
///
/// Use this to create stable callback references that prevent unnecessary
/// child widget rebuilds. Without `useCallback`, closures are recreated
/// on every build, causing children that receive them as props to rebuild.
///
/// ```dart
/// class ParentWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final count = useCore(0);
///
///     // Same instance across rebuilds (stable for child widgets)
///     final increment = useCallback(() => count.value++, []);
///
///     return ChildWidget(onTap: increment);
///   }
/// }
/// ```
///
/// When [keys] change, the callback is recreated:
///
/// ```dart
/// final submit = useCallback(
///   () => api.submit(userId),
///   [userId], // Recreated when userId changes
/// );
/// ```
T useCallback<T extends Function>(T callback, [List<Object?>? keys]) {
  final state = SparkState.current!;
  return state
      .use(() => _CallbackHookState<T>(callback, keys))
      .maybeUpdate(callback, keys);
}

class _CallbackHookState<T extends Function> extends _HookState<T> {
  _CallbackHookState(this._callback, this._keys);

  T _callback;
  List<Object?>? _keys;

  T maybeUpdate(T callback, List<Object?>? newKeys) {
    if (newKeys == null) {
      // null keys = always use latest callback
      _callback = callback;
      return _callback;
    }

    if (identical(_keys, newKeys)) return _callback;
    if (_keys != null &&
        _keys!.length == newKeys.length &&
        !_sparkKeysChanged(_keys!, newKeys)) {
      return _callback; // Keys unchanged — return cached
    }

    _keys = newKeys;
    _callback = callback;
    return _callback;
  }
}

// =============================================================================
// useValueListenable — Listen to a Flutter ValueListenable
// =============================================================================

/// Listens to a [ValueListenable] and rebuilds the Spark when the value
/// changes. Returns the current value.
///
/// Use this for interop with Flutter's built-in `ValueNotifier`,
/// `TextEditingController`, or any other `ValueListenable<T>`.
///
/// ```dart
/// class SearchResults extends Spark {
///   const SearchResults({required this.searchNotifier});
///   final ValueNotifier<String> searchNotifier;
///
///   @override
///   Widget ignite(BuildContext context) {
///     final query = useValueListenable(searchNotifier);
///     return Text('Searching: $query');
///   }
/// }
/// ```
///
/// The listener is auto-managed — attached on first build and cleaned up
/// when the Spark disposes.
T useValueListenable<T>(ValueListenable<T> listenable) {
  final state = SparkState.current!;
  return state.use(() => _ValueListenableHookState<T>(listenable)).value;
}

class _ValueListenableHookState<T> extends _HookState<T> {
  _ValueListenableHookState(this._listenable);

  final ValueListenable<T> _listenable;
  late T value;
  late final void Function() _listener;

  @override
  void init() {
    value = _listenable.value;
    _listener = () {
      value = _listenable.value;
      _state.rebuild();
    };
    _listenable.addListener(_listener);
  }

  @override
  void dispose() {
    _listenable.removeListener(_listener);
  }
}

// =============================================================================
// usePrevious — Remember the previous value
// =============================================================================

/// Returns the previous value of [value] from the last build.
///
/// On the first build, returns `null`. On subsequent builds, returns
/// whatever [value] was during the previous `ignite()` call.
///
/// ```dart
/// class DiffWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final count = useCore(0);
///     final prev = usePrevious(count.value);
///
///     return Column(children: [
///       Text('Current: ${count.value}'),
///       Text('Previous: ${prev ?? "none"}'),
///       FilledButton(
///         onPressed: () => count.value++,
///         child: Text('Increment'),
///       ),
///     ]);
///   }
/// }
/// ```
T? usePrevious<T>(T value) {
  final state = SparkState.current!;
  final hook = state.use(() => _PreviousHookState<T>());
  final previous = hook._previous;
  hook._previous = value;
  return previous;
}

class _PreviousHookState<T> extends _HookState<T> {
  T? _previous;
}

// =============================================================================
// useDebounced — Debounced value
// =============================================================================

/// Returns a debounced version of [value].
///
/// The returned value only updates after [value] has stopped changing
/// for [timeout]. Returns `null` on the first build until the first
/// debounce completes.
///
/// ```dart
/// class SearchWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final query = useCore('');
///     final debounced = useDebounced(query.value, Duration(milliseconds: 300));
///
///     useFuture(
///       searchApi(debounced ?? ''),
///       keys: [debounced],
///     );
///
///     return TextField(onChanged: (v) => query.value = v);
///   }
/// }
/// ```
T? useDebounced<T>(T value, Duration timeout) {
  final state = SparkState.current!;
  final hook = state.use(() => _DebouncedHookState<T>(timeout));
  hook.maybeUpdate(value, timeout);
  return hook.debouncedValue;
}

class _DebouncedHookState<T> extends _HookState<T> {
  _DebouncedHookState(this._timeout);

  Duration _timeout;
  T? debouncedValue;
  T? _pendingValue;
  Timer? _timer;

  void maybeUpdate(T value, Duration timeout) {
    _timeout = timeout;
    if (_pendingValue == value) return;
    _pendingValue = value;
    _timer?.cancel();
    _timer = Timer(_timeout, () {
      debouncedValue = value;
      _state.rebuild();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
  }
}

// =============================================================================
// useListenable — General Listenable subscriber
// =============================================================================

/// Subscribes to a [Listenable] and rebuilds the Spark whenever it
/// notifies. Returns the listenable itself for property access.
///
/// Use this for interop with any Flutter [Listenable] — `ChangeNotifier`,
/// `AnimationController`, `ScrollController.position`, third-party
/// notifiers, etc. For `ValueListenable<T>` specifically, prefer
/// [useValueListenable] which returns the value directly.
///
/// ```dart
/// class AnimatedBox extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final controller = useAnimationController(
///       duration: Duration(seconds: 1),
///     );
///     // Rebuilds on every animation frame
///     useListenable(controller);
///
///     return Opacity(
///       opacity: controller.value,
///       child: Container(width: 100, height: 100, color: Colors.blue),
///     );
///   }
/// }
/// ```
T useListenable<T extends Listenable>(T listenable) {
  final state = SparkState.current!;
  state.use(() => _ListenableHookState<T>(listenable));
  return listenable;
}

class _ListenableHookState<T extends Listenable> extends _HookState<T> {
  _ListenableHookState(this._listenable);

  final T _listenable;
  late final void Function() _listener;

  @override
  void init() {
    _listener = () => _state.rebuild();
    _listenable.addListener(_listener);
  }

  @override
  void dispose() {
    _listenable.removeListener(_listener);
  }
}

// =============================================================================
// useAnimation — Animation value subscriber
// =============================================================================

/// Subscribes to an [Animation] and returns its current value.
///
/// Rebuilds on every animation tick, making this ideal for driving
/// per-frame UI updates without wrapping in `AnimatedBuilder`.
///
/// ```dart
/// class FadeBox extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final controller = useAnimationController(
///       duration: Duration(milliseconds: 500),
///     );
///     final opacity = useAnimation(controller);
///
///     useEffect(() { controller.forward(); return null; }, []);
///
///     return Opacity(opacity: opacity, child: const Placeholder());
///   }
/// }
/// ```
T useAnimation<T>(Animation<T> animation) {
  final state = SparkState.current!;
  final hook = state.use(() => _AnimationHookState<T>(animation));
  return hook.value;
}

class _AnimationHookState<T> extends _HookState<T> {
  _AnimationHookState(this._animation);

  final Animation<T> _animation;
  late T value;
  late final void Function() _listener;

  @override
  void init() {
    value = _animation.value;
    _listener = () {
      value = _animation.value;
      _state.rebuild();
    };
    _animation.addListener(_listener);
  }

  @override
  void dispose() {
    _animation.removeListener(_listener);
  }
}

// =============================================================================
// useIsMounted — Async mount safety
// =============================================================================

/// Returns a function that returns `true` if the Spark is still mounted.
///
/// Use this to guard async continuations against calling operations
/// on a disposed widget — the perennial `setState after dispose` error.
///
/// ```dart
/// class AsyncWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final isMounted = useIsMounted();
///     final data = useCore<String?>(null);
///
///     return ElevatedButton(
///       onPressed: () async {
///         final result = await fetchData();
///         if (isMounted()) {
///           data.value = result;
///         }
///       },
///       child: Text(data.value ?? 'Load'),
///     );
///   }
/// }
/// ```
bool Function() useIsMounted() {
  final state = SparkState.current!;
  return state.use(_IsMountedHookState.new).isMounted;
}

class _IsMountedHookState extends _HookState<void> {
  late final bool Function() isMounted;

  @override
  void init() {
    isMounted = () => _state.mounted;
  }
}

// =============================================================================
// useAppLifecycleState — App lifecycle observer (rebuilding)
// =============================================================================

/// Returns the current [AppLifecycleState] and rebuilds when it changes.
///
/// ```dart
/// class VideoPlayer extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final lifecycle = useAppLifecycleState();
///
///     useEffect(() {
///       if (lifecycle == AppLifecycleState.paused) pauseVideo();
///       if (lifecycle == AppLifecycleState.resumed) resumeVideo();
///       return null;
///     }, [lifecycle]);
///
///     return VideoWidget();
///   }
/// }
/// ```
AppLifecycleState useAppLifecycleState() {
  final state = SparkState.current!;
  return state.use(_AppLifecycleHookState.new).lifecycleState;
}

class _AppLifecycleHookState extends _HookState<void>
    with WidgetsBindingObserver {
  AppLifecycleState lifecycleState = AppLifecycleState.resumed;

  @override
  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycleState = state;
    _state.rebuild();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// =============================================================================
// useOnAppLifecycleStateChange — App lifecycle callback (non-rebuilding)
// =============================================================================

/// Listens to [AppLifecycleState] changes and calls [callback] without
/// triggering a rebuild. Use this for side-effects like saving drafts
/// or pausing audio.
///
/// ```dart
/// class BackgroundSaver extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     useOnAppLifecycleStateChange((previous, current) {
///       if (current == AppLifecycleState.paused) saveDraft();
///     });
///
///     return EditorWidget();
///   }
/// }
/// ```
void useOnAppLifecycleStateChange(
  void Function(AppLifecycleState? previous, AppLifecycleState current)
  callback,
) {
  final state = SparkState.current!;
  final hook = state.use(_OnAppLifecycleHookState.new);
  hook._callback = callback;
}

class _OnAppLifecycleHookState extends _HookState<void>
    with WidgetsBindingObserver {
  void Function(AppLifecycleState?, AppLifecycleState)? _callback;
  AppLifecycleState? _previous;

  @override
  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _callback?.call(_previous, state);
    _previous = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// =============================================================================
// useAutomaticKeepAlive — Keep widget alive in scrollable lists
// =============================================================================

/// Marks this Spark widget as wanting to stay alive when scrolled
/// off-screen in a [ListView], [TabBarView], or [PageView].
///
/// Equivalent to [AutomaticKeepAliveClientMixin] without the boilerplate.
///
/// ```dart
/// class ExpensiveListItem extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     useAutomaticKeepAlive();
///     return ExpensiveContent();
///   }
/// }
/// ```
///
/// Pass `false` to conditionally disable keep-alive:
///
/// ```dart
/// useAutomaticKeepAlive(wantKeepAlive: someCondition);
/// ```
void useAutomaticKeepAlive({bool wantKeepAlive = true}) {
  final state = SparkState.current!;
  final hook = state.use(_KeepAliveHookState.new);
  hook.updateKeepAlive(wantKeepAlive);
}

class _KeepAliveHookState extends _HookState<void> {
  KeepAliveHandle? _handle;

  void updateKeepAlive(bool wantKeepAlive) {
    if (wantKeepAlive) {
      if (_handle == null) {
        _handle = KeepAliveHandle();
        KeepAliveNotification(_handle!).dispatch(_state.context);
      }
    } else {
      _releaseHandle();
    }
  }

  void _releaseHandle() {
    _handle?.dispose();
    _handle = null;
  }

  @override
  void dispose() {
    _releaseHandle();
  }
}

// =============================================================================
// useReducer — Reducer-pattern state management
// =============================================================================

/// A store returned by [useReducer], containing the current [state]
/// and a [dispatch] function to apply actions.
class SparkStore<S, A> {
  SparkStore._(this._hookState);

  final _ReducerHookState<S, A> _hookState;

  /// The current state.
  S get state => _hookState.state;

  /// Dispatches an [action] through the reducer. If the state changes,
  /// the Spark rebuilds.
  void dispatch(A action) {
    final next = _hookState._reducer(state, action);
    if (!identical(next, state) && next != state) {
      _hookState.state = next;
      _hookState._state.rebuild();
    }
  }
}

/// Creates a reducer-based state store local to this Spark.
///
/// Use this for complex state with many possible transitions — form wizards,
/// multi-step workflows, or any state machine. Aligns with Titan's Strike
/// pattern philosophy.
///
/// ```dart
/// class CounterWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final store = useReducer<int, String>(
///       (state, action) => switch (action) {
///         'increment' => state + 1,
///         'decrement' => state - 1,
///         'reset' => 0,
///         _ => state,
///       },
///       initialState: 0,
///     );
///
///     return Column(children: [
///       Text('${store.state}'),
///       FilledButton(
///         onPressed: () => store.dispatch('increment'),
///         child: Text('+'),
///       ),
///     ]);
///   }
/// }
/// ```
SparkStore<S, A> useReducer<S, A>(
  S Function(S state, A action) reducer, {
  required S initialState,
}) {
  final state = SparkState.current!;
  final hook = state.use(() => _ReducerHookState<S, A>(reducer, initialState));
  hook._reducer = reducer; // Always use latest reducer closure
  return hook.store;
}

class _ReducerHookState<S, A> extends _HookState<S> {
  _ReducerHookState(this._reducer, this.state);

  S Function(S, A) _reducer;
  S state;
  late final SparkStore<S, A> store = SparkStore<S, A>._(this);
}

// =============================================================================
// useStreamController — Auto-disposed StreamController
// =============================================================================

/// Creates a [StreamController] that auto-disposes with the Spark.
///
/// Useful for bridging user input to stream-based APIs, local event buses,
/// or debouncing without Titan's Flux.
///
/// ```dart
/// class EventWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final controller = useStreamController<String>();
///
///     useEffect(() {
///       final sub = controller.stream
///         .distinct()
///         .listen((event) => print('Event: \$event'));
///       return sub.cancel;
///     }, []);
///
///     return TextField(
///       onChanged: (v) => controller.add(v),
///     );
///   }
/// }
/// ```
StreamController<T> useStreamController<T>({
  bool sync = false,
  VoidCallback? onListen,
  VoidCallback? onCancel,
}) {
  final state = SparkState.current!;
  return state
      .use(
        () => _StreamControllerHookState<T>(
          sync: sync,
          onListen: onListen,
          onCancel: onCancel,
        ),
      )
      .controller;
}

class _StreamControllerHookState<T> extends _HookState<T> {
  _StreamControllerHookState({
    required bool sync,
    VoidCallback? onListen,
    VoidCallback? onCancel,
  }) : _sync = sync,
       _onListen = onListen,
       _onCancel = onCancel;

  final bool _sync;
  final VoidCallback? _onListen;
  final VoidCallback? _onCancel;
  late final StreamController<T> controller;

  @override
  void init() {
    controller = StreamController<T>(
      sync: _sync,
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  @override
  void dispose() {
    controller.close();
  }
}

// =============================================================================
// useValueChanged — Watch value & trigger callback
// =============================================================================

/// Watches [value] and calls [valueChange] when it changes.
///
/// Returns the result of the last [valueChange] call, or `null` if the
/// value hasn't changed yet. Useful for triggering animations, analytics,
/// or navigation when a specific value transitions.
///
/// ```dart
/// class AnimatedCounter extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final count = useCore(0);
///     final controller = useAnimationController(
///       duration: Duration(milliseconds: 200),
///     );
///
///     useValueChanged(count.value, (int oldValue, AnimationController? old) {
///       controller.forward(from: 0);
///       return controller;
///     });
///
///     return Text('${count.value}');
///   }
/// }
/// ```
R? useValueChanged<T, R>(
  T value,
  R Function(T oldValue, R? oldResult) valueChange,
) {
  final state = SparkState.current!;
  final hook = state.use(() => _ValueChangedHookState<T, R>());
  return hook.maybeUpdate(value, valueChange);
}

class _ValueChangedHookState<T, R> extends _HookState<T> {
  bool _hasValue = false;
  late T _value;
  R? _result;

  R? maybeUpdate(T value, R Function(T oldValue, R? oldResult) valueChange) {
    if (_hasValue && _value != value) {
      final old = _value;
      _value = value;
      _result = valueChange(old, _result);
    } else if (!_hasValue) {
      _hasValue = true;
      _value = value;
    }
    return _result;
  }
}

// =============================================================================
// useValueNotifier — Auto-disposed ValueNotifier
// =============================================================================

/// Creates a [ValueNotifier] that auto-disposes with the Spark.
///
/// Useful for bridging Spark state to Flutter widgets that expect
/// `ValueNotifier` (e.g., `ValueListenableBuilder`, `SearchAnchor`, etc.).
///
/// ```dart
/// class BridgeWidget extends Spark {
///   @override
///   Widget ignite(BuildContext context) {
///     final counter = useValueNotifier(0);
///
///     return Column(children: [
///       // Use in a ValueListenableBuilder downstream
///       ValueListenableBuilder<int>(
///         valueListenable: counter,
///         builder: (_, value, __) => Text('Count: \$value'),
///       ),
///       FilledButton(
///         onPressed: () => counter.value++,
///         child: Text('Increment'),
///       ),
///     ]);
///   }
/// }
/// ```
ValueNotifier<T> useValueNotifier<T>(T initialValue) {
  final state = SparkState.current!;
  return state.use(() => _ValueNotifierHookState<T>(initialValue)).notifier;
}

class _ValueNotifierHookState<T> extends _HookState<T> {
  _ValueNotifierHookState(this._initialValue);

  final T _initialValue;
  late final ValueNotifier<T> notifier;

  @override
  void init() {
    notifier = ValueNotifier<T>(_initialValue);
  }

  @override
  void dispose() {
    notifier.dispose();
  }
}
