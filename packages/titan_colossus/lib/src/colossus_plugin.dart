import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'colossus.dart';
import 'integration/lens.dart';
import 'widgets/shade_listener.dart';
import 'alerts/tremor.dart';

/// **ColossusPlugin** — One-line enterprise performance monitoring.
///
/// `ColossusPlugin` is a [TitanPlugin] that automatically initializes
/// [Colossus], wraps the widget tree with [Lens] and [ShadeListener],
/// and cleans up on disposal. Add or remove performance monitoring
/// with a single line — zero widget tree restructuring.
///
/// ## Quick Start
///
/// ```dart
/// Beacon(
///   pillars: [MyPillar.new],
///   plugins: [
///     if (kDebugMode) ColossusPlugin(),
///   ],
///   child: MaterialApp(...),
/// )
/// ```
///
/// ## Full Configuration
///
/// ```dart
/// Beacon(
///   pillars: [MyPillar.new],
///   plugins: [
///     if (kDebugMode)
///       ColossusPlugin(
///         tremors: [Tremor.fps(), Tremor.leaks()],
///         enableLens: true,
///         enableShade: true,
///         enableChronicle: true,
///         shadeStoragePath: '/path/to/shade',
///         exportDirectory: '/path/to/export',
///         onExport: (paths) => Share.shareFiles(paths),
///         getCurrentRoute: () => Atlas.current.path,
///         autoReplayOnStartup: true,
///       ),
///   ],
///   child: MaterialApp.router(routerConfig: atlas.config),
/// )
/// ```
///
/// ## Removing Colossus
///
/// Delete the `ColossusPlugin(...)` line and remove the
/// `titan_colossus` import. No other changes needed.
///
/// ## What It Does
///
/// On attach (Beacon `initState`):
/// 1. Calls [Colossus.init] with the provided configuration
/// 2. Sets up export and route callbacks
/// 3. Schedules auto-replay check if configured
///
/// On build (every Beacon `build`):
/// 1. Wraps child with [ShadeListener] (if [enableShade] is true)
/// 2. Wraps with [Lens] overlay (if [enableLens] is true)
///
/// On detach (Beacon `dispose`):
/// 1. Calls [Colossus.shutdown] to clean up all resources
class ColossusPlugin extends TitanPlugin {
  /// Performance alert thresholds.
  ///
  /// ```dart
  /// ColossusPlugin(
  ///   tremors: [
  ///     Tremor.fps(threshold: 50),
  ///     Tremor.jankRate(threshold: 5),
  ///     Tremor.leaks(),
  ///   ],
  /// )
  /// ```
  final List<Tremor> tremors;

  /// Configuration for the [Vessel] memory monitor.
  final VesselConfig vesselConfig;

  /// Maximum number of frame timing entries to retain.
  final int pulseMaxHistory;

  /// Maximum number of page load entries to retain.
  final int strideMaxHistory;

  /// Whether to show the [Lens] debug overlay.
  ///
  /// Defaults to `true`. Set to `false` to use Colossus monitoring
  /// without the visual overlay.
  final bool enableLens;

  /// Whether to wrap with [ShadeListener] for gesture recording.
  ///
  /// Defaults to `true`. Set to `false` if you only need perf
  /// monitoring without gesture/macro replay.
  final bool enableShade;

  /// Whether to register Lens plugin tabs.
  final bool enableLensTab;

  /// Whether to log performance events to Chronicle.
  final bool enableChronicle;

  /// Directory path for Shade session persistence.
  final String? shadeStoragePath;

  /// Directory path for report exports.
  final String? exportDirectory;

  /// Callback invoked after reports are exported.
  ///
  /// Receives a list of saved file paths. Use for platform sharing.
  final void Function(List<String> paths)? onExport;

  /// Callback that returns the current route path.
  ///
  /// Used by Shade for route-aware recording and Phantom for
  /// route validation during replay.
  ///
  /// ```dart
  /// getCurrentRoute: () => Atlas.current.path,
  /// ```
  final String? Function()? getCurrentRoute;

  /// Whether to check for auto-replay on startup.
  ///
  /// When `true`, schedules a post-frame callback to replay
  /// a saved Shade session if configured via [Colossus.setAutoReplay].
  final bool autoReplayOnStartup;

  /// Creates a ColossusPlugin with the given configuration.
  ///
  /// All parameters mirror [Colossus.init] options. The plugin
  /// manages the full Colossus lifecycle automatically.
  const ColossusPlugin({
    this.tremors = const [],
    this.vesselConfig = const VesselConfig(),
    this.pulseMaxHistory = 300,
    this.strideMaxHistory = 100,
    this.enableLens = true,
    this.enableShade = true,
    this.enableLensTab = true,
    this.enableChronicle = true,
    this.shadeStoragePath,
    this.exportDirectory,
    this.onExport,
    this.getCurrentRoute,
    this.autoReplayOnStartup = false,
  });

  @override
  void onAttach() {
    // Initialize Colossus (idempotent — returns existing if already init'd)
    Colossus.init(
      tremors: tremors,
      vesselConfig: vesselConfig,
      pulseMaxHistory: pulseMaxHistory,
      strideMaxHistory: strideMaxHistory,
      enableLensTab: enableLensTab,
      enableChronicle: enableChronicle,
      shadeStoragePath: shadeStoragePath,
      exportDirectory: exportDirectory,
    );

    final instance = Colossus.instance;

    // Wire up export callback
    if (onExport != null) {
      instance.onExport = onExport;
    }

    // Wire up route-aware recording
    if (getCurrentRoute != null) {
      instance.shade.getCurrentRoute = getCurrentRoute;
    }

    // Schedule auto-replay check
    if (autoReplayOnStartup) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        instance.checkAutoReplay();
      });
    }
  }

  @override
  Widget buildOverlay(BuildContext context, Widget child) {
    Widget result = child;

    // Lens overlay (outermost — so the overlay is on top of everything)
    if (enableLens) {
      result = Lens(enabled: true, child: result);
    }

    // ShadeListener (inside Lens — captures gestures on the app content)
    if (enableShade && Colossus.isActive) {
      result = ShadeListener(shade: Colossus.instance.shade, child: result);
    }

    return result;
  }

  @override
  void onDetach() {
    Colossus.shutdown();
  }

  @override
  String toString() =>
      'ColossusPlugin('
      'enableLens: $enableLens, '
      'enableShade: $enableShade, '
      'tremors: ${tremors.length}'
      ')';
}
