import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

/// A widget that selects and watches a specific value from reactive state.
///
/// [TitanSelector] only rebuilds when the selected value changes,
/// providing fine-grained control over rebuilds for performance-critical
/// widgets.
///
/// ## Usage
///
/// ```dart
/// TitanSelector<int>(
///   selector: () => store.count.value,
///   builder: (context, count) => Text('Count: $count'),
/// )
/// ```
///
/// ## Custom Equality
///
/// ```dart
/// TitanSelector<List<User>>(
///   selector: () => store.users.value,
///   equals: (a, b) => listEquals(a, b),
///   builder: (context, users) => UserList(users: users),
/// )
/// ```
class TitanSelector<T> extends StatefulWidget {
  /// The selector function that extracts the value to watch.
  final T Function() selector;

  /// The builder function that receives the selected value.
  final Widget Function(BuildContext context, T value) builder;

  /// Optional custom equality function for change detection.
  final bool Function(T previous, T next)? equals;

  /// Creates a Titan selector widget.
  const TitanSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.equals,
  });

  @override
  State<TitanSelector<T>> createState() => _TitanSelectorState<T>();
}

class _TitanSelectorState<T> extends State<TitanSelector<T>> {
  late TitanEffect _effect;
  late T _selectedValue;
  Widget? _cachedWidget;
  bool _isFirst = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        final newValue = widget.selector();
        if (_isFirst || !_isEqual(_selectedValue, newValue)) {
          _selectedValue = newValue;
          _isFirst = false;
          _cachedWidget = widget.builder(context, _selectedValue);
        }
      },
      onNotify: _handleChange,
      fireImmediately: false,
    );
  }

  void _handleChange() {
    if (!mounted) return;

    // Re-run selector to check if selected value actually changed
    final newValue = widget.selector();
    if (!_isEqual(_selectedValue, newValue)) {
      // Don't update _selectedValue here — let _effect.run() handle it
      // so the effect closure detects the change and rebuilds _cachedWidget.
      setState(() {
        _cachedWidget = null; // Force rebuild
      });
    }
  }

  bool _isEqual(T a, T b) {
    if (widget.equals != null) return widget.equals!(a, b);
    return a == b;
  }

  @override
  void dispose() {
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedWidget == null) {
      _effect.run();
    }
    return _cachedWidget ?? const SizedBox.shrink();
  }
}
