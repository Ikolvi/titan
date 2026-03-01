import 'reactive.dart';

/// A reactive side effect that automatically tracks dependencies
/// and re-runs when they change.
///
/// [TitanEffect] is used for performing side effects (logging, API calls,
/// persistence, etc.) in response to reactive state changes.
///
/// ## Usage
///
/// ```dart
/// final counter = TitanState(0);
///
/// // This effect auto-tracks `counter` and re-runs when it changes
/// final effect = TitanEffect(() {
///   print('Counter changed to: ${counter.value}');
/// });
///
/// counter.value = 1; // Prints: "Counter changed to: 1"
///
/// // Clean up when done
/// effect.dispose();
/// ```
///
/// ## Cleanup
///
/// If the effect function returns a [Function], it will be called as a
/// cleanup function before the next execution and on disposal:
///
/// ```dart
/// final effect = TitanEffect(() {
///   final subscription = stream.listen(handler);
///   return () => subscription.cancel(); // cleanup
/// });
/// ```
class TitanEffect extends ReactiveNode {
  final Function() _fn;
  final void Function()? _onNotify;
  Function()? _cleanup;
  final Set<ReactiveNode> _dependencies = {};
  final String? _name;
  bool _isRunning = false;

  /// Creates a reactive effect.
  ///
  /// - [fn] — The effect function. If it returns a [Function], that function
  ///   is used as cleanup before re-execution and on disposal.
  /// - [name] — Optional debug name.
  /// - [onNotify] — Optional callback invoked instead of re-running the effect
  ///   when dependencies change. Useful for Flutter widget integration.
  /// - [fireImmediately] — Whether to run the effect immediately upon creation.
  ///   Defaults to `true`.
  TitanEffect(
    Function() fn, {
    String? name,
    void Function()? onNotify,
    bool fireImmediately = true,
  })  : _fn = fn,
        _name = name,
        _onNotify = onNotify {
    if (fireImmediately) {
      _execute();
    }
  }

  /// The debug name, if provided.
  String? get name => _name;

  /// Manually triggers the effect.
  void run() {
    _execute();
  }

  void _execute() {
    if (isDisposed) return;
    if (_isRunning) return; // Prevent recursive effects

    _isRunning = true;

    // Run cleanup from previous execution
    _runCleanup();

    // Clear old dependency registrations
    _clearDependencies();

    // Push this as the current tracker
    final previous = ReactiveScope.pushTracker(this);

    try {
      final result = _fn();
      if (result is Function()) {
        _cleanup = result;
      }
    } finally {
      ReactiveScope.popTracker(previous);
      _isRunning = false;
    }
  }

  void _runCleanup() {
    _cleanup?.call();
    _cleanup = null;
  }

  void _clearDependencies() {
    for (final dep in _dependencies) {
      dep.removeDependent(this);
    }
    _dependencies.clear();
  }

  @override
  void onTracked(ReactiveNode source) {
    _dependencies.add(source);
  }

  @override
  void onDependencyChanged(ReactiveNode dependency) {
    if (isDisposed) return;

    if (_onNotify != null) {
      // Delegate to external handler (e.g., Flutter setState)
      _onNotify();
    } else {
      // Re-execute the effect
      _execute();
    }
  }

  @override
  void dispose() {
    _runCleanup();
    _clearDependencies();
    super.dispose();
  }

  @override
  String toString() {
    final label = _name != null ? '($_name)' : '';
    return 'TitanEffect$label';
  }
}
