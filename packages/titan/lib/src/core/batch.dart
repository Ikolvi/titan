import 'reactive.dart';

/// Groups multiple state changes into a single notification cycle.
///
/// When multiple [TitanState] values are changed within a batch,
/// dependents are only notified once at the end, preventing unnecessary
/// intermediate recomputations and rebuilds.
///
/// ## Usage
///
/// ```dart
/// final a = TitanState(0);
/// final b = TitanState(0);
/// final sum = TitanComputed(() => a.value + b.value);
///
/// // Without batch: sum recomputes twice (once per change)
/// // With batch: sum recomputes once at the end
/// titanBatch(() {
///   a.value = 10;
///   b.value = 20;
/// });
/// ```
void titanBatch(void Function() updates) {
  if (ReactiveScope.isBatching) {
    // Already in a batch, just run updates
    updates();
    return;
  }

  ReactiveScope.beginBatch();
  try {
    updates();
  } finally {
    ReactiveScope.endBatch();
  }
}

/// Async version of [titanBatch].
///
/// Groups async state changes into a single notification cycle.
///
/// ```dart
/// await titanBatchAsync(() async {
///   a.value = await fetchA();
///   b.value = await fetchB();
/// });
/// ```
Future<void> titanBatchAsync(Future<void> Function() updates) async {
  if (ReactiveScope.isBatching) {
    await updates();
    return;
  }

  ReactiveScope.beginBatch();
  try {
    await updates();
  } finally {
    ReactiveScope.endBatch();
  }
}
