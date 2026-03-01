import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

/// Provides a [TitanContainer] to the widget subtree.
///
/// [TitanScope] creates and manages a [TitanContainer] that can be
/// accessed by descendant widgets using [context.titan<T>()] or
/// [TitanConsumer].
///
/// ## Usage
///
/// ```dart
/// TitanScope(
///   stores: (container) {
///     container.register(() => CounterStore());
///     container.register(() => AuthStore());
///   },
///   child: MyApp(),
/// )
/// ```
///
/// ## Nested Scopes
///
/// Scopes can be nested. Child scopes inherit parent registrations
/// and can override them:
///
/// ```dart
/// TitanScope(
///   stores: (container) {
///     container.register(() => AppStore());
///   },
///   child: TitanScope(
///     stores: (container) {
///       container.register(() => FeatureStore());
///     },
///     child: FeatureWidget(),
///   ),
/// )
/// ```
class TitanScope extends StatefulWidget {
  /// Callback to register stores in the container.
  final void Function(TitanContainer container) stores;

  /// The widget subtree that can access the container.
  final Widget child;

  /// Optional modules to register in the container.
  final List<TitanModule>? modules;

  /// Creates a Titan scope.
  const TitanScope({
    super.key,
    required this.stores,
    required this.child,
    this.modules,
  });

  @override
  State<TitanScope> createState() => _TitanScopeState();
}

class _TitanScopeState extends State<TitanScope> {
  late TitanContainer _container;

  @override
  void initState() {
    super.initState();
    _initContainer();
  }

  void _initContainer() {
    // Look for parent scope to create child container
    final parentContainer = context
        .getInheritedWidgetOfExactType<_TitanInherited>()
        ?.container;

    _container = parentContainer != null
        ? parentContainer.createChild()
        : TitanContainer();

    // Register modules first
    if (widget.modules != null) {
      for (final module in widget.modules!) {
        module.register(_container);
      }
    }

    // Then register stores
    widget.stores(_container);
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TitanInherited(container: _container, child: widget.child);
  }
}

/// Internal InheritedWidget that holds the [TitanContainer].
class _TitanInherited extends InheritedWidget {
  final TitanContainer container;

  const _TitanInherited({required this.container, required super.child});

  @override
  bool updateShouldNotify(_TitanInherited oldWidget) {
    return container != oldWidget.container;
  }

  /// Retrieves the nearest [TitanContainer] from the widget tree.
  static TitanContainer of(BuildContext context) {
    final inherited = context.getInheritedWidgetOfExactType<_TitanInherited>();
    if (inherited == null) {
      throw FlutterError(
        'TitanScope not found in the widget tree.\n'
        'Make sure to wrap your widget tree with TitanScope:\n\n'
        'TitanScope(\n'
        '  stores: (container) {\n'
        '    container.register(() => MyStore());\n'
        '  },\n'
        '  child: MyApp(),\n'
        ')',
      );
    }
    return inherited.container;
  }
}

/// Provides access to the nearest [TitanContainer] from the widget tree.
TitanContainer titanContainerOf(BuildContext context) =>
    _TitanInherited.of(context);
