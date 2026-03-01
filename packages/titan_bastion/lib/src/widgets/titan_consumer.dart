import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import 'titan_scope.dart';

/// A widget that provides access to a [TitanStore] and rebuilds reactively.
///
/// [TitanConsumer] combines store access from [TitanScope] with automatic
/// reactive rebuilds, similar to [TitanBuilder] but with typed store access.
///
/// ## Usage
///
/// ```dart
/// TitanConsumer<CounterStore>(
///   builder: (context, store) => Column(
///     children: [
///       Text('Count: ${store.count.value}'),
///       ElevatedButton(
///         onPressed: store.increment,
///         child: Text('Increment'),
///       ),
///     ],
///   ),
/// )
/// ```
class TitanConsumer<T extends TitanStore> extends StatefulWidget {
  /// The builder function with typed store access.
  final Widget Function(BuildContext context, T store) builder;

  /// Creates a Titan consumer widget.
  const TitanConsumer({super.key, required this.builder});

  @override
  State<TitanConsumer<T>> createState() => _TitanConsumerState<T>();
}

class _TitanConsumerState<T extends TitanStore>
    extends State<TitanConsumer<T>> {
  late TitanEffect _effect;
  late T _store;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = widget.builder(context, _store);
      },
      onNotify: _handleChange,
      fireImmediately: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = titanContainerOf(context).get<T>();
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
