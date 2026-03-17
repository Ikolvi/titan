import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'colossus.dart';
import 'export/blueprint_export.dart';
import 'integration/colossus_argus.dart';
import 'integration/colossus_atlas_observer.dart';
import 'integration/colossus_basalt.dart';
import 'integration/colossus_bastion.dart';
import 'integration/colossus_envoy.dart';
import 'integration/lens.dart';
import 'monitors/sentinel.dart';
import 'relay/relay.dart';
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

  /// Whether to enable Tableau capture on Shade.
  ///
  /// When `true` (default for ColossusPlugin), Shade records DOM-like
  /// snapshots of each screen, enabling Scout to discover routes and
  /// interactive elements automatically. Required for Blueprint
  /// features to work.
  ///
  /// Defaults to `true` in ColossusPlugin (vs `false` in
  /// `Colossus.init()` for backward compatibility).
  final bool enableTableauCapture;

  /// Whether to auto-feed Shade sessions into Scout.
  ///
  /// When `true` (default), completed Shade recordings are
  /// automatically passed to `learnFromSession()`, populating
  /// the Terrain flow graph without any manual wiring.
  final bool autoLearnSessions;

  /// Whether to auto-integrate with Atlas routing.
  ///
  /// When `true` (default), ColossusPlugin will:
  /// - Register [ColossusAtlasObserver] for page-load timing
  /// - Pre-seed [RouteParameterizer] with Atlas route patterns
  /// - Auto-wire `getCurrentRoute` for route-aware recording
  ///
  /// Gracefully degrades if Atlas is not initialized or not
  /// in the dependency graph. No error if Atlas is absent.
  final bool autoAtlasIntegration;

  /// Directory for auto-exporting Blueprint data on shutdown.
  ///
  /// When non-null, ColossusPlugin will automatically export the
  /// current [BlueprintExport] (Terrain graph, Gauntlet Stratagems,
  /// and AI prompt) to this directory when the plugin detaches.
  ///
  /// This bridges runtime Blueprint data to AI assistants:
  /// the exported `.titan/blueprint.json` can be read by Copilot
  /// to understand the app's navigation and generate targeted tests.
  ///
  /// ```dart
  /// ColossusPlugin(
  ///   blueprintExportDirectory: '.titan',
  /// )
  /// ```
  final String? blueprintExportDirectory;

  /// Whether to start the [Relay] for AI-driven campaign execution.
  ///
  /// When `true`:
  /// - **Native** (Android, iOS, macOS, Windows, Linux): Starts an
  ///   embedded HTTP server on [relayConfig.port] (default 8642).
  /// - **Web**: Connects via WebSocket to the MCP server's relay
  ///   endpoint at [relayConfig.targetUrl]. The MCP server must be
  ///   started with `--relay-ws-port <port>`.
  ///
  /// Allows AI assistants to execute Campaigns, query Terrain, and
  /// receive Debrief reports — all without human interaction.
  ///
  /// ```dart
  /// // Native:
  /// ColossusPlugin(
  ///   enableRelay: true,
  ///   relayConfig: RelayConfig(port: 8642),
  /// )
  ///
  /// // Web:
  /// ColossusPlugin(
  ///   enableRelay: true,
  ///   relayConfig: RelayConfig(
  ///     targetUrl: 'ws://localhost:8643/relay',
  ///   ),
  /// )
  /// ```
  final bool enableRelay;

  /// Configuration for the [Relay] server/client.
  ///
  /// Only used when [enableRelay] is `true`.
  ///
  /// On native platforms, [RelayConfig.port] and [RelayConfig.host]
  /// control the HTTP server bind address. On web, [RelayConfig.targetUrl]
  /// specifies the MCP server's WebSocket relay endpoint.
  ///
  /// ```dart
  /// // Native — HTTP server on port 8642:
  /// ColossusPlugin(
  ///   enableRelay: true,
  ///   relayConfig: RelayConfig(
  ///     port: 8642,
  ///     host: '0.0.0.0',
  ///     authToken: 'my-secret-token',
  ///   ),
  /// )
  ///
  /// // Web — WebSocket client connecting to MCP server:
  /// ColossusPlugin(
  ///   enableRelay: true,
  ///   relayConfig: RelayConfig(
  ///     targetUrl: 'ws://localhost:8643/relay',
  ///     authToken: 'my-secret-token',
  ///   ),
  /// )
  /// ```
  final RelayConfig relayConfig;

  /// Whether to auto-connect Envoy HTTP metrics to Colossus.
  ///
  /// When `true` (default), ColossusPlugin will look for an [Envoy]
  /// registered in Titan DI (`Titan.get<Envoy>()`) and automatically
  /// wire a [MetricsCourier] that forwards every HTTP request metric
  /// to [Colossus.trackApiMetric]. Zero user configuration needed.
  ///
  /// Requires [EnvoyModule.install] to be called before [runApp]:
  ///
  /// ```dart
  /// EnvoyModule.production(baseUrl: 'https://api.example.com');
  ///
  /// runApp(
  ///   Beacon(
  ///     plugins: [ColossusPlugin()], // auto-wires Envoy → Colossus
  ///     child: MyApp(),
  ///   ),
  /// );
  /// ```
  ///
  /// Gracefully degrades — no error if Envoy is not registered.
  final bool autoEnvoyMetrics;

  /// Whether to automatically connect [ColossusArgus] for auth event
  /// tracking when [Argus] is registered in Titan DI.
  ///
  /// Gracefully degrades — no error if Argus is not registered.
  final bool autoArgusMetrics;

  /// Whether to automatically connect [ColossusBastion] for Pillar
  /// lifecycle tracking, state mutation heat maps, and effect errors.
  final bool autoBastionMetrics;

  /// Whether to enable Sentinel HTTP interception.
  ///
  /// When `true`, installs `HttpOverrides` to capture all HTTP
  /// traffic — like Charles Proxy built into the app. Works with
  /// any HTTP client (package:http, dio, Envoy, raw HttpClient).
  ///
  /// Native platforms only (`dart:io`). No-op on web.
  final bool enableSentinel;

  /// Configuration for Sentinel HTTP interception.
  final SentinelConfig sentinelConfig;

  /// Whether to install the DevTools bridge.
  ///
  /// Registers VM service extensions (`ext.colossus.*`) that
  /// DevTools extension tabs can query, and pushes events to
  /// the DevTools Performance timeline and Extension stream.
  final bool enableDevTools;

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
    this.enableTableauCapture = true,
    this.autoLearnSessions = true,
    this.autoAtlasIntegration = true,
    this.blueprintExportDirectory,
    this.enableRelay = false,
    this.relayConfig = const RelayConfig(),
    this.autoEnvoyMetrics = true,
    this.autoArgusMetrics = true,
    this.autoBastionMetrics = true,
    this.enableSentinel = false,
    this.sentinelConfig = const SentinelConfig(),
    this.enableDevTools = true,
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
      enableTableauCapture: enableTableauCapture,
      autoLearnSessions: autoLearnSessions,
      enableSentinel: enableSentinel,
      sentinelConfig: sentinelConfig,
      enableDevTools: enableDevTools,
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

    // Auto-integrate with Atlas routing (graceful — no error if Atlas
    // is not available or not yet initialized).
    if (autoAtlasIntegration) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _tryAtlasIntegration(instance);
      });
    }

    // Start Relay HTTP server for AI-driven campaign execution.
    // Scheduled post-frame so Colossus is fully initialized first.
    if (enableRelay) {
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        try {
          await instance.startRelay(config: relayConfig);
        } on SocketException catch (e) {
          // Port already in use — previous instance or hot restart.
          // Log and continue; the app runs fine without Relay.
          debugPrint(
            '[Colossus] Relay failed to bind port ${relayConfig.port}: $e',
          );
        }
      });
    }

    // Auto-connect Envoy HTTP metrics to Colossus.
    // Checks Titan DI for a registered Envoy instance and wires a
    // MetricsCourier that forwards every request to trackApiMetric().
    if (autoEnvoyMetrics) {
      ColossusEnvoy.connect();
    }

    // Auto-connect Argus auth event tracking.
    // Listens to isLoggedIn state changes and forwards as events.
    if (autoArgusMetrics) {
      ColossusArgus.connect();
    }

    // Auto-connect Bastion reactive engine observer.
    // Tracks Pillar lifecycle, state mutation frequency, effect errors.
    if (autoBastionMetrics) {
      ColossusBastion.connect();
    }
  }

  @override
  Widget buildOverlay(BuildContext context, Widget child) {
    Widget result = child;

    // Check whether the MCP Relay is connected — used to hide the
    // ShadeListener indicator (MCP agents control recording via Scry
    // tools instead). The Lens FAB visibility is controlled via the
    // toggle_lens MCP tool (sets Lens.relayConnected notifier).
    final relayRunning = enableRelay && Colossus.isActive
        ? Colossus.instance.relay.status.isRunning
        : false;

    // Lens overlay (outermost — so the overlay is on top of everything).
    if (enableLens) {
      result = Lens(enabled: true, child: result);
    }

    // ShadeListener (inside Lens — captures gestures on the app content).
    // Hide the recording indicator when the Relay is connected (MCP
    // controls recording — the status pill would be distracting).
    if (enableShade && Colossus.isActive) {
      result = ShadeListener(
        shade: Colossus.instance.shade,
        showIndicator: !relayRunning,
        child: result,
      );
    }

    return result;
  }

  @override
  void onDetach() {
    // Reset relay connection state
    Lens.relayConnected.value = false;

    // Auto-export Blueprint data before shutdown
    if (blueprintExportDirectory != null) {
      _tryBlueprintExport();
    }

    // Disconnect Envoy metrics before Colossus shuts down.
    if (autoEnvoyMetrics) {
      ColossusEnvoy.disconnect();
    }

    // Disconnect Argus auth tracking.
    if (autoArgusMetrics) {
      ColossusArgus.disconnect();
    }

    // Disconnect Bastion reactive engine observer.
    if (autoBastionMetrics) {
      ColossusBastion.disconnect();
    }

    // Disconnect any Basalt resilience monitors.
    ColossusBasalt.disconnectAll();

    // Remove Atlas observer before shutdown
    if (autoAtlasIntegration) {
      _tryAtlasCleanup();
    }
    Colossus.shutdown();
  }

  /// Attempt Atlas integration — gracefully skipped if Atlas
  /// is not available or not yet initialized.
  void _tryAtlasIntegration(Colossus instance) {
    try {
      if (!Atlas.isActive) return;

      // 1. Auto-register page-load observer
      if (instance.autoAtlasObserver == null) {
        final observer = const ColossusAtlasObserver();
        Atlas.addObserver(observer);
        instance.autoAtlasObserver = observer;
      }

      // 2. Pre-seed RouteParameterizer with declared Atlas patterns.
      // This gives Scout a head start — it knows the app's route
      // structure before any sessions are recorded.
      final patterns = Atlas.registeredPatterns;
      for (final pattern in patterns) {
        instance.scout.parameterizer.registerPattern(pattern);
      }

      // 3. Auto-wire getCurrentRoute if not user-provided.
      // This enables route-aware Shade recording automatically.
      instance.shade.getCurrentRoute ??= () {
        try {
          return Atlas.current.path;
        } catch (_) {
          return null;
        }
      };
    } catch (_) {
      // Atlas not available or not initialized — graceful degradation.
      // Blueprint features will work but with manual terrain building.
    }
  }

  /// Export Blueprint data to disk before shutdown.
  void _tryBlueprintExport() {
    try {
      final instance = Colossus.instance;
      final export = BlueprintExport.fromScout(
        scout: instance.scout,
        metadata: {'source': 'auto-export', 'plugin': 'ColossusPlugin'},
      );

      // Fire-and-forget — don't block shutdown on file I/O.
      // Uses unawaited Future intentionally.
      BlueprintExportIO.saveAll(export, directory: blueprintExportDirectory);
    } catch (_) {
      // Export failed — don't block shutdown.
    }
  }

  /// Clean up Atlas integration on shutdown.
  void _tryAtlasCleanup() {
    try {
      if (!Atlas.isActive) return;

      final instance = Colossus.instance;
      if (instance.autoAtlasObserver != null) {
        Atlas.removeObserver(instance.autoAtlasObserver!);
        instance.autoAtlasObserver = null;
      }
    } catch (_) {
      // Atlas already shut down or not available — no cleanup needed.
    }
  }

  @override
  String toString() =>
      'ColossusPlugin('
      'enableLens: $enableLens, '
      'enableShade: $enableShade, '
      'enableRelay: $enableRelay, '
      'tremors: ${tremors.length}'
      ')';
}
