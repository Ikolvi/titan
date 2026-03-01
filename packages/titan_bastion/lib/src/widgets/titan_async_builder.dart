import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

/// A widget for rendering async state with loading, error, and data states.
///
/// [TitanAsyncBuilder] connects to a [TitanAsyncState] and automatically
/// renders the appropriate widget based on the current async state.
///
/// ## Usage
///
/// ```dart
/// TitanAsyncBuilder<List<User>>(
///   state: store.users,
///   loading: (context) => CircularProgressIndicator(),
///   error: (context, error, stackTrace) => Text('Error: $error'),
///   data: (context, users) => UserList(users: users),
/// )
/// ```
class TitanAsyncBuilder<T> extends StatefulWidget {
  /// The async state to watch.
  final TitanAsyncState<T> state;

  /// Builder for the data state.
  final Widget Function(BuildContext context, T data) data;

  /// Builder for the loading state.
  final Widget Function(BuildContext context)? loading;

  /// Builder for the error state.
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  error;

  /// Creates a Titan async builder.
  const TitanAsyncBuilder({
    super.key,
    required this.state,
    required this.data,
    this.loading,
    this.error,
  });

  @override
  State<TitanAsyncBuilder<T>> createState() => _TitanAsyncBuilderState<T>();
}

class _TitanAsyncBuilderState<T> extends State<TitanAsyncBuilder<T>> {
  late TitanEffect _effect;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = _buildForState(widget.state.value);
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

  Widget _buildForState(AsyncValue<T> asyncValue) {
    return switch (asyncValue) {
      AsyncData<T>(:final data) => widget.data(context, data),
      AsyncLoading<T>() =>
        widget.loading?.call(context) ?? const SizedBox.shrink(),
      AsyncRefreshing<T>(:final data) => widget.data(context, data),
      AsyncError<T>(:final error, :final stackTrace) =>
        widget.error?.call(context, error, stackTrace) ??
            const SizedBox.shrink(),
    };
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
