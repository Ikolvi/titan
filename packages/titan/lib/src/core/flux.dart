/// **Flux** — Stream-like operators for reactive Cores.
///
/// Extensions on [TitanState] and [TitanComputed] that provide debounce,
/// throttle, stream conversion, and more.
///
/// ## Quick Start
///
/// ```dart
/// class SearchPillar extends Pillar {
///   late final query = core('');
///   late final debouncedQuery = query.debounce(Duration(milliseconds: 300));
///
///   @override
///   void onInit() {
///     watch(() {
///       final q = debouncedQuery.value;
///       if (q.isNotEmpty) performSearch(q);
///     });
///   }
/// }
/// ```
library;

import 'dart:async';

import 'reactive.dart';
import 'state.dart';

// ---------------------------------------------------------------------------
// Debounced Core
// ---------------------------------------------------------------------------

/// A [TitanState] that debounces updates from a source.
///
/// The value only updates after the source has stopped changing for
/// the specified [duration].
///
/// ```dart
/// final query = TitanState('');
/// final debounced = DebouncedState(query, Duration(milliseconds: 300));
///
/// query.value = 'h';
/// query.value = 'he';
/// query.value = 'hel';
/// // After 300ms of quiet: debounced.value == 'hel'
/// ```
class DebouncedState<T> extends TitanState<T> {
  final TitanState<T> _source;
  final Duration _duration;
  Timer? _timer;
  late final void Function() _unsubscribe;

  /// Creates a debounced state that follows [source] with the given [duration].
  DebouncedState(
    this._source,
    this._duration, {
    super.name,
  }) : super(_source.peek()) {
    _unsubscribe = _source.listen((_) => _onSourceChanged());
  }

  void _onSourceChanged() {
    _timer?.cancel();
    _timer = Timer(_duration, () {
      if (!isDisposed) {
        super.value = _source.peek();
      }
    });
  }

  /// Read-only — setting value directly is disabled on debounced states.
  @override
  set value(T newValue) {
    // Only update from source via timer
    throw UnsupportedError(
      'Cannot set value directly on a debounced state. '
      'Set the source state instead.',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unsubscribe();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Throttled Core
// ---------------------------------------------------------------------------

/// A [TitanState] that throttles updates from a source.
///
/// The value updates at most once per the specified [duration].
/// Uses a trailing-edge strategy: the latest value is applied when
/// the throttle window expires.
///
/// ```dart
/// final slider = TitanState(0.0);
/// final throttled = ThrottledState(slider, Duration(milliseconds: 100));
/// ```
class ThrottledState<T> extends TitanState<T> {
  final TitanState<T> _source;
  final Duration _duration;
  Timer? _timer;
  bool _hasScheduled = false;
  late final void Function() _unsubscribe;

  /// Creates a throttled state that follows [source] with the given [duration].
  ThrottledState(
    this._source,
    this._duration, {
    super.name,
  }) : super(_source.peek()) {
    _unsubscribe = _source.listen((_) => _onSourceChanged());
  }

  void _onSourceChanged() {
    if (!_hasScheduled) {
      _hasScheduled = true;
      _timer = Timer(_duration, () {
        if (!isDisposed) {
          _hasScheduled = false;
          super.value = _source.peek();
        }
      });
    }
  }

  /// Read-only — setting value directly is disabled on throttled states.
  @override
  set value(T newValue) {
    throw UnsupportedError(
      'Cannot set value directly on a throttled state. '
      'Set the source state instead.',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unsubscribe();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Extensions on TitanState
// ---------------------------------------------------------------------------

/// Stream-like operators for [TitanState] (Core).
extension FluxStateExtensions<T> on TitanState<T> {
  /// Creates a debounced version of this Core.
  ///
  /// The returned state only updates after this Core has been quiet for
  /// the specified [duration].
  ///
  /// ```dart
  /// late final query = core('');
  /// late final debouncedQuery = query.debounce(
  ///   Duration(milliseconds: 300),
  /// );
  /// ```
  DebouncedState<T> debounce(Duration duration, {String? name}) {
    return DebouncedState<T>(this, duration, name: name);
  }

  /// Creates a throttled version of this Core.
  ///
  /// The returned state updates at most once per [duration].
  ///
  /// ```dart
  /// late final slider = core(0.0);
  /// late final throttled = slider.throttle(
  ///   Duration(milliseconds: 100),
  /// );
  /// ```
  ThrottledState<T> throttle(Duration duration, {String? name}) {
    return ThrottledState<T>(this, duration, name: name);
  }

  /// Converts this Core to a [Stream] that emits on every value change.
  ///
  /// ```dart
  /// final count = TitanState(0);
  /// count.asStream().listen((v) => print(v));
  /// count.value = 1; // Prints: 1
  /// ```
  Stream<T> asStream() {
    final controller = StreamController<T>.broadcast(sync: true);
    final unsub = listen((value) {
      if (!controller.isClosed) controller.add(value);
    });

    controller.onCancel = () {
      unsub();
      controller.close();
    };

    return controller.stream;
  }
}

// ---------------------------------------------------------------------------
// Extensions on ReactiveNode (generic stream)
// ---------------------------------------------------------------------------

/// Stream conversion for any [ReactiveNode].
extension FluxNodeExtensions on ReactiveNode {
  /// Converts this node to a stream that emits on every change.
  ///
  /// Note: This emits void signals. For typed values, use
  /// [FluxStateExtensions.asStream] on a [TitanState].
  Stream<void> get onChange {
    final controller = StreamController<void>.broadcast(sync: true);
    void listener() {
      if (!controller.isClosed) controller.add(null);
    }

    addListener(listener);

    controller.onCancel = () {
      removeListener(listener);
      controller.close();
    };

    return controller.stream;
  }
}
