import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

/// A mixin that adds reactive capabilities to a [StatefulWidget]'s [State].
///
/// [TitanStateMixin] manages [TitanEffect] lifecycle automatically,
/// disposing effects when the state is disposed.
///
/// ## Usage
///
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with TitanStateMixin {
///   final counter = TitanState(0);
///
///   @override
///   void initState() {
///     super.initState();
///     // Create an effect that triggers rebuild
///     watch(() {
///       // Access reactive values here
///       counter.value;
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Text('Count: ${counter.value}');
///   }
/// }
/// ```
mixin TitanStateMixin<T extends StatefulWidget> on State<T> {
  final List<TitanEffect> _titanEffects = [];

  /// Creates a reactive watcher that triggers [setState] when
  /// any accessed reactive value changes.
  ///
  /// Returns the created [TitanEffect] for manual control if needed.
  TitanEffect watch(Function() fn) {
    final effect = TitanEffect(
      fn,
      onNotify: () {
        if (mounted) setState(() {});
      },
    );
    _titanEffects.add(effect);
    return effect;
  }

  /// Creates a reactive effect that runs a side effect (no rebuild).
  ///
  /// Returns the created [TitanEffect] for manual control if needed.
  TitanEffect titanEffect(Function() fn, {bool fireImmediately = true}) {
    final effect = TitanEffect(fn, fireImmediately: fireImmediately);
    _titanEffects.add(effect);
    return effect;
  }

  @override
  void dispose() {
    for (final effect in _titanEffects) {
      effect.dispose();
    }
    _titanEffects.clear();
    super.dispose();
  }
}
