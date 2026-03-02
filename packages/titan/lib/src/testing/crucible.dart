/// Crucible — Titan's testing harness for Pillars.
///
/// A Crucible forges and tests Pillars in isolation, providing
/// assertion helpers that dramatically reduce test boilerplate.
///
/// ## Why "Crucible"?
///
/// A crucible is a vessel for testing materials at high temperatures.
/// The Crucible tests your Pillars under pressure.
///
/// ## Usage
///
/// ```dart
/// test('increment updates count', () {
///   final crucible = Crucible<CounterPillar>(CounterPillar.new);
///
///   crucible.expectCore(crucible.pillar.count, 0);
///   crucible.pillar.increment();
///   crucible.expectCore(crucible.pillar.count, 1);
///
///   crucible.dispose();
/// });
///
/// test('login flow', () async {
///   final crucible = Crucible<AuthPillar>(
///     () => AuthPillar(api: MockApi()),
///   );
///
///   await crucible.expectStrike(
///     () => crucible.pillar.login('test@test.com', 'pass'),
///     before: () => expect(crucible.pillar.user.peek(), isNull),
///     after: () => expect(crucible.pillar.user.peek(), isNotNull),
///   );
///
///   crucible.dispose();
/// });
/// ```
library;

import '../core/state.dart';
import '../pillar/pillar.dart';

/// A testing harness for [Pillar]s.
///
/// Creates, initializes, and provides assertion helpers for testing
/// Pillars in isolation without Flutter widgets.
///
/// ```dart
/// final crucible = Crucible<CounterPillar>(CounterPillar.new);
/// crucible.pillar.increment();
/// crucible.expectCore(crucible.pillar.count, 1);
/// crucible.dispose();
/// ```
class Crucible<P extends Pillar> {
  /// The Pillar under test.
  final P pillar;

  /// Whether the Crucible has been disposed.
  bool _isDisposed = false;

  /// Recorded core value changes for verification.
  final List<CoreChange<dynamic>> _changes = [];

  /// Active listeners (for cleanup).
  final List<void Function()> _listeners = [];

  /// Creates a Crucible that instantiates and initializes a Pillar.
  ///
  /// The Pillar is created via the supplied factory and immediately
  /// initialized (calling `onInit()`).
  ///
  /// ```dart
  /// final crucible = Crucible<CounterPillar>(CounterPillar.new);
  /// ```
  Crucible(P Function() factory) : pillar = factory() {
    pillar.initialize();
  }

  /// Creates a Crucible from a pre-existing Pillar instance.
  ///
  /// The Pillar is initialized if not already.
  ///
  /// ```dart
  /// final pillar = CounterPillar();
  /// final crucible = Crucible.from(pillar);
  /// ```
  Crucible.from(this.pillar) {
    if (!pillar.isInitialized) {
      pillar.initialize();
    }
  }

  /// Whether the Crucible has been disposed.
  bool get isDisposed => _isDisposed;

  /// All recorded [CoreChange]s.
  List<CoreChange<dynamic>> get changes => List.unmodifiable(_changes);

  /// Asserts that a [Core] holds the expected value.
  ///
  /// Uses `peek()` to avoid reactive tracking.
  ///
  /// Throws [AssertionError] if the values don't match.
  ///
  /// ```dart
  /// crucible.expectCore(pillar.count, 0);
  /// pillar.increment();
  /// crucible.expectCore(pillar.count, 1);
  /// ```
  void expectCore<T>(TitanState<T> core, T expected) {
    final actual = core.peek();
    if (actual != expected) {
      throw AssertionError(
        'Crucible: Expected ${core.name ?? 'Core<$T>'} to be '
        '$expected, but was $actual.',
      );
    }
  }

  /// Executes a synchronous action and verifies state before and after.
  ///
  /// - [action] — The function to execute (e.g., a strike call).
  /// - [before] — Assertion to run before the action.
  /// - [after] — Assertion to run after the action.
  ///
  /// ```dart
  /// crucible.expectStrikeSync(
  ///   () => pillar.increment(),
  ///   before: () => expect(pillar.count.peek(), 0),
  ///   after: () => expect(pillar.count.peek(), 1),
  /// );
  /// ```
  void expectStrikeSync(
    void Function() action, {
    void Function()? before,
    void Function()? after,
  }) {
    before?.call();
    action();
    after?.call();
  }

  /// Executes an async action and verifies state before and after.
  ///
  /// - [action] — The async function to execute.
  /// - [before] — Assertion to run before the action.
  /// - [after] — Assertion to run after the action completes.
  ///
  /// ```dart
  /// await crucible.expectStrike(
  ///   () => pillar.login('email', 'pass'),
  ///   before: () => expect(pillar.user.peek(), isNull),
  ///   after: () => expect(pillar.user.peek(), isNotNull),
  /// );
  /// ```
  Future<void> expectStrike(
    Future<void> Function() action, {
    void Function()? before,
    void Function()? after,
  }) async {
    before?.call();
    await action();
    after?.call();
  }

  /// Start tracking changes on a [Core].
  ///
  /// Records every value change until [stopTracking] is called or
  /// the Crucible is disposed. Access recorded changes via [changes]
  /// or [changesFor].
  ///
  /// ```dart
  /// crucible.track(pillar.count);
  /// pillar.increment();
  /// pillar.increment();
  /// expect(crucible.changesFor(pillar.count), hasLength(2));
  /// ```
  void track<T>(TitanState<T> core) {
    final unsub = core.listen((value) {
      _changes.add(
        CoreChange<T>(core: core, value: value, timestamp: DateTime.now()),
      );
    });
    _listeners.add(unsub);
  }

  /// Returns changes recorded for a specific [Core].
  ///
  /// ```dart
  /// crucible.track(pillar.count);
  /// pillar.increment();
  /// final changes = crucible.changesFor(pillar.count);
  /// expect(changes.first.value, 1);
  /// ```
  List<CoreChange<T>> changesFor<T>(TitanState<T> core) {
    return _changes.where((c) => c.core == core).cast<CoreChange<T>>().toList();
  }

  /// Returns the values recorded for a specific [Core] as a list.
  ///
  /// Convenience shorthand for extracting just the values from
  /// [changesFor].
  ///
  /// ```dart
  /// crucible.track(pillar.count);
  /// pillar.increment();
  /// pillar.increment();
  /// expect(crucible.valuesFor(pillar.count), [1, 2]);
  /// ```
  List<T> valuesFor<T>(TitanState<T> core) {
    return changesFor<T>(core).map((c) => c.value).toList();
  }

  /// Clears all recorded changes.
  void clearChanges() => _changes.clear();

  /// Disposes the Crucible and its Pillar.
  ///
  /// Always call this in `tearDown` to prevent memory leaks.
  ///
  /// ```dart
  /// late Crucible<CounterPillar> crucible;
  ///
  /// setUp(() => crucible = Crucible(CounterPillar.new));
  /// tearDown(() => crucible.dispose());
  /// ```
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final unsub in _listeners) {
      unsub();
    }
    _listeners.clear();
    _changes.clear();
    pillar.dispose();
  }
}

/// A recorded change on a [Core].
///
/// Captures the core, new value, and timestamp of the change.
class CoreChange<T> {
  /// The [TitanState] that changed.
  final TitanState<T> core;

  /// The new value after the change.
  final T value;

  /// When the change occurred.
  final DateTime timestamp;

  /// Creates a core change record.
  const CoreChange({
    required this.core,
    required this.value,
    required this.timestamp,
  });

  @override
  String toString() => 'CoreChange<$T>(${core.name ?? 'unnamed'}: $value)';
}
