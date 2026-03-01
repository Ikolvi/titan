import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import '../widgets/titan_scope.dart';

/// Extension methods on [BuildContext] for Titan state management.
///
/// Provides convenient access to [TitanStore] instances from the
/// widget tree.
///
/// ## Usage
///
/// ```dart
/// // Get a store (reads once, no rebuild)
/// final store = context.titan<CounterStore>();
///
/// // Use in a TitanBuilder for reactive access
/// TitanBuilder(
///   builder: (context) {
///     final store = context.titan<CounterStore>();
///     return Text('${store.count.value}');
///   },
/// )
/// ```
extension TitanContextExtensions on BuildContext {
  /// Retrieves a [TitanStore] of type [T] from the nearest [TitanScope].
  ///
  /// This does NOT automatically rebuild the widget when state changes.
  /// Use [TitanBuilder] or [TitanConsumer] for reactive rebuilds.
  ///
  /// Throws [FlutterError] if no [TitanScope] is found.
  /// Throws [StateError] if the store type is not registered.
  T titan<T extends TitanStore>() {
    return titanContainerOf(this).get<T>();
  }

  /// Checks if a store of type [T] is available in the nearest [TitanScope].
  bool hasTitan<T extends TitanStore>() {
    try {
      return titanContainerOf(this).has<T>();
    } catch (_) {
      return false;
    }
  }
}
