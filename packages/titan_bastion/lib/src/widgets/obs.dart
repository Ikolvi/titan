import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

/// Ultra-simple auto-tracking reactive widget builder.
///
/// `Obs` rebuilds **only** when reactive values read inside it change.
/// No manual subscriptions, no consumers, no ceremony.
///
/// ## Basic usage
///
/// ```dart
/// final count = signal(0);
///
/// // Rebuilds only when count changes
/// Obs(() => Text('${count.value}'))
/// ```
///
/// ## Multiple dependencies
///
/// ```dart
/// Obs(() => Text('${firstName.value} ${lastName.value}'))
/// // Rebuilds when firstName OR lastName changes
/// ```
///
/// ## With BuildContext
///
/// ```dart
/// Obs.builder((context) {
///   final theme = Theme.of(context);
///   return Text(
///     '${count.value}',
///     style: theme.textTheme.headlineLarge,
///   );
/// })
/// ```
///
/// ## Performance tip
///
/// Place `Obs` as deep in the tree as possible:
///
/// ```dart
/// // ✅ Good — only Text rebuilds
/// Column(
///   children: [
///     const Header(),
///     Obs(() => Text('${count.value}')),
///     const Footer(),
///   ],
/// )
///
/// // ❌ Bad — entire Column rebuilds
/// Obs(() => Column(
///   children: [
///     const Header(),
///     Text('${count.value}'),
///     const Footer(),
///   ],
/// ))
/// ```
class Obs extends StatefulWidget {
  final Widget Function(BuildContext context) _builder;

  /// Creates a reactive observer that rebuilds when tracked values change.
  ///
  /// ```dart
  /// Obs(() => Text('${count.value}'))
  /// ```
  Obs(Widget Function() builder, {super.key})
      : _builder = ((_) => builder());

  /// Creates a reactive observer with access to [BuildContext].
  ///
  /// ```dart
  /// Obs.builder((context) => Text('${count.value}'))
  /// ```
  const Obs.builder(this._builder, {super.key});

  @override
  State<Obs> createState() => _ObsState();
}

class _ObsState extends State<Obs> {
  late TitanEffect _effect;
  Widget? _cachedWidget;
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _effect = TitanEffect(
      () {
        _cachedWidget = widget._builder(context);
      },
      onNotify: _onDependencyChanged,
      fireImmediately: false,
    );
  }

  void _onDependencyChanged() {
    if (mounted) {
      setState(() => _needsRebuild = true);
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
