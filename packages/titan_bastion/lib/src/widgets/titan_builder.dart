import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

/// A widget that automatically rebuilds when reactive values change.
///
/// [TitanBuilder] tracks which [TitanState] and [TitanComputed] values
/// are read during its [builder] function and automatically rebuilds
/// only when those values change.
///
/// ## Usage
///
/// ```dart
/// final counter = TitanState(0);
///
/// TitanBuilder(
///   builder: (context) => Text('Count: ${counter.value}'),
/// )
/// ```
///
/// Only the widgets inside the builder are rebuilt — the rest of the
/// tree remains untouched.
///
/// ## Multiple Dependencies
///
/// ```dart
/// TitanBuilder(
///   builder: (context) => Column(
///     children: [
///       Text('Name: ${nameState.value}'),    // tracked
///       Text('Age: ${ageState.value}'),       // tracked
///       Text('Score: ${scoreComputed.value}'), // tracked
///     ],
///   ),
/// )
/// ```
class TitanBuilder extends StatefulWidget {
  /// The builder function that builds the widget tree.
  ///
  /// Any [TitanState] or [TitanComputed] values read inside this
  /// function are automatically tracked for changes.
  final Widget Function(BuildContext context) builder;

  /// Creates a Titan builder widget.
  const TitanBuilder({
    super.key,
    required this.builder,
  });

  @override
  State<TitanBuilder> createState() => _TitanBuilderState();
}

class _TitanBuilderState extends State<TitanBuilder> {
  late TitanEffect _effect;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        // This runs during build — tracking happens automatically
        _cachedWidget = widget.builder(context);
      },
      onNotify: _handleChange,
      fireImmediately: false,
    );
  }

  void _handleChange() {
    if (mounted) {
      setState(() {
        _needsRebuild = true;
      });
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
