import 'package:flutter/widgets.dart';

/// **TitanPlugin** — Augments a [Beacon] with additional widget wrapping
/// and lifecycle hooks.
///
/// Plugins enable zero-refactoring integration of cross-cutting concerns
/// like performance monitoring, debug overlays, and gesture recording.
/// Add or remove a plugin with a single-line change in the `plugins`
/// list — no widget tree restructuring required.
///
/// ## Usage
///
/// ```dart
/// Beacon(
///   pillars: [CounterPillar.new],
///   plugins: [
///     if (kDebugMode) ColossusPlugin(tremors: [...]),
///   ],
///   child: MaterialApp(...),
/// )
/// ```
///
/// ## Lifecycle
///
/// 1. [onAttach] — called during `Beacon.initState`, before the first build
/// 2. [buildOverlay] — called during every `Beacon.build` to wrap the child
/// 3. [onDetach] — called during `Beacon.dispose`, after Pillars are disposed
///
/// ## Creating a Plugin
///
/// ```dart
/// class MyPlugin extends TitanPlugin {
///   @override
///   void onAttach() {
///     // Initialize resources, register services
///   }
///
///   @override
///   Widget buildOverlay(BuildContext context, Widget child) {
///     return MyOverlay(child: child);
///   }
///
///   @override
///   void onDetach() {
///     // Clean up resources
///   }
/// }
/// ```
///
/// ## Plugin Order
///
/// Plugins are applied in list order. The first plugin wraps innermost
/// (closest to the child), the last wraps outermost:
///
/// ```dart
/// plugins: [PluginA(), PluginB()]
/// // Produces: PluginB(PluginA(child))
/// ```
abstract class TitanPlugin {
  /// Creates a [TitanPlugin].
  const TitanPlugin();

  /// Wraps [child] with additional widgets.
  ///
  /// Called during every [Beacon] build. Return [child] unchanged
  /// if no wrapping is needed for this build cycle.
  ///
  /// The wrapping is applied *inside* the Beacon's [InheritedWidget],
  /// so plugins have access to all Pillars registered in the same
  /// Beacon scope.
  Widget buildOverlay(BuildContext context, Widget child) => child;

  /// Called when the plugin is attached to a [Beacon].
  ///
  /// Use this to initialize resources, register services, or
  /// perform one-time setup. Called during `Beacon.initState`,
  /// after all Pillars are created and initialized.
  void onAttach() {}

  /// Called when the plugin is detached from a [Beacon].
  ///
  /// Use this to clean up resources, unregister services, or
  /// perform teardown. Called during `Beacon.dispose`, after
  /// all owned Pillars have been disposed.
  void onDetach() {}
}
