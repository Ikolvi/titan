import 'dart:convert';

import 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        FlutterError,
        FlutterErrorDetails,
        FlutterExceptionHandler;
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Element, WidgetsBinding;
import 'package:titan_atlas/titan_atlas.dart' show Atlas;
import 'package:titan_bastion/titan_bastion.dart';
import 'package:titan_envoy/titan_envoy.dart';

import 'alerts/tremor.dart';
import 'framework_error.dart';
import 'integration/lens.dart';
import 'export/inscribe.dart';
import 'integration/blueprint_lens_tab.dart';
import 'integration/bridge_lens_tab.dart';
import 'integration/envoy_lens_tab.dart';
import 'integration/argus_lens_tab.dart';
import 'integration/colossus_lens_tab.dart';
import 'integration/shade_lens_tab.dart';
import 'metrics/decree.dart';
import 'metrics/mark.dart';
import 'monitors/pulse.dart';
import 'monitors/stride.dart';
import 'monitors/vessel.dart';
import 'recording/fresco.dart';
import 'export/blueprint_export.dart';
import 'recording/imprint.dart';
import 'recording/phantom.dart';
import 'recording/shade.dart';
import 'recording/shade_vault.dart';
import 'recording/tableau_capture.dart';
import 'testing/stratagem.dart';
import 'testing/stratagem_runner.dart';
import 'testing/verdict.dart';
import 'testing/campaign.dart';
import 'testing/debrief.dart';
import 'discovery/gauntlet.dart';
import 'discovery/lineage.dart';
import 'discovery/scout.dart';
import 'discovery/terrain.dart';
import 'integration/colossus_atlas_observer.dart';
import 'relay/relay.dart';
import 'widgets/shade_text_controller.dart';

// ---------------------------------------------------------------------------
// Colossus — Enterprise Performance Monitoring
// ---------------------------------------------------------------------------

/// **Colossus** — the all-seeing guardian of your app's performance.
///
/// Colossus is a [Pillar] that monitors frame rendering, page loads,
/// memory health, and widget rebuilds. It integrates with every major
/// Titan system: [Herald] for alerts, [Chronicle] for logging,
/// [Vigil] for error tracking, [Lens] for debug overlay, and
/// [Atlas] for route timing.
///
/// ## Why "Colossus"?
///
/// The Colossus of Rhodes — a representation of the Titan Helios —
/// stood watch over the harbor, seeing everything. Colossus stands
/// watch over your app's performance, seeing every frame, every
/// navigation, every allocation.
///
/// ## Quick Start
///
/// ```dart
/// void main() {
///   Colossus.init();
///
///   runApp(
///     Lens(
///       enabled: kDebugMode,
///       child: MaterialApp.router(routerConfig: atlas.config),
///     ),
///   );
/// }
/// ```
///
/// ## Configuration
///
/// ```dart
/// Colossus.init(
///   tremors: [
///     Tremor.fps(threshold: 50),
///     Tremor.jankRate(threshold: 5),
///     Tremor.pageLoad(threshold: Duration(seconds: 1)),
///     Tremor.memory(maxPillars: 30),
///     Tremor.leaks(),
///   ],
///   vesselConfig: VesselConfig(
///     leakThreshold: Duration(minutes: 3),
///     exemptTypes: {'AuthPillar', 'AppPillar'},
///   ),
///   enableLensTab: true,
///   enableChronicle: true,
/// );
/// ```
///
/// ## Accessing Metrics
///
/// ```dart
/// final c = Colossus.instance;
/// print('FPS: ${c.pulse.fps}');
/// print('Jank: ${c.pulse.jankRate}%');
/// print('Pillars: ${c.vessel.pillarCount}');
/// print('Rebuilds: ${c.rebuildsPerWidget}');
/// ```
///
/// ## Performance Report
///
/// ```dart
/// final report = Colossus.instance.decree();
/// print(report.summary);
/// ```
class Colossus extends Pillar {
  // -----------------------------------------------------------------------
  // Singleton
  // -----------------------------------------------------------------------

  static Colossus? _instance;

  /// The active Colossus instance.
  ///
  /// Throws if [init] has not been called.
  static Colossus get instance {
    if (_instance == null) {
      throw StateError('Colossus.init() must be called first.');
    }
    return _instance!;
  }

  /// Whether Colossus has been initialized.
  static bool get isActive => _instance != null;

  // -----------------------------------------------------------------------
  // Monitors
  // -----------------------------------------------------------------------

  /// Frame metrics monitor (FPS, jank, build/raster times).
  final Pulse pulse;

  /// Memory and leak detection monitor.
  final Vessel vessel;

  /// Page load timing monitor.
  final Stride stride;

  // -----------------------------------------------------------------------
  // Configuration
  // -----------------------------------------------------------------------

  /// Performance alert thresholds.
  final List<Tremor> _tremors;

  /// Whether to register a Lens plugin tab.
  final bool _enableLensTab;

  /// Whether to log performance events to Chronicle.
  final bool _enableChronicle;

  /// Whether to auto-feed Shade sessions into Scout for Terrain building.
  final bool _autoLearnSessions;

  // -----------------------------------------------------------------------
  // State
  // -----------------------------------------------------------------------

  final Map<String, int> _rebuildsPerWidget = {};
  final DateTime _sessionStart = DateTime.now();
  Chronicle? _chronicle;

  /// History of fired [ColossusTremor] alerts (newest last).
  ///
  /// Capped at [_maxAlertHistory] entries to prevent unbounded growth.
  final List<ColossusTremor> _alertHistory = [];

  /// Maximum number of alerts to retain in history.
  static const int _maxAlertHistory = 200;

  /// All fired performance alerts since initialization (newest last).
  ///
  /// ```dart
  /// final alerts = Colossus.instance.alertHistory;
  /// for (final alert in alerts) {
  ///   print('${alert.tremor.name}: ${alert.message}');
  /// }
  /// ```
  List<ColossusTremor> get alertHistory => List.unmodifiable(_alertHistory);

  /// Currently configured [Tremor] thresholds (read-only view).
  ///
  /// ```dart
  /// final tremors = Colossus.instance.tremors;
  /// print('Active tremors: ${tremors.map((t) => t.name)}');
  /// ```
  List<Tremor> get tremors => List.unmodifiable(_tremors);

  /// Add a [Tremor] at runtime.
  ///
  /// The tremor will be evaluated on the next performance check cycle
  /// (Pulse update, Vessel update, page load, or API metric).
  ///
  /// ```dart
  /// Colossus.instance.addTremor(
  ///   Tremor.apiLatency(threshold: Duration(milliseconds: 300)),
  /// );
  /// ```
  void addTremor(Tremor tremor) {
    _tremors.add(tremor);
  }

  /// Remove a [Tremor] by name.
  ///
  /// Returns `true` if a tremor with the given name was found and removed.
  ///
  /// ```dart
  /// Colossus.instance.removeTremor('fps_low');
  /// ```
  bool removeTremor(String name) {
    final index = _tremors.indexWhere((t) => t.name == name);
    if (index == -1) return false;
    _tremors.removeAt(index);
    return true;
  }

  /// Reset the fired state of all [Tremor] thresholds.
  ///
  /// This allows `once`-mode tremors to fire again.
  ///
  /// ```dart
  /// Colossus.instance.resetTremors();
  /// ```
  void resetTremors() {
    for (final tremor in _tremors) {
      tremor.reset();
    }
  }

  /// Clear all entries from the alert history.
  ///
  /// ```dart
  /// Colossus.instance.clearAlertHistory();
  /// ```
  void clearAlertHistory() {
    _alertHistory.clear();
  }

  // -----------------------------------------------------------------------
  // Page reload (MCP-accessible)
  // -----------------------------------------------------------------------

  /// Reload the current page by re-navigating to the active route.
  ///
  /// When [fullRebuild] is `false` (default), uses [Atlas.go] to
  /// navigate to the current route, which re-triggers Sentinel
  /// guards, page builders, and data-loading logic — equivalent
  /// to a browser page refresh.
  ///
  /// When [fullRebuild] is `true`, calls
  /// [WidgetsBinding.instance.reassembleApplication] for a full
  /// widget tree reassembly (like hot reload).
  ///
  /// Returns a map with the result:
  /// - `success`: whether the reload was performed
  /// - `method`: `'route'` or `'reassemble'`
  /// - `currentRoute`: the route that was reloaded
  ///
  /// ```dart
  /// await Colossus.instance.reloadPage();
  /// await Colossus.instance.reloadPage(fullRebuild: true);
  /// ```
  Future<Map<String, dynamic>> reloadPage({bool fullRebuild = false}) async {
    if (fullRebuild) {
      WidgetsBinding.instance.reassembleApplication();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return {
        'success': true,
        'method': 'reassemble',
        'currentRoute': shade.getCurrentRoute?.call(),
      };
    }

    final currentRoute = shade.getCurrentRoute?.call();
    if (currentRoute == null || currentRoute.isEmpty) {
      return {
        'success': false,
        'method': 'route',
        'error':
            'Unable to determine current route. '
            'Configure shade.getCurrentRoute or use fullRebuild: true.',
      };
    }

    try {
      Atlas.go(currentRoute);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return {'success': true, 'method': 'route', 'currentRoute': currentRoute};
    } catch (_) {
      // Atlas not available — fall back to reassemble
      WidgetsBinding.instance.reassembleApplication();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return {
        'success': true,
        'method': 'reassemble',
        'currentRoute': currentRoute,
        'note': 'Atlas not available — used reassemble fallback',
      };
    }
  }

  // -----------------------------------------------------------------------
  // Route history (extracted from integration events)
  // -----------------------------------------------------------------------

  /// Returns a structured navigation history from integration events.
  ///
  /// Filters events by `source == 'atlas'` and returns them in
  /// chronological order. Includes route, action type (navigate,
  /// pop, replace, etc.), and timestamp.
  ///
  /// ```dart
  /// final history = Colossus.instance.getRouteHistory();
  /// print('Routes visited: ${history['routes'].length}');
  /// ```
  Map<String, dynamic> getRouteHistory() {
    final routeEvents = _events.where((e) => e['source'] == 'atlas').toList();

    return {
      'count': routeEvents.length,
      'routes': routeEvents,
      'currentRoute': shade.getCurrentRoute?.call(),
    };
  }

  // -----------------------------------------------------------------------
  // Screenshot capture
  // -----------------------------------------------------------------------

  /// Capture a screenshot of the current screen as PNG bytes.
  ///
  /// Uses [Fresco] internally. Returns base64-encoded PNG in a
  /// structured result map. [pixelRatio] controls resolution
  /// (default 0.5 — half resolution for smaller payloads).
  ///
  /// ```dart
  /// final result = await Colossus.instance.captureScreenshot();
  /// if (result['success'] == true) {
  ///   final base64Png = result['base64'] as String;
  /// }
  /// ```
  Future<Map<String, dynamic>> captureScreenshot({
    double pixelRatio = 0.5,
  }) async {
    try {
      final bytes = await Fresco.capture(pixelRatio: pixelRatio);
      if (bytes == null) {
        return {
          'success': false,
          'error': 'Capture failed — no RenderRepaintBoundary found',
        };
      }
      return {
        'success': true,
        'sizeBytes': bytes.length,
        'pixelRatio': pixelRatio,
        'base64': base64Encode(bytes),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // -----------------------------------------------------------------------
  // Framework error capture (FlutterError.onError)
  // -----------------------------------------------------------------------

  /// Captured Flutter framework errors (newest last).
  ///
  /// Populated by hooking [FlutterError.onError] during [onInit].
  /// Captures overflow, build, layout, paint, and gesture errors.
  final List<FrameworkError> _frameworkErrors = [];

  /// Maximum number of framework errors to retain.
  static const int _maxFrameworkErrors = 200;

  // -----------------------------------------------------------------------
  // API Metrics (Envoy integration)
  // -----------------------------------------------------------------------

  /// Tracked API metrics from Envoy HTTP client (newest last).
  ///
  /// Populated via [trackApiMetric] callback. Connect Envoy's
  /// [MetricsCourier] to this method for MCP-accessible API monitoring.
  final List<Map<String, dynamic>> _apiMetrics = [];

  /// Maximum number of API metrics to retain.
  static const int _maxApiMetrics = 500;

  /// All tracked API metrics since initialization (newest last).
  ///
  /// Each entry is a JSON-serializable map with keys:
  /// `method`, `url`, `statusCode`, `durationMs`, `success`,
  /// `error`, `timestamp`, `cached`.
  ///
  /// ```dart
  /// final metrics = Colossus.instance.apiMetrics;
  /// final slow = metrics.where((m) => (m['durationMs'] as int) > 1000);
  /// print('Slow API calls: ${slow.length}');
  /// ```
  List<Map<String, dynamic>> get apiMetrics => List.unmodifiable(_apiMetrics);

  /// Tracks an API metric from Envoy's [MetricsCourier].
  ///
  /// Pass the result of [EnvoyMetric.toJson()] to this method.
  /// Metrics are stored in-memory and accessible via Relay HTTP
  /// endpoints and MCP tools.
  ///
  /// ```dart
  /// envoy.addCourier(MetricsCourier(
  ///   onMetric: (m) => Colossus.instance.trackApiMetric(m.toJson()),
  /// ));
  /// ```
  void trackApiMetric(Map<String, dynamic> metric) {
    _apiMetrics.add(metric);
    if (_apiMetrics.length > _maxApiMetrics) {
      _apiMetrics.removeAt(0);
    }
    _evaluateTremors();
  }

  // -----------------------------------------------------------------------
  // Integration Events (cross-cutting bridge events)
  // -----------------------------------------------------------------------

  /// Tracked integration events from Colossus bridges (newest last).
  ///
  /// Sources: `atlas`, `basalt`, `argus`, `bastion`, or custom bridges.
  /// Each entry is a JSON-serializable map with at least `source`, `type`,
  /// and `timestamp` keys.
  final List<Map<String, dynamic>> _events = [];

  /// Maximum number of integration events to retain.
  static const int _maxEvents = 1000;

  /// All tracked integration events since initialization (newest last).
  ///
  /// ```dart
  /// final events = Colossus.instance.events;
  /// final authEvents = events.where((e) => e['source'] == 'argus');
  /// ```
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);

  /// Tracks an integration event from a Colossus bridge.
  ///
  /// Automatically adds a `timestamp` field if not present. Events are
  /// stored in-memory and accessible via the Relay HTTP endpoint.
  ///
  /// ```dart
  /// Colossus.instance.trackEvent({
  ///   'source': 'basalt',
  ///   'type': 'circuit_trip',
  ///   'name': 'api-breaker',
  ///   'tripCount': 3,
  /// });
  /// ```
  void trackEvent(Map<String, dynamic> event) {
    final stamped = {
      ...event,
      if (!event.containsKey('timestamp'))
        'timestamp': DateTime.now().toIso8601String(),
    };
    _events.add(stamped);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
  }

  /// The original [FlutterError.onError] handler, restored on dispose.
  FlutterExceptionHandler? _previousErrorHandler;

  /// All captured Flutter framework errors since initialization (newest last).
  ///
  /// Includes overflow, build, layout, paint, and gesture errors
  /// that Flutter reports through [FlutterError.onError].
  ///
  /// ```dart
  /// final errors = Colossus.instance.frameworkErrors;
  /// final overflows = errors
  ///     .where((e) => e.category == FrameworkErrorCategory.overflow);
  /// print('Overflow errors: ${overflows.length}');
  /// ```
  List<FrameworkError> get frameworkErrors =>
      List.unmodifiable(_frameworkErrors);

  /// Notifier that fires when Terrain is updated (session analyzed).
  ///
  /// Subscribe to this in UI layers to reactively rebuild when
  /// new screens or transitions are discovered.
  final ChangeNotifier terrainNotifier = ChangeNotifier();

  ColossusLensTab? _lensTab;
  ShadeLensTab? _shadeLensTab;
  BlueprintLensTab? _blueprintLensTab;
  BridgeLensTab? _bridgeLensTab;
  EnvoyLensTab? _envoyLensTab;
  ArgusLensTab? _argusLensTab;

  /// The embedded HTTP server for AI-driven campaign execution.
  ///
  /// Relay bridges AI assistants (via MCP) to the running app,
  /// enabling fully automated testing without human interaction.
  /// Available on all platforms except web.
  ///
  /// ```dart
  /// final relay = Colossus.instance.relay;
  /// print(relay.status.isRunning); // true if started
  /// ```
  final Relay relay = Relay();

  /// Atlas observer auto-registered by [ColossusPlugin].
  ///
  /// Stored here so it can be removed on shutdown. Only non-null
  /// when auto-Atlas integration is active.
  ColossusAtlasObserver? autoAtlasObserver;

  /// Directory path for exporting reports.
  ///
  /// When set via [Colossus.init], reports are saved to this
  /// user-accessible directory (e.g., Downloads) instead of
  /// the system temp directory.
  String? _exportDirectory;

  /// Directory path for exporting reports.
  String? get exportDirectory => _exportDirectory;

  /// Callback invoked after reports are exported to disk.
  ///
  /// Receives a list of saved file paths. Use this to integrate
  /// with platform sharing (e.g., `share_plus`), open the folder,
  /// or show a notification.
  ///
  /// ```dart
  /// Colossus.instance.onExport = (paths) {
  ///   Share.shareFiles(paths, text: 'Colossus Report');
  /// };
  /// ```
  void Function(List<String> paths)? onExport;

  // -----------------------------------------------------------------------
  // Recording state (survives Lens close/reopen)
  // -----------------------------------------------------------------------

  /// The most recently recorded [ShadeSession] (in-memory).
  ///
  /// Stored on the [Colossus] instance so the Lens Shade tab can
  /// display it even after the overlay is hidden and re-opened
  /// (which disposes and recreates the tab's internal Pillar).
  ShadeSession? lastRecordedSession;

  /// Whether a standalone perf recording session is active.
  ///
  /// This state lives on the [Colossus] instance so it persists
  /// across Lens open/close cycles. The Lens UI reads this to
  /// show the correct recording indicators.
  bool _isPerfRecording = false;

  /// Whether a standalone perf recording session is active.
  bool get isPerfRecording => _isPerfRecording;

  /// When the current perf recording started.
  DateTime? _perfRecordingStart;

  /// Status message from the last perf recording operation.
  String perfRecordingStatus = '';

  /// Start a standalone performance recording session.
  ///
  /// Resets all Colossus metrics and begins tracking frame times,
  /// memory, and rebuilds. The recording persists even when the
  /// Lens overlay is closed.
  void startPerfRecording() {
    reset();
    _isPerfRecording = true;
    _perfRecordingStart = DateTime.now();
    perfRecordingStatus = '';
    _chronicle?.info('Perf recording started');
  }

  /// Stop the current performance recording session.
  ///
  /// Calculates the duration and generates a Decree.
  void stopPerfRecording() {
    final duration = _perfRecordingStart != null
        ? DateTime.now().difference(_perfRecordingStart!)
        : Duration.zero;
    _isPerfRecording = false;
    _perfRecordingStart = null;
    perfRecordingStatus =
        'Recorded ${duration.inSeconds}s — '
        'check Export tab for report';
    _chronicle?.info(
      'Perf recording stopped — ${duration.inSeconds}s captured',
    );
  }

  /// The session persistence vault.
  ///
  /// Only available if [shadeStoragePath] was provided during [init].
  ShadeVault? _vault;

  /// The session persistence vault (if configured).
  ShadeVault? get vault => _vault;

  // -----------------------------------------------------------------------
  // Constructor
  // -----------------------------------------------------------------------

  Colossus._({
    required this.pulse,
    required this.vessel,
    required this.stride,
    required List<Tremor> tremors,
    required bool enableLensTab,
    required bool enableChronicle,
    required bool autoLearnSessions,
  }) : _tremors = List<Tremor>.of(tremors),
       _enableLensTab = enableLensTab,
       _enableChronicle = enableChronicle,
       _autoLearnSessions = autoLearnSessions;

  // -----------------------------------------------------------------------
  // Factory initialization
  // -----------------------------------------------------------------------

  /// Initialize the Colossus performance monitor.
  ///
  /// Call this once at app startup, before `runApp`. Colossus
  /// registers itself in Titan's DI and begins monitoring.
  ///
  /// ```dart
  /// void main() {
  ///   Colossus.init(
  ///     tremors: [Tremor.fps(), Tremor.leaks()],
  ///     enableLensTab: true,
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  static Colossus init({
    List<Tremor> tremors = const [],
    VesselConfig vesselConfig = const VesselConfig(),
    int pulseMaxHistory = 300,
    int strideMaxHistory = 100,
    bool enableLensTab = true,
    bool enableChronicle = true,
    String? shadeStoragePath,
    String? exportDirectory,
    bool enableTableauCapture = false,
    bool enableScreenCapture = false,
    double screenCapturePixelRatio = 0.5,
    bool autoLearnSessions = true,
  }) {
    if (_instance != null) {
      return _instance!;
    }

    final colossus = Colossus._(
      pulse: Pulse(maxHistory: pulseMaxHistory),
      vessel: Vessel(
        checkInterval: vesselConfig.checkInterval,
        leakThreshold: vesselConfig.leakThreshold,
        exemptTypes: Set.of(vesselConfig.exemptTypes),
      ),
      stride: Stride(maxHistory: strideMaxHistory),
      tremors: tremors,
      enableLensTab: enableLensTab,
      enableChronicle: enableChronicle,
      autoLearnSessions: autoLearnSessions,
    );

    if (shadeStoragePath != null) {
      colossus._vault = ShadeVault(shadeStoragePath);
    }

    if (exportDirectory != null) {
      colossus._exportDirectory = exportDirectory;
    }

    // Configure Tableau capture on Shade
    colossus.shade.enableTableauCapture = enableTableauCapture;
    colossus.shade.enableScreenCapture = enableScreenCapture;
    colossus.shade.screenCapturePixelRatio = screenCapturePixelRatio;

    _instance = colossus;
    Titan.put(colossus);

    return colossus;
  }

  /// Shut down the Colossus monitor and clean up all resources.
  ///
  /// Relay stop is initiated but not awaited — the server socket
  /// is closed asynchronously. Use [shutdownAsync] if you need to
  /// await full cleanup.
  static void shutdown() {
    if (_instance != null) {
      Titan.remove<Colossus>();
      _instance = null;
    }
  }

  /// Shut down Colossus and await complete cleanup (including Relay).
  static Future<void> shutdownAsync() async {
    final instance = _instance;
    if (instance != null) {
      await instance.relay.stop();
      Titan.remove<Colossus>();
      _instance = null;
    }
  }

  // -----------------------------------------------------------------------
  // Pillar lifecycle
  // -----------------------------------------------------------------------

  @override
  void onInit() {
    if (_enableChronicle) {
      _chronicle = Chronicle('Colossus');
      _chronicle!.info('Colossus initialized — performance monitoring active');
    }

    // Start frame monitoring
    pulse.onUpdate = _onPulseUpdate;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);

    // Start memory monitoring
    vessel.onUpdate = _onVesselUpdate;
    vessel.start();

    // Start page load tracking
    stride.onPageLoad = _onPageLoad;

    // Register Lens plugin tabs (Shade first — primary workflow tab)
    if (_enableLensTab) {
      _shadeLensTab = ShadeLensTab(this);
      Lens.registerPlugin(_shadeLensTab!);
      _lensTab = ColossusLensTab(this);
      Lens.registerPlugin(_lensTab!);
      _blueprintLensTab = BlueprintLensTab(this);
      Lens.registerPlugin(_blueprintLensTab!);
      _bridgeLensTab = BridgeLensTab(this);
      Lens.registerPlugin(_bridgeLensTab!);
      _envoyLensTab = EnvoyLensTab(this);
      Lens.registerPlugin(_envoyLensTab!);
      _argusLensTab = ArgusLensTab(this);
      Lens.registerPlugin(_argusLensTab!);
    }

    // Register Spark text controller factory so useTextController()
    // automatically creates ShadeTextControllers for text recording.
    // Performance: factory runs once per hook init (first build only);
    // ShadeTextController adds a single O(1) isRecording check per
    // text change — zero overhead when not recording.
    Spark.textControllerFactory = ({String? text, String? fieldId}) {
      return ShadeTextController(shade: shade, text: text, fieldId: fieldId);
    };

    // Auto-wire Shade → Scout: every completed recording automatically
    // feeds Scout to build the Terrain flow graph. This is the key
    // zero-code integration that makes Blueprint discovery automatic.
    if (_autoLearnSessions) {
      final existingCallback = shade.onRecordingStopped;
      shade.onRecordingStopped = (session) {
        learnFromSession(session);
        existingCallback?.call(session);
      };
    }

    // Hook FlutterError.onError to capture framework errors
    // (overflow, build, layout, paint, gesture). The previous
    // handler is chained so errors still surface normally.
    _previousErrorHandler = FlutterError.onError;
    FlutterError.onError = _captureFlutterError;
  }

  @override
  void onDispose() {
    // Stop frame monitoring
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    pulse.onUpdate = null;

    // Stop memory monitoring
    vessel.dispose();

    // Unregister Lens tab
    if (_lensTab != null) {
      Lens.unregisterPlugin(_lensTab!);
      _lensTab = null;
    }
    if (_shadeLensTab != null) {
      Lens.unregisterPlugin(_shadeLensTab!);
      _shadeLensTab = null;
    }
    if (_blueprintLensTab != null) {
      Lens.unregisterPlugin(_blueprintLensTab!);
      _blueprintLensTab = null;
    }
    if (_bridgeLensTab != null) {
      Lens.unregisterPlugin(_bridgeLensTab!);
      _bridgeLensTab = null;
    }
    if (_envoyLensTab != null) {
      Lens.unregisterPlugin(_envoyLensTab!);
      _envoyLensTab = null;
    }
    if (_argusLensTab != null) {
      Lens.unregisterPlugin(_argusLensTab!);
      _argusLensTab = null;
    }

    // Stop Relay server
    relay.stop();

    // Clean up auto-learn wiring
    if (_autoLearnSessions) {
      shade.onRecordingStopped = null;
    }

    // Dispose terrain notifier
    terrainNotifier.dispose();

    // Restore original FlutterError.onError handler
    FlutterError.onError = _previousErrorHandler;
    _previousErrorHandler = null;

    _chronicle?.info('Colossus shut down');
    Spark.textControllerFactory = null;
    _instance = null;
  }

  // -----------------------------------------------------------------------
  // Relay — AI Campaign Bridge
  // -----------------------------------------------------------------------

  /// Start the Relay HTTP server for AI-driven campaign execution.
  ///
  /// Once started, AI assistants can POST Campaign JSON to
  /// `http://<host>:<port>/campaign` and receive results.
  ///
  /// ```dart
  /// await Colossus.instance.startRelay(
  ///   config: RelayConfig(port: 8642),
  /// );
  /// ```
  Future<void> startRelay({RelayConfig config = const RelayConfig()}) async {
    await relay.start(config: config, handler: _ColossusRelayHandler(this));
  }

  // -----------------------------------------------------------------------
  // Callbacks
  // -----------------------------------------------------------------------

  void _timingsCallback(List<FrameTiming> timings) {
    pulse.processTimings(timings);
  }

  void _onPulseUpdate() {
    _evaluateTremors();
  }

  void _onVesselUpdate() {
    _evaluateTremors();
  }

  void _onPageLoad(PageLoadMark mark) {
    _chronicle?.info(
      'Page load: ${mark.path} in ${mark.duration.inMilliseconds}ms',
    );
    _evaluateTremors();
  }

  // -----------------------------------------------------------------------
  // Rebuild tracking (used by Echo widget)
  // -----------------------------------------------------------------------

  /// Widget rebuild counts by label.
  Map<String, int> get rebuildsPerWidget =>
      Map.unmodifiable(_rebuildsPerWidget);

  /// Record a widget rebuild. Called internally by [Echo].
  void recordRebuild(String label) {
    _rebuildsPerWidget[label] = (_rebuildsPerWidget[label] ?? 0) + 1;
  }

  // -----------------------------------------------------------------------
  // Tremor evaluation
  // -----------------------------------------------------------------------

  void _evaluateTremors() {
    if (_tremors.isEmpty) return;

    // Compute API stats for TremorContext
    final apiCount = _apiMetrics.length;
    double apiAvgLatency = 0;
    double apiErrRate = 0;
    if (apiCount > 0) {
      final totalDuration = _apiMetrics
          .map((m) => ((m['durationMs'] as num?) ?? 0).toDouble())
          .fold<double>(0, (a, b) => a + b);
      apiAvgLatency = totalDuration / apiCount;
      final failed = _apiMetrics.where((m) => m['success'] != true).length;
      apiErrRate = (failed / apiCount) * 100;
    }

    final context = TremorContext(
      fps: pulse.fps,
      jankRate: pulse.jankRate,
      pillarCount: vessel.pillarCount,
      leakSuspects: vessel.leakSuspects,
      lastPageLoad: stride.lastPageLoad,
      rebuildsPerWidget: _rebuildsPerWidget,
      apiAvgLatencyMs: apiAvgLatency,
      apiErrorRate: apiErrRate,
      apiRequestCount: apiCount,
    );

    for (final tremor in _tremors) {
      if (tremor.evaluate(context)) {
        final event = ColossusTremor(
          tremor: tremor,
          message: _tremorMessage(tremor, context),
        );

        // Store in alert history (capped)
        _alertHistory.add(event);
        if (_alertHistory.length > _maxAlertHistory) {
          _alertHistory.removeAt(0);
        }

        // Emit via Herald
        Herald.emit(event);

        // Log via Chronicle
        _chronicle?.warning('Tremor: ${event.message}');

        // Report via Vigil
        Vigil.capture(
          'Performance alert: ${tremor.name}',
          severity: _tremorToVigilSeverity(tremor.severity),
        );
      }
    }
  }

  String _tremorMessage(Tremor tremor, TremorContext context) {
    return switch (tremor.name) {
      'fps_low' => 'FPS dropped to ${context.fps.toStringAsFixed(1)}',
      'jank_rate' => 'Jank rate at ${context.jankRate.toStringAsFixed(1)}%',
      'page_load_slow' =>
        'Page load ${context.lastPageLoad?.path} took '
            '${context.lastPageLoad?.duration.inMilliseconds}ms',
      'memory_high' => '${context.pillarCount} Pillars in memory',
      'excessive_rebuilds' => 'Excessive rebuilds detected',
      'leak_detected' =>
        'Leak suspects: ${context.leakSuspects.map((s) => s.typeName).join(', ')}',
      'api_latency_high' =>
        'API avg latency ${context.apiAvgLatencyMs.toStringAsFixed(0)}ms '
            '(${context.apiRequestCount} requests)',
      'api_error_rate' =>
        'API error rate ${context.apiErrorRate.toStringAsFixed(1)}% '
            '(${context.apiRequestCount} requests)',
      _ => '${tremor.name} threshold breached',
    };
  }

  ErrorSeverity _tremorToVigilSeverity(TremorSeverity severity) {
    return switch (severity) {
      TremorSeverity.info => ErrorSeverity.info,
      TremorSeverity.warning => ErrorSeverity.warning,
      TremorSeverity.error => ErrorSeverity.error,
    };
  }

  // -----------------------------------------------------------------------
  // Framework error capture
  // -----------------------------------------------------------------------

  /// Handles a Flutter framework error by storing it, logging it,
  /// and forwarding to the previous handler (if any).
  void _captureFlutterError(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final library = details.library;
    final context = details.context?.toDescription();

    // Truncate message to first line if very long
    final firstLine = message.contains('\n')
        ? message.substring(0, message.indexOf('\n'))
        : message;
    final truncated = firstLine.length > 300
        ? '${firstLine.substring(0, 300)}...'
        : firstLine;

    // Truncate stack trace to top 5 frames
    String? stackStr;
    if (details.stack != null) {
      final lines = details.stack.toString().split('\n');
      stackStr = lines.take(5).join('\n');
    }

    final error = FrameworkError(
      category: FrameworkError.classify(
        message: message,
        library: library,
        context: context,
      ),
      message: truncated,
      timestamp: DateTime.now(),
      library: library,
      stackTrace: stackStr,
    );

    // Store in buffer (capped)
    _frameworkErrors.add(error);
    if (_frameworkErrors.length > _maxFrameworkErrors) {
      _frameworkErrors.removeAt(0);
    }

    // Log via Chronicle
    _chronicle?.warning('Framework ${error.category.name}: $truncated');

    // Forward to previous handler (preserves default behavior)
    _previousErrorHandler?.call(details);
  }

  // -----------------------------------------------------------------------
  // Decree — Performance Report
  // -----------------------------------------------------------------------

  /// Generate a comprehensive performance [Decree] (report).
  ///
  /// ```dart
  /// final report = Colossus.instance.decree();
  /// print(report.summary);
  /// ```
  Decree decree() {
    return Decree(
      sessionStart: _sessionStart,
      totalFrames: pulse.totalFrames,
      jankFrames: pulse.jankFrames,
      avgFps: pulse.fps,
      avgBuildTime: pulse.avgBuildTime,
      avgRasterTime: pulse.avgRasterTime,
      pageLoads: List.of(stride.history),
      pillarCount: vessel.pillarCount,
      totalInstances: vessel.totalInstances,
      leakSuspects: List.of(vessel.leakSuspects),
      rebuildsPerWidget: Map.of(_rebuildsPerWidget),
    );
  }

  /// Reset all metrics and start fresh.
  void reset() {
    pulse.reset();
    vessel.reset();
    stride.reset();
    _rebuildsPerWidget.clear();
    for (final tremor in _tremors) {
      tremor.reset();
    }
    _chronicle?.info('Colossus metrics reset');
  }

  // -----------------------------------------------------------------------
  // Inscribe — Export
  // -----------------------------------------------------------------------

  /// Export the current performance metrics as a Markdown report.
  ///
  /// Shorthand for `Inscribe.markdown(decree())`.
  ///
  /// ```dart
  /// final md = Colossus.instance.inscribeMarkdown();
  /// ```
  String inscribeMarkdown() => Inscribe.markdown(decree());

  /// Export the current performance metrics as a JSON string.
  ///
  /// Shorthand for `Inscribe.json(decree())`.
  ///
  /// ```dart
  /// final json = Colossus.instance.inscribeJson();
  /// ```
  String inscribeJson() => Inscribe.json(decree());

  /// Export the current performance metrics as a self-contained HTML page.
  ///
  /// Shorthand for `Inscribe.html(decree())`.
  ///
  /// ```dart
  /// final html = Colossus.instance.inscribeHtml();
  /// ```
  String inscribeHtml() => Inscribe.html(decree());

  // -----------------------------------------------------------------------
  // Shade — Gesture Recording & Replay
  // -----------------------------------------------------------------------

  /// The gesture recorder. Use this to start/stop recording sessions.
  ///
  /// ```dart
  /// Colossus.instance.shade.startRecording(name: 'checkout_flow');
  /// // ... user interacts ...
  /// final session = Colossus.instance.shade.stopRecording();
  /// ```
  final Shade shade = Shade();

  /// Save a recorded session to the vault for later replay.
  ///
  /// Requires [shadeStoragePath] to be configured during [init].
  ///
  /// ```dart
  /// final session = Colossus.instance.shade.stopRecording();
  /// await Colossus.instance.saveSession(session);
  /// ```
  Future<String?> saveSession(ShadeSession session) async {
    if (_vault == null) {
      _chronicle?.warning(
        'Cannot save session — shadeStoragePath not configured',
      );
      return null;
    }
    final path = await _vault!.save(session);
    _chronicle?.info('Session saved: ${session.name} → $path');
    return path;
  }

  /// Load a saved session from the vault by ID.
  Future<ShadeSession?> loadSession(String sessionId) async {
    return _vault?.load(sessionId);
  }

  /// Enable or disable auto-replay on next app launch.
  ///
  /// When enabled, the next `checkAutoReplay()` call will
  /// automatically replay the specified session.
  ///
  /// ```dart
  /// // Enable auto-replay
  /// await Colossus.instance.setAutoReplay(
  ///   enabled: true,
  ///   sessionId: session.id,
  ///   speed: 2.0,
  /// );
  ///
  /// // Disable auto-replay
  /// await Colossus.instance.setAutoReplay(enabled: false);
  /// ```
  Future<void> setAutoReplay({
    required bool enabled,
    String? sessionId,
    double speed = 1.0,
  }) async {
    if (_vault == null) {
      _chronicle?.warning(
        'Cannot set auto-replay — shadeStoragePath not configured',
      );
      return;
    }
    await _vault!.setAutoReplay(
      enabled: enabled,
      sessionId: sessionId,
      speed: speed,
    );
    _chronicle?.info(
      'Auto-replay ${enabled ? 'enabled' : 'disabled'}'
      '${sessionId != null ? ' for session $sessionId' : ''}',
    );
  }

  /// Check for and execute auto-replay if configured.
  ///
  /// Call this after the widget tree is ready (e.g. in a
  /// `SchedulerBinding.addPostFrameCallback`).
  ///
  /// Returns the [PhantomResult] if a replay was executed,
  /// or `null` if auto-replay is not configured.
  ///
  /// ```dart
  /// // In main.dart after runApp:
  /// SchedulerBinding.instance.addPostFrameCallback((_) async {
  ///   await Colossus.instance.checkAutoReplay();
  /// });
  /// ```
  Future<PhantomResult?> checkAutoReplay() async {
    if (_vault == null) return null;

    final config = await _vault!.getAutoReplayConfig();
    if (config == null || !config.enabled || config.sessionId == null) {
      return null;
    }

    final session = await _vault!.load(config.sessionId!);
    if (session == null) {
      _chronicle?.warning('Auto-replay session not found: ${config.sessionId}');
      return null;
    }

    // Wait for the widget tree to fully settle before replaying.
    // A single post-frame callback may fire before animations,
    // transitions, and route-driven builds have completed.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Route mismatch check — if the restarted page is different
    // from where the session was recorded, show a warning in Lens
    // instead of replaying blindly
    if (session.startRoute != null && shade.getCurrentRoute != null) {
      final currentRoute = shade.getCurrentRoute!();
      if (currentRoute != null && currentRoute != session.startRoute) {
        final message =
            'Auto-replay blocked: session was recorded on '
            '"${session.startRoute}" but app restarted on '
            '"$currentRoute"';
        _chronicle?.warning(message);

        // Open Lens so the user sees the warning
        Lens.show();

        return null;
      }
    }

    _chronicle?.info(
      'Auto-replay starting: ${session.name} at ${config.speed}x speed',
    );

    return replaySession(session, speedMultiplier: config.speed);
  }

  /// Replay a recorded [ShadeSession] while monitoring performance.
  ///
  /// Resets Colossus metrics before replay, dispatches all events
  /// through [Phantom], then returns a [PhantomResult] with replay
  /// stats. Call [decree] afterwards for the performance report.
  ///
  /// When the session has a [ShadeSession.startRoute] and
  /// [shade.getCurrentRoute] is configured, Phantom verifies the
  /// app is on the correct page before replaying. Set
  /// [requireMatchingRoute] to `true` to throw on mismatch.
  ///
  /// ```dart
  /// final result = await Colossus.instance.replaySession(
  ///   session,
  ///   speedMultiplier: 1.0,
  /// );
  /// final report = Colossus.instance.decree();
  /// print(report.summary);
  /// ```
  Future<PhantomResult> replaySession(
    ShadeSession session, {
    double speedMultiplier = 1.0,
    bool normalizePositions = true,
    bool resetBeforeReplay = true,
    bool requireMatchingRoute = false,
    bool validateRoute = true,
    bool waitForSettled = false,
    Duration settleTimeout = const Duration(seconds: 5),
    void Function(int current, int total)? onProgress,
  }) async {
    // Route safety check
    if (session.startRoute != null && shade.getCurrentRoute != null) {
      final currentRoute = shade.getCurrentRoute!();
      if (currentRoute != null && currentRoute != session.startRoute) {
        final message =
            'Route mismatch: session was recorded on '
            '"${session.startRoute}" but app is on "$currentRoute"';
        _chronicle?.warning(message);
        if (requireMatchingRoute) {
          throw StateError(message);
        }
      }
    }

    if (resetBeforeReplay) {
      reset();
    }

    final phantom = Phantom(
      speedMultiplier: speedMultiplier,
      normalizePositions: normalizePositions,
      shade: shade,
      waitForSettled: waitForSettled,
      settleTimeout: settleTimeout,
      validateRoute: validateRoute,
      onProgress: onProgress,
    );

    _chronicle?.info(
      'Phantom replay starting: ${session.name} '
      '(${session.eventCount} events, '
      '${session.duration.inMilliseconds}ms)',
    );

    final result = await phantom.replay(session);

    if (result.routeChanged) {
      _chronicle?.warning(
        'Phantom replay stopped — route changed to '
        '"${result.invalidRoute}" '
        '(${result.eventsDispatched}/${result.totalEvents} events)',
      );
    } else {
      _chronicle?.info(
        'Phantom replay ${result.wasCancelled ? 'cancelled' : 'complete'}: '
        '${result.eventsDispatched}/${result.totalEvents} events dispatched '
        'in ${result.actualDuration.inMilliseconds}ms',
      );
    }

    return result;
  }

  // -----------------------------------------------------------------------
  // Stratagem Engine — AI-Driven Testing
  // -----------------------------------------------------------------------

  /// Execute a [Stratagem] and return the [Verdict].
  ///
  /// Runs each step against the live UI, capturing screen state as
  /// [Tableau]x and producing a detailed execution report.
  ///
  /// ```dart
  /// final stratagem = Stratagem.fromJson(jsonDecode(spec));
  /// final verdict = await Colossus.instance.executeStratagem(stratagem);
  /// print(verdict.toReport());
  /// ```
  Future<Verdict> executeStratagem(
    Stratagem stratagem, {
    bool captureScreenshots = false,
    Duration? stepTimeout,
    void Function(VerdictStep)? onStepComplete,
  }) async {
    _chronicle?.info(
      'Executing Stratagem: ${stratagem.name} '
      '(${stratagem.steps.length} steps)',
    );

    final runner = StratagemRunner(
      shade: shade,
      captureScreenshots: captureScreenshots,
      defaultStepTimeout: stepTimeout ?? const Duration(seconds: 10),
      onStepComplete: onStepComplete,
    );

    final verdict = await runner.execute(stratagem);

    _chronicle?.info(
      'Stratagem ${stratagem.name} '
      '${verdict.passed ? "PASSED" : "FAILED"}: '
      '${verdict.summary.oneLiner}',
    );

    return verdict;
  }

  /// Execute a Stratagem from a JSON file path.
  ///
  /// Reads and parses the file, then executes the Stratagem.
  /// The file must be valid JSON matching the Stratagem schema.
  ///
  /// ```dart
  /// final verdict = await Colossus.instance.executeStratagemFile(
  ///   'test/stratagems/login_flow.json',
  /// );
  /// ```
  Future<Verdict> executeStratagemFile(
    String path, {
    bool captureScreenshots = false,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArgumentError('Stratagem file not found: $path');
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final stratagem = Stratagem.fromJson(json);
    return executeStratagem(stratagem, captureScreenshots: captureScreenshots);
  }

  /// Execute all Stratagems in a directory.
  ///
  /// Scans for `*.stratagem.json` files and executes each one.
  /// Returns a list of [Verdict]s in execution order.
  ///
  /// ```dart
  /// final verdicts = await Colossus.instance.executeStratagemSuite(
  ///   directory: 'test/stratagems/',
  ///   stopOnFirstFailure: true,
  /// );
  /// for (final v in verdicts) {
  ///   print(v.summary.oneLiner);
  /// }
  /// ```
  Future<List<Verdict>> executeStratagemSuite({
    required String directory,
    bool stopOnFirstFailure = false,
    bool captureScreenshots = false,
  }) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      throw ArgumentError('Stratagem directory not found: $directory');
    }

    final files =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.stratagem.json') ||
                  f.path.endsWith('.json'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    _chronicle?.info(
      'Running Stratagem suite: ${files.length} files in $directory',
    );

    final verdicts = <Verdict>[];
    for (final file in files) {
      final verdict = await executeStratagemFile(
        file.path,
        captureScreenshots: captureScreenshots,
      );
      verdicts.add(verdict);

      if (stopOnFirstFailure && !verdict.passed) {
        _chronicle?.warning(
          'Stratagem suite stopped: ${verdict.stratagemName} failed',
        );
        break;
      }
    }

    return verdicts;
  }

  /// Get context information for AI to write better Stratagems.
  ///
  /// Returns a map containing:
  /// - `screenDimensions`: current screen size
  /// - `currentRoute`: active route (if available)
  /// - `elementCount`: number of glyphs visible
  /// - `currentTableau`: current screen state as Tableau JSON
  /// - `stratagemTemplate`: JSON schema for writing Stratagems
  /// - `templateDescription`: natural-language guide for AI
  /// - `actionList`: all available StratagemAction values
  ///
  /// ```dart
  /// final context = Colossus.instance.getAiContext();
  /// // Send context to AI along with prompt
  /// ```
  Future<Map<String, dynamic>> getAiContext() async {
    final tableau = await TableauCapture.capture(index: 0);

    return {
      'screenDimensions': {
        'width': tableau.screenWidth,
        'height': tableau.screenHeight,
      },
      'currentRoute': tableau.route,
      'elementCount': tableau.glyphs.length,
      'currentTableau': tableau.toMap(),
      'stratagemTemplate': Stratagem.template,
      'templateDescription': Stratagem.templateDescription,
      'actionList': StratagemAction.values.map((a) => a.name).toList(),
    };
  }

  /// Save a [Verdict] to disk.
  ///
  /// Writes to `[directory]/[stratagemName].verdict.json`.
  /// Defaults to the app's documents directory.
  ///
  /// ```dart
  /// await Colossus.instance.saveVerdict(verdict, directory: '/tmp/verdicts');
  /// ```
  Future<void> saveVerdict(Verdict verdict, {String? directory}) async {
    final dir = directory ?? 'verdicts';
    await verdict.saveToFile(dir);
    _chronicle?.info(
      'Verdict saved: $dir/${verdict.stratagemName}.verdict.json',
    );
  }

  /// Load a previously saved [Verdict] from disk.
  ///
  /// Returns `null` if the file doesn't exist.
  ///
  /// ```dart
  /// final verdict = await Colossus.instance.loadVerdict(
  ///   'login_flow',
  ///   directory: '/tmp/verdicts',
  /// );
  /// ```
  Future<Verdict?> loadVerdict(String name, {String? directory}) async {
    final dir = directory ?? 'verdicts';
    return Verdict.loadFromFile(name, directory: dir);
  }

  // -----------------------------------------------------------------------
  // AI Blueprint Generation — Discovery & Testing Integration
  // -----------------------------------------------------------------------

  /// The [Scout] instance for flow discovery.
  ///
  /// Scout passively builds the [Terrain] flow graph from recorded
  /// sessions and executed Stratagems.
  ///
  /// ```dart
  /// final scout = Colossus.instance.scout;
  /// scout.analyzeSession(session);
  /// ```
  Scout get scout => Scout.instance;

  /// The current [Terrain] — a complete flow graph of the app.
  ///
  /// Shows all discovered screens ([Outpost]s) and transitions
  /// ([March]es) between them.
  ///
  /// ```dart
  /// final terrain = Colossus.instance.terrain;
  /// print(terrain.toMermaid()); // Visualize the flow graph
  /// ```
  Terrain get terrain => Scout.instance.terrain;

  /// Analyze a [ShadeSession] to update the Terrain flow graph.
  ///
  /// Extracts screen fingerprints and transitions from the recorded
  /// session and feeds them into the Scout.
  ///
  /// ```dart
  /// final session = shade.stopRecording();
  /// Colossus.instance.learnFromSession(session);
  /// print(Colossus.instance.terrain.outposts.length);
  /// ```
  void learnFromSession(ShadeSession session) {
    _chronicle?.info(
      'Learning from session: ${session.name} '
      '(${session.tableaux.length} tableaux)',
    );
    Scout.instance.analyzeSession(session);
    _chronicle?.info(
      'Terrain updated: ${terrain.outposts.length} screens, '
      '${terrain.marches.length} transitions',
    );

    // Notify listeners that Terrain data has changed.
    // This allows reactive UI (like the Blueprint Lens tab) to
    // auto-rebuild without polling or manual refresh.
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    terrainNotifier.notifyListeners();
  }

  /// Generate exploration Stratagems for unmapped routes.
  ///
  /// Returns a list of Stratagems that will visit screens with
  /// limited test coverage.
  ///
  /// ```dart
  /// final sorties = Colossus.instance.generateSorties();
  /// for (final s in sorties) {
  ///   await Colossus.instance.executeStratagem(s);
  /// }
  /// ```
  List<Stratagem> generateSorties() {
    final sorties = Scout.instance.generateAllSorties();
    _chronicle?.info('Generated ${sorties.length} exploration sorties');
    return sorties;
  }

  /// Resolve prerequisites for reaching a specific route.
  ///
  /// Returns a [Lineage] describing the shortest path from an app
  /// entry point to the target, including any auth or form gates.
  ///
  /// ```dart
  /// final lineage = Colossus.instance.resolveLineage('/settings/profile');
  /// print(lineage.toAiSummary());
  /// ```
  Lineage resolveLineage(String targetRoute) {
    return Lineage.resolve(terrain, targetRoute: targetRoute);
  }

  /// Get prerequisite chain as AI-readable text.
  ///
  /// Returns a formatted string describing the navigation steps
  /// needed to reach the target route.
  ///
  /// ```dart
  /// final summary = Colossus.instance.getLineageSummary('/dashboard');
  /// // Send to AI along with Stratagem prompt
  /// ```
  String getLineageSummary(String targetRoute) {
    return resolveLineage(targetRoute).toAiSummary();
  }

  /// Generate edge-case test Stratagems for a specific screen.
  ///
  /// Looks up the [Outpost] for [routePattern] in the Terrain,
  /// resolves its [Lineage], and generates stress/boundary tests.
  ///
  /// ```dart
  /// final tests = Colossus.instance.generateGauntlet(
  ///   '/login',
  ///   intensity: GauntletIntensity.thorough,
  /// );
  /// ```
  List<Stratagem> generateGauntlet(
    String routePattern, {
    GauntletIntensity intensity = GauntletIntensity.standard,
  }) {
    final outpost = terrain.outposts[routePattern];
    if (outpost == null) {
      _chronicle?.warning('Gauntlet: no outpost found for "$routePattern"');
      return [];
    }

    final lineage = Lineage.resolve(terrain, targetRoute: routePattern);
    final stratagems = Gauntlet.generateFor(
      outpost,
      lineage: lineage.isNotEmpty ? lineage : null,
      intensity: intensity,
    );

    _chronicle?.info(
      'Generated ${stratagems.length} Gauntlet tests for "$routePattern" '
      '(intensity: ${intensity.name})',
    );

    return stratagems;
  }

  /// Execute a [Campaign] — an ordered test suite with dependencies.
  ///
  /// Resolves prerequisites, performs topological sort, and executes
  /// Stratagems in dependency order.
  ///
  /// The [navigateToRoute] callback is used to programmatically navigate
  /// to each Stratagem's `startRoute` before its steps execute. When
  /// `null`, the runner navigates via [Atlas.go] as the default.
  ///
  /// ```dart
  /// final result = await Colossus.instance.executeCampaign(campaign);
  /// print(result.passRate);
  /// ```
  Future<CampaignResult> executeCampaign(
    Campaign campaign, {
    bool captureScreenshots = false,
    Future<void> Function(String route)? navigateToRoute,
  }) async {
    _chronicle?.info(
      'Executing Campaign: ${campaign.name} '
      '(${campaign.entries.length} entries)',
    );

    final runner = StratagemRunner(
      shade: shade,
      captureScreenshots: captureScreenshots,
      defaultStepTimeout: campaign.timeout,
      navigateToRoute: navigateToRoute ?? _defaultNavigateToRoute,
      authStratagem: campaign.authStratagem,
    );

    final result = await campaign.execute(runner: runner, terrain: terrain);

    _chronicle?.info(
      'Campaign ${campaign.name} complete: '
      '${result.totalExecuted} executed, '
      '${result.totalFailed} failed '
      '(${(result.passRate * 100).toStringAsFixed(1)}%)',
    );

    return result;
  }

  /// Execute a [Campaign] from JSON.
  ///
  /// Deserializes the JSON into a [Campaign] and executes it.
  ///
  /// ```dart
  /// final result = await Colossus.instance.executeCampaignJson(json);
  /// ```
  Future<CampaignResult> executeCampaignJson(
    Map<String, dynamic> json, {
    bool captureScreenshots = false,
    Future<void> Function(String route)? navigateToRoute,
  }) {
    final campaign = Campaign.fromJson(json);
    return executeCampaign(
      campaign,
      captureScreenshots: captureScreenshots,
      navigateToRoute: navigateToRoute,
    );
  }

  /// Default navigation callback for the [StratagemRunner].
  ///
  /// Uses [Atlas.go] for declarative navigation. If Atlas is
  /// not initialized (no router configured), the call is caught
  /// and silently ignored so the remaining steps still execute.
  Future<void> _defaultNavigateToRoute(String route) async {
    try {
      Atlas.go(route);
      // Allow the frame to settle after navigation
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } catch (_) {
      // Atlas not initialized — skip programmatic navigation
    }
  }

  /// Analyze verdicts and produce a [DebriefReport].
  ///
  /// Feeds verdicts back into the Terrain via Scout, classifies
  /// failures, detects patterns, and suggests next actions.
  ///
  /// ```dart
  /// final report = Colossus.instance.debrief(verdicts);
  /// print(report.toAiSummary());
  /// ```
  DebriefReport debrief(List<Verdict> verdicts) {
    _chronicle?.info('Debriefing ${verdicts.length} verdicts');

    final report = Debrief(verdicts: verdicts, terrain: terrain).analyze();

    _chronicle?.info(
      'Debrief complete: ${report.passedVerdicts}/${report.totalVerdicts} '
      'passed, ${report.insights.length} insights',
    );

    return report;
  }

  /// Get comprehensive AI context for Blueprint generation.
  ///
  /// Returns everything an AI agent needs to write effective
  /// Stratagems: screen inventory, transitions, element details,
  /// auth gates, dead ends, and template schemas.
  ///
  /// This is the **primary method AI agents call** for context.
  ///
  /// ```dart
  /// final blueprint = await Colossus.instance.getAiBlueprint();
  /// // Send blueprint to AI with prompt
  /// ```
  Future<Map<String, dynamic>> getAiBlueprint() async {
    final baseContext = await getAiContext();

    return {
      ...baseContext,
      'terrain': terrain.toJson(),
      'terrainMap': terrain.toAiMap(),
      'terrainMermaid': terrain.toMermaid(),
      'campaignTemplate': Campaign.templateDescription,
      'gauntletCatalog': Gauntlet.catalog.map((p) => p.toJson()).toList(),
      'discoveredScreens': terrain.outposts.values
          .map((o) => o.toAiSummary())
          .toList(),
      'authProtectedRoutes': terrain.authProtectedScreens
          .map((o) => o.routePattern)
          .toList(),
      'publicRoutes': terrain.publicScreens.map((o) => o.routePattern).toList(),
      'deadEnds': terrain.deadEnds.map((o) => o.routePattern).toList(),
      'unreliableTransitions': terrain.unreliableMarches
          .map(
            (m) => {
              'from': m.fromRoute,
              'to': m.toRoute,
              'observations': m.observationCount,
            },
          )
          .toList(),
    };
  }
}

// ---------------------------------------------------------------------------
// VesselConfig — Memory monitoring configuration
// ---------------------------------------------------------------------------

/// Configuration for the [Vessel] memory monitor.
///
/// ```dart
/// Colossus.init(
///   vesselConfig: VesselConfig(
///     leakThreshold: Duration(minutes: 3),
///     exemptTypes: {'AuthPillar', 'AppPillar'},
///   ),
/// );
/// ```
class VesselConfig {
  /// How often to check for leaks.
  final Duration checkInterval;

  /// How long a Pillar must live before it becomes a leak suspect.
  final Duration leakThreshold;

  /// Pillar type names exempt from leak detection.
  final Set<String> exemptTypes;

  /// Creates a [VesselConfig].
  const VesselConfig({
    this.checkInterval = const Duration(seconds: 10),
    this.leakThreshold = const Duration(minutes: 5),
    this.exemptTypes = const {},
  });
}

// ---------------------------------------------------------------------------
// _ColossusRelayHandler — Bridges Relay HTTP to Colossus
// ---------------------------------------------------------------------------

/// Implements [RelayHandler] by delegating to the [Colossus] instance.
///
/// This decouples Relay's HTTP layer from Colossus internals.
/// All method calls are dispatched on the main isolate (same
/// event loop as Flutter's UI), which is required for
/// `StratagemRunner` to synthesize pointer events.
class _ColossusRelayHandler implements RelayHandler {
  final Colossus _colossus;

  _ColossusRelayHandler(this._colossus);

  @override
  Future<Map<String, dynamic>> executeCampaign(
    Map<String, dynamic> json,
  ) async {
    final result = await _colossus.executeCampaignJson(json);
    return {
      'campaign': result.campaign.name,
      'passRate': result.passRate,
      'totalExecuted': result.totalExecuted,
      'totalFailed': result.totalFailed,
      'totalSkipped': result.skipped.length,
      'report': result.toReport(),
      'aiDiagnostic': result.toAiDiagnostic(),
      'verdicts': result.verdicts.entries
          .map(
            (e) => {
              'stratagem': e.key,
              'passed': e.value.passed,
              'summary': e.value.summary.toJson(),
            },
          )
          .toList(),
    };
  }

  @override
  Map<String, dynamic> getTerrain() => _colossus.terrain.toJson();

  @override
  Future<Map<String, dynamic>> getBlueprint() => _colossus.getAiBlueprint();

  @override
  Map<String, dynamic> debriefVerdicts(List<Map<String, dynamic>> verdicts) {
    final parsedVerdicts = verdicts.map((v) => Verdict.fromJson(v)).toList();

    final report = _colossus.debrief(parsedVerdicts);
    return {
      'totalVerdicts': report.totalVerdicts,
      'passedVerdicts': report.passedVerdicts,
      'failedVerdicts': report.failedVerdicts,
      'insights': report.insights.map((i) => i.toJson()).toList(),
      'suggestedNextActions': report.suggestedNextActions,
      'aiSummary': report.toAiSummary(),
    };
  }

  @override
  Map<String, dynamic> getPerformanceReport() => _colossus.decree().toMap();

  @override
  Map<String, dynamic> getFrameHistory() => {
    'totalFrames': _colossus.pulse.totalFrames,
    'maxHistory': 300,
    'frames': _colossus.pulse.history.map((f) => f.toMap()).toList(),
  };

  @override
  Map<String, dynamic> getPageLoads() => {
    'totalPageLoads': _colossus.stride.history.length,
    'avgPageLoadMs': _colossus.stride.avgPageLoad.inMilliseconds,
    'pageLoads': _colossus.stride.history.map((p) => p.toMap()).toList(),
  };

  @override
  Map<String, dynamic> getMemorySnapshot() {
    final snapshot = _colossus.vessel.snapshot();
    return {
      ...snapshot.toMap(),
      'leakSuspects': _colossus.vessel.leakSuspects
          .map((s) => s.toMap())
          .toList(),
      'exemptTypes': _colossus.vessel.exemptTypes.toList(),
    };
  }

  @override
  Map<String, dynamic> getAlerts() => {
    'totalAlerts': _colossus.alertHistory.length,
    'maxHistory': Colossus._maxAlertHistory,
    'alerts': _colossus.alertHistory.map((a) => a.toMap()).toList(),
  };

  @override
  Future<Map<String, dynamic>> listSessions() async {
    final vault = _colossus.vault;
    if (vault == null) {
      return {
        'configured': false,
        'sessions': <Map<String, dynamic>>[],
        'message':
            'ShadeVault not configured. Pass shadeStoragePath '
            'to Colossus.init() or ColossusPlugin.',
      };
    }

    final summaries = await vault.list();
    return {
      'configured': true,
      'totalSessions': summaries.length,
      'sessions': summaries.map((s) => s.toMap()).toList(),
    };
  }

  @override
  Map<String, dynamic> getRecordingStatus() => {
    'isRecording': _colossus.shade.isRecording,
    'isReplaying': _colossus.shade.isReplaying,
    'currentEventCount': _colossus.shade.currentEventCount,
    'elapsedMs': _colossus.shade.elapsed.inMilliseconds,
    'isPerfRecording': _colossus.isPerfRecording,
    'hasLastSession': _colossus.lastRecordedSession != null,
  };

  @override
  Map<String, dynamic> getFrameworkErrors() => {
    'errors': _colossus.frameworkErrors.map((e) => e.toMap()).toList(),
    'total': _colossus.frameworkErrors.length,
    'byCategory': {
      for (final cat in FrameworkErrorCategory.values)
        cat.name: _colossus.frameworkErrors
            .where((e) => e.category == cat)
            .length,
    },
  };

  @override
  Map<String, dynamic> startRecording({String? name, String? description}) {
    if (_colossus.shade.isRecording) {
      return {
        'success': false,
        'error': 'Already recording',
        'currentEventCount': _colossus.shade.currentEventCount,
        'elapsedMs': _colossus.shade.elapsed.inMilliseconds,
      };
    }

    _colossus.shade.startRecording(name: name, description: description);
    return {'success': true, 'name': name ?? 'session', 'isRecording': true};
  }

  @override
  Map<String, dynamic> stopRecording() {
    if (!_colossus.shade.isRecording) {
      return {'success': false, 'error': 'Not currently recording'};
    }

    final session = _colossus.shade.stopRecording();

    // Feed session to Scout for terrain analysis.
    _colossus.scout.analyzeSession(session);

    return {
      'success': true,
      'sessionId': session.id,
      'name': session.name,
      'eventCount': session.eventCount,
      'durationMs': session.duration.inMilliseconds,
      'description': session.description,
    };
  }

  @override
  Future<Map<String, dynamic>> exportBlueprint({String? directory}) async {
    final dir = directory ?? '.titan';

    final export = BlueprintExport.fromScout(scout: _colossus.scout);

    final result = await BlueprintExportIO.saveAll(export, directory: dir);

    return {
      'success': true,
      'jsonPath': result.json,
      'promptPath': result.prompt,
      'terrainSummary': {
        'screens': export.terrain.outposts.length,
        'transitions': export.terrain.marches.length,
      },
      'stratagemCount': export.stratagems.length,
    };
  }

  @override
  Map<String, dynamic> getBlueprintData() {
    final export = BlueprintExport.fromScout(scout: _colossus.scout);
    return {
      'blueprint': export.toJson(),
      'prompt': export.toAiPrompt(),
      'terrainSummary': {
        'screens': export.terrain.outposts.length,
        'transitions': export.terrain.marches.length,
      },
      'stratagemCount': export.stratagems.length,
    };
  }

  @override
  Map<String, dynamic> getApiMetrics() {
    final metrics = _colossus.apiMetrics;
    final successful = metrics.where((m) => m['success'] == true).length;
    final failed = metrics.length - successful;

    // Compute durations list
    final durations = metrics
        .map((m) => ((m['durationMs'] as num?) ?? 0).toDouble())
        .toList();

    final avgDuration = durations.isEmpty
        ? 0.0
        : durations.fold<double>(0, (a, b) => a + b) / durations.length;

    // Percentiles
    final p50 = _percentile(durations, 50);
    final p95 = _percentile(durations, 95);
    final p99 = _percentile(durations, 99);

    // Success rate
    final successRate = metrics.isEmpty
        ? 100.0
        : (successful / metrics.length) * 100;

    // Endpoint grouping
    final byEndpoint = _groupByEndpoint(metrics);

    return {
      'totalMetrics': metrics.length,
      'successful': successful,
      'failed': failed,
      'successRate': double.parse(successRate.toStringAsFixed(1)),
      'avgDurationMs': avgDuration.round(),
      'p50Ms': p50.round(),
      'p95Ms': p95.round(),
      'p99Ms': p99.round(),
      'maxStored': Colossus._maxApiMetrics,
      'byEndpoint': byEndpoint,
      'metrics': metrics,
    };
  }

  /// Compute the [percentile]-th percentile from a list of values.
  ///
  /// Returns 0 for an empty list.
  static double _percentile(List<double> values, int percentile) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final index = ((percentile / 100) * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Group API metrics by endpoint pattern and compute per-group stats.
  static List<Map<String, dynamic>> _groupByEndpoint(
    List<Map<String, dynamic>> metrics,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final m in metrics) {
      final url = (m['url'] as String?) ?? '';
      final pattern = _normalizeEndpoint(url);
      (groups[pattern] ??= []).add(m);
    }

    final result = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final groupMetrics = entry.value;
      final groupDurations = groupMetrics
          .map((m) => ((m['durationMs'] as num?) ?? 0).toDouble())
          .toList();
      final groupSuccessful = groupMetrics
          .where((m) => m['success'] == true)
          .length;
      final errorRate = groupMetrics.isEmpty
          ? 0.0
          : ((groupMetrics.length - groupSuccessful) / groupMetrics.length) *
                100;
      final avgMs = groupDurations.isEmpty
          ? 0.0
          : groupDurations.fold<double>(0, (a, b) => a + b) /
                groupDurations.length;

      result.add({
        'pattern': entry.key,
        'count': groupMetrics.length,
        'avgMs': avgMs.round(),
        'p95Ms': _percentile(groupDurations, 95).round(),
        'errorRate': double.parse(errorRate.toStringAsFixed(1)),
      });
    }

    // Sort by count descending
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return result;
  }

  /// Normalize a URL into an endpoint pattern by replacing numeric
  /// path segments and UUIDs with `:id`.
  static String _normalizeEndpoint(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.map((s) {
        // Replace UUIDs
        if (RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
          r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(s)) {
          return ':id';
        }
        // Replace pure numeric segments
        if (RegExp(r'^\d+$').hasMatch(s)) {
          return ':id';
        }
        return s;
      });
      return '/${segments.join('/')}';
    } catch (_) {
      return url;
    }
  }

  @override
  Map<String, dynamic> getApiErrors() {
    final errors = _colossus.apiMetrics
        .where((m) => m['success'] != true)
        .toList();

    return {'totalErrors': errors.length, 'errors': errors};
  }

  @override
  Map<String, dynamic> getTremors() {
    final tremors = _colossus.tremors;
    return {
      'count': tremors.length,
      'tremors': tremors
          .map(
            (t) => {
              'name': t.name,
              'category': t.category.name,
              'severity': t.severity.name,
              'once': t.once,
            },
          )
          .toList(),
      'alertHistoryCount': _colossus.alertHistory.length,
    };
  }

  @override
  Map<String, dynamic> addTremor(Map<String, dynamic> config) {
    final type = config['type'] as String?;
    if (type == null) {
      return {'success': false, 'error': 'Missing required "type" field'};
    }

    final severity = _parseSeverity(config['severity'] as String?);
    final once = config['once'] as bool? ?? false;

    Tremor tremor;
    try {
      tremor = switch (type) {
        'fps' => Tremor.fps(
          threshold: (config['threshold'] as num?)?.toDouble() ?? 50,
          severity: severity,
          once: once,
        ),
        'jankRate' => Tremor.jankRate(
          threshold: (config['threshold'] as num?)?.toDouble() ?? 5,
          severity: severity,
          once: once,
        ),
        'pageLoad' => Tremor.pageLoad(
          threshold: Duration(
            milliseconds: (config['thresholdMs'] as num?)?.toInt() ?? 1000,
          ),
          severity: severity,
          once: once,
        ),
        'memory' => Tremor.memory(
          maxPillars: (config['maxPillars'] as num?)?.toInt() ?? 50,
          severity: severity,
          once: once,
        ),
        'rebuilds' => Tremor.rebuilds(
          threshold: (config['threshold'] as num?)?.toInt() ?? 100,
          widget: config['widget'] as String? ?? '',
          severity: severity,
          once: once,
        ),
        'leaks' => Tremor.leaks(severity: severity, once: once),
        'apiLatency' => Tremor.apiLatency(
          threshold: Duration(
            milliseconds: (config['thresholdMs'] as num?)?.toInt() ?? 500,
          ),
          severity: severity,
          once: once,
        ),
        'apiErrorRate' => Tremor.apiErrorRate(
          threshold: (config['threshold'] as num?)?.toDouble() ?? 10,
          severity: severity,
          once: once,
        ),
        _ => throw ArgumentError('Unknown tremor type: $type'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }

    _colossus.addTremor(tremor);
    return {
      'success': true,
      'tremor': {
        'name': tremor.name,
        'category': tremor.category.name,
        'severity': tremor.severity.name,
        'once': tremor.once,
      },
      'totalTremors': _colossus.tremors.length,
    };
  }

  @override
  Map<String, dynamic> removeTremor(String name) {
    final removed = _colossus.removeTremor(name);
    return {
      'success': removed,
      'name': name,
      'totalTremors': _colossus.tremors.length,
    };
  }

  @override
  Map<String, dynamic> resetTremors({bool clearHistory = false}) {
    _colossus.resetTremors();
    if (clearHistory) {
      _colossus.clearAlertHistory();
    }
    return {
      'success': true,
      'tremorsReset': _colossus.tremors.length,
      'historyCleared': clearHistory,
      'alertHistoryCount': _colossus.alertHistory.length,
    };
  }

  static TremorSeverity _parseSeverity(String? value) {
    return switch (value) {
      'info' => TremorSeverity.info,
      'error' => TremorSeverity.error,
      _ => TremorSeverity.warning,
    };
  }

  @override
  Future<Map<String, dynamic>> reloadPage({bool fullRebuild = false}) {
    return _colossus.reloadPage(fullRebuild: fullRebuild);
  }

  @override
  Map<String, dynamic> getWidgetTree() {
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) {
      return {'success': false, 'error': 'No root element available'};
    }

    var totalElements = 0;
    var maxDepth = 0;
    final typeCounts = <String, int>{};
    var hasText = false;
    var hasTextField = false;
    var hasButton = false;

    void walk(Element element, int depth) {
      if (totalElements > 2000) return; // Safety limit
      totalElements++;
      if (depth > maxDepth) maxDepth = depth;

      final typeName = element.widget.runtimeType.toString();
      typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;

      if (typeName == 'Text') hasText = true;
      if (typeName == 'TextField' || typeName == 'TextFormField') {
        hasTextField = true;
      }
      if (typeName.contains('Button')) hasButton = true;

      element.visitChildren((child) => walk(child, depth + 1));
    }

    walk(rootElement, 0);

    final sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'success': true,
      'totalElements': totalElements,
      'maxDepth': maxDepth,
      'uniqueWidgetTypes': typeCounts.length,
      'hasText': hasText,
      'hasTextField': hasTextField,
      'hasButton': hasButton,
      'top20WidgetTypes': sortedTypes
          .take(20)
          .map((e) => '${e.key}: ${e.value}')
          .toList(),
    };
  }

  @override
  Map<String, dynamic> getEvents({String? source}) {
    final events = _colossus.events;
    final filtered = source != null
        ? events.where((e) => e['source'] == source).toList()
        : events.toList();

    // Group by source for summary
    final bySrc = <String, int>{};
    for (final e in filtered) {
      final s = (e['source'] as String?) ?? 'unknown';
      bySrc[s] = (bySrc[s] ?? 0) + 1;
    }

    return {
      'count': filtered.length,
      'totalEvents': events.length,
      'filter': source,
      'bySource': bySrc,
      'events': filtered.length > 100
          ? filtered.sublist(filtered.length - 100)
          : filtered,
    };
  }

  @override
  Future<Map<String, dynamic>> replaySession(
    String sessionId, {
    double speedMultiplier = 1.0,
  }) async {
    final session = await _colossus.loadSession(sessionId);
    if (session == null) {
      return {
        'success': false,
        'error': 'Session "$sessionId" not found in ShadeVault',
      };
    }

    try {
      final result = await _colossus.replaySession(
        session,
        speedMultiplier: speedMultiplier,
      );
      return {
        'success': true,
        'sessionId': sessionId,
        'sessionName': session.name,
        'eventsDispatched': result.eventsDispatched,
        'totalEvents': result.totalEvents,
        'durationMs': result.actualDuration.inMilliseconds,
        'wasCancelled': result.wasCancelled,
        'routeChanged': result.routeChanged,
        'invalidRoute': result.invalidRoute,
      };
    } catch (e) {
      return {'success': false, 'sessionId': sessionId, 'error': e.toString()};
    }
  }

  @override
  Map<String, dynamic> getRouteHistory() {
    return _colossus.getRouteHistory();
  }

  @override
  Future<Map<String, dynamic>> captureScreenshot({double pixelRatio = 0.5}) {
    return _colossus.captureScreenshot(pixelRatio: pixelRatio);
  }

  @override
  Map<String, dynamic> auditAccessibility() {
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) {
      return {'success': false, 'error': 'No root element available'};
    }

    final issues = <Map<String, dynamic>>[];
    var totalElements = 0;
    var interactiveCount = 0;
    var withLabels = 0;
    var withRoles = 0;
    var touchTargetViolations = 0;

    void walk(Element element) {
      if (totalElements > 2000) return; // Safety limit
      totalElements++;

      final widget = element.widget;
      final typeName = widget.runtimeType.toString();

      // Check if interactive
      final isInteractive =
          typeName.contains('Button') ||
          typeName == 'GestureDetector' ||
          typeName == 'InkWell' ||
          typeName == 'InkResponse' ||
          typeName == 'IconButton' ||
          typeName == 'TextButton' ||
          typeName == 'ElevatedButton' ||
          typeName == 'OutlinedButton' ||
          typeName == 'FloatingActionButton' ||
          typeName == 'TextField' ||
          typeName == 'TextFormField' ||
          typeName == 'Checkbox' ||
          typeName == 'Switch' ||
          typeName == 'Radio' ||
          typeName == 'Slider' ||
          typeName == 'DropdownButton' ||
          typeName == 'PopupMenuButton';

      if (isInteractive) {
        interactiveCount++;

        // Check for semantic label via ancestor Semantics widget
        String? semanticLabel;
        String? semanticRole;
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget.runtimeType.toString() == 'Semantics') {
            try {
              // ignore: avoid_dynamic_calls
              final props = (ancestor.widget as dynamic).properties;
              if (props != null) {
                // ignore: avoid_dynamic_calls
                final label = props.label as String?;
                if (label != null && label.isNotEmpty) {
                  semanticLabel = label;
                }
                // ignore: avoid_dynamic_calls
                if (props.button == true) semanticRole = 'button';
                // ignore: avoid_dynamic_calls
                if (props.textField == true) semanticRole = 'textField';
                // ignore: avoid_dynamic_calls
                if (props.header == true) semanticRole = 'header';
              }
            } catch (_) {
              // Semantics access not available — skip
            }
            return false; // Stop walking
          }
          return true;
        });

        if (semanticLabel != null) withLabels++;
        if (semanticRole != null) withRoles++;

        // Check for missing semantic label
        if (semanticLabel == null) {
          issues.add({
            'type': 'missing_label',
            'severity': 'warning',
            'widget': typeName,
            'message':
                '$typeName is interactive but has no Semantics label. '
                'Wrap with Semantics(label: ...) for screen reader support.',
          });
        }

        // Check touch target size
        final renderObject = element.renderObject;
        if (renderObject != null && renderObject.paintBounds.isFinite) {
          final bounds = renderObject.paintBounds;
          final width = bounds.width;
          final height = bounds.height;
          if (width < 48 || height < 48) {
            touchTargetViolations++;
            issues.add({
              'type': 'small_touch_target',
              'severity': 'warning',
              'widget': typeName,
              'size':
                  '${width.toStringAsFixed(1)}×${height.toStringAsFixed(1)}',
              'message':
                  '$typeName has touch target '
                  '${width.toStringAsFixed(1)}×${height.toStringAsFixed(1)} dp. '
                  'Minimum recommended is 48×48 dp.',
            });
          }
        }
      }

      element.visitChildren(walk);
    }

    walk(rootElement);

    return {
      'success': true,
      'summary': {
        'totalElements': totalElements,
        'interactiveElements': interactiveCount,
        'withLabels': withLabels,
        'withRoles': withRoles,
        'touchTargetViolations': touchTargetViolations,
        'issueCount': issues.length,
      },
      'issues': issues.length > 50 ? issues.sublist(0, 50) : issues,
    };
  }

  @override
  Map<String, dynamic> inspectDi() {
    final registeredTypes = Titan.registeredTypes;
    final instances = Titan.instances;
    // Compute lazy types from public API: registered but not yet instantiated.
    final lazyTypes = registeredTypes.difference(instances.keys.toSet());

    final entries = <Map<String, dynamic>>[];

    for (final type in registeredTypes) {
      final isInstantiated = instances.containsKey(type);
      final isLazy = lazyTypes.contains(type);
      final instance = isInstantiated ? instances[type] : null;
      final isPillar = instance is Pillar;

      entries.add({
        'type': type.toString(),
        'instantiated': isInstantiated,
        'lazy': isLazy,
        'isPillar': isPillar,
        if (isPillar) 'disposed': instance.isDisposed,
      });
    }

    return {
      'success': true,
      'registeredCount': registeredTypes.length,
      'instantiatedCount': instances.length,
      'lazyCount': lazyTypes.length,
      'pillarCount': entries.where((e) => e['isPillar'] == true).length,
      'entries': entries,
    };
  }

  @override
  Map<String, dynamic> inspectEnvoy() {
    final envoy = Titan.find<Envoy>();
    if (envoy == null) {
      return {
        'success': false,
        'error':
            'No Envoy instance registered in Titan DI. '
            'Register with Titan.put(Envoy(baseUrl: ...)).',
      };
    }

    final couriers = <Map<String, dynamic>>[];
    for (var i = 0; i < envoy.couriers.length; i++) {
      couriers.add(_serializeCourier(envoy.couriers[i], i));
    }

    return {
      'success': true,
      'baseUrl': envoy.baseUrl,
      'connectTimeout': envoy.connectTimeout?.inMilliseconds,
      'sendTimeout': envoy.sendTimeout?.inMilliseconds,
      'receiveTimeout': envoy.receiveTimeout?.inMilliseconds,
      'followRedirects': envoy.followRedirects,
      'maxRedirects': envoy.maxRedirects,
      'defaultHeaders': envoy.defaultHeaders,
      'courierCount': envoy.couriers.length,
      'couriers': couriers,
    };
  }

  /// Serialize a [Courier] to a JSON-friendly map based on its runtime type.
  Map<String, dynamic> _serializeCourier(Courier courier, int index) {
    final type = courier.runtimeType.toString();
    final config = <String, dynamic>{};

    switch (courier) {
      case LogCourier c:
        config['logHeaders'] = c.logHeaders;
        config['logBody'] = c.logBody;
        config['logErrors'] = c.logErrors;
      case RetryCourier c:
        config['maxRetries'] = c.maxRetries;
        config['retryDelayMs'] = c.retryDelay.inMilliseconds;
        config['backoffMultiplier'] = c.backoffMultiplier;
        config['maxDelayMs'] = c.maxDelay.inMilliseconds;
        config['addJitter'] = c.addJitter;
        config['retryOn'] = c.retryOn.toList()..sort();
        config['retryOnTimeout'] = c.retryOnTimeout;
        config['retryOnConnectionError'] = c.retryOnConnectionError;
        config['hasCustomShouldRetry'] = c.shouldRetry != null;
      case AuthCourier c:
        config['headerName'] = c.headerName;
        config['tokenPrefix'] = c.tokenPrefix;
        config['maxRefreshAttempts'] = c.maxRefreshAttempts;
        config['hasOnUnauthorized'] = c.onUnauthorized != null;
      case CacheCourier c:
        config['strategy'] = c.defaultPolicy.strategy.name;
        config['ttlMs'] = c.defaultPolicy.ttl?.inMilliseconds;
        config['cacheableMethods'] = c.cacheableMethods
            .map((m) => m.name)
            .toList();
      case MetricsCourier _:
        config['note'] = 'Forwards metrics via onMetric callback';
      case DedupCourier c:
        config['ttlMs'] = c.ttl.inMilliseconds;
        config['inFlightCount'] = c.inFlightCount;
      case CookieCourier c:
        config['persistCookies'] = c.persistCookies;
        config['cookieCount'] = c.cookieCount;
      default:
        config['note'] = 'Custom courier — no detailed config available';
    }

    return {'type': type, 'index': index, 'config': config};
  }

  @override
  Map<String, dynamic> configureEnvoy(Map<String, dynamic> config) {
    final envoy = Titan.find<Envoy>();
    if (envoy == null) {
      return {
        'success': false,
        'error':
            'No Envoy instance registered in Titan DI. '
            'Register with Titan.put(Envoy(baseUrl: ...)).',
      };
    }

    final changes = <String>[];

    // -- Base URL --
    if (config.containsKey('baseUrl')) {
      final old = envoy.baseUrl;
      envoy.baseUrl = config['baseUrl'] as String;
      changes.add('baseUrl: $old → ${envoy.baseUrl}');
    }

    // -- Timeouts --
    if (config.containsKey('connectTimeout')) {
      envoy.connectTimeout = Duration(
        milliseconds: config['connectTimeout'] as int,
      );
      changes.add('connectTimeout: ${envoy.connectTimeout!.inMilliseconds} ms');
    }
    if (config.containsKey('sendTimeout')) {
      envoy.sendTimeout = Duration(milliseconds: config['sendTimeout'] as int);
      changes.add('sendTimeout: ${envoy.sendTimeout!.inMilliseconds} ms');
    }
    if (config.containsKey('receiveTimeout')) {
      envoy.receiveTimeout = Duration(
        milliseconds: config['receiveTimeout'] as int,
      );
      changes.add('receiveTimeout: ${envoy.receiveTimeout!.inMilliseconds} ms');
    }

    // -- Redirects --
    if (config.containsKey('followRedirects')) {
      envoy.followRedirects = config['followRedirects'] as bool;
      changes.add('followRedirects: ${envoy.followRedirects}');
    }
    if (config.containsKey('maxRedirects')) {
      envoy.maxRedirects = config['maxRedirects'] as int;
      changes.add('maxRedirects: ${envoy.maxRedirects}');
    }

    // -- Headers --
    if (config.containsKey('setHeaders')) {
      final headers = config['setHeaders'] as Map<String, dynamic>;
      for (final entry in headers.entries) {
        envoy.defaultHeaders[entry.key] = entry.value.toString();
      }
      changes.add('setHeaders: ${headers.keys.join(', ')}');
    }
    if (config.containsKey('removeHeaders')) {
      final keys = (config['removeHeaders'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      for (final key in keys) {
        envoy.defaultHeaders.remove(key);
      }
      changes.add('removeHeaders: ${keys.join(', ')}');
    }

    // -- Clear couriers --
    if (config['clearCouriers'] == true) {
      final count = envoy.couriers.length;
      envoy.clearCouriers();
      changes.add('clearCouriers: removed $count couriers');
    }

    // -- Remove courier by index (before adding) --
    if (config.containsKey('removeCourierAt')) {
      final index = config['removeCourierAt'] as int;
      if (index >= 0 && index < envoy.couriers.length) {
        final removed = envoy.couriers[index];
        envoy.removeCourier(removed);
        changes.add('removeCourierAt[$index]: ${removed.runtimeType}');
      } else {
        changes.add(
          'removeCourierAt[$index]: SKIPPED — '
          'out of range (0..${envoy.couriers.length - 1})',
        );
      }
    }

    // -- Add courier by type name --
    if (config.containsKey('addCourier')) {
      final typeName = config['addCourier'] as String;
      final courier = _createCourier(typeName);
      if (courier != null) {
        envoy.addCourier(courier);
        changes.add(
          'addCourier: $typeName (at index ${envoy.couriers.length - 1})',
        );
      } else {
        changes.add(
          'addCourier: $typeName — FAILED (unsupported or requires '
          'configuration; supported defaults: LogCourier, RetryCourier, '
          'DedupCourier, CookieCourier)',
        );
      }
    }

    return {
      'success': true,
      'changesApplied': changes.length,
      'changes': changes,
      'currentState': inspectEnvoy(),
    };
  }

  /// Create a default [Courier] instance by type name.
  ///
  /// Only couriers with all-optional constructor parameters can be created:
  /// [LogCourier], [RetryCourier], [DedupCourier], [CookieCourier].
  /// Returns `null` for types that require configuration (AuthCourier,
  /// CacheCourier, MetricsCourier) or unknown types.
  Courier? _createCourier(String typeName) {
    return switch (typeName) {
      'LogCourier' => LogCourier(),
      'RetryCourier' => RetryCourier(),
      'DedupCourier' => DedupCourier(),
      'CookieCourier' => CookieCourier(),
      _ => null,
    };
  }
}
