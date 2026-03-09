import 'dart:convert';

import 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        FlutterError,
        FlutterErrorDetails,
        FlutterExceptionHandler;
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:titan_atlas/titan_atlas.dart' show Atlas;
import 'package:titan_bastion/titan_bastion.dart';

import 'alerts/tremor.dart';
import 'framework_error.dart';
import 'integration/lens.dart';
import 'export/inscribe.dart';
import 'integration/blueprint_lens_tab.dart';
import 'integration/bridge_lens_tab.dart';
import 'integration/colossus_lens_tab.dart';
import 'integration/shade_lens_tab.dart';
import 'metrics/decree.dart';
import 'metrics/mark.dart';
import 'monitors/pulse.dart';
import 'monitors/stride.dart';
import 'monitors/vessel.dart';
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
  }) : _tremors = tremors,
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

    final context = TremorContext(
      fps: pulse.fps,
      jankRate: pulse.jankRate,
      pillarCount: vessel.pillarCount,
      leakSuspects: vessel.leakSuspects,
      lastPageLoad: stride.lastPageLoad,
      rebuildsPerWidget: _rebuildsPerWidget,
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
    final avgDuration = metrics.isEmpty
        ? 0
        : metrics
                  .map((m) => (m['durationMs'] as num?) ?? 0)
                  .fold<num>(0, (a, b) => a + b) /
              metrics.length;

    return {
      'totalMetrics': metrics.length,
      'successful': successful,
      'failed': failed,
      'avgDurationMs': avgDuration.round(),
      'maxStored': Colossus._maxApiMetrics,
      'metrics': metrics,
    };
  }

  @override
  Map<String, dynamic> getApiErrors() {
    final errors = _colossus.apiMetrics
        .where((m) => m['success'] != true)
        .toList();

    return {'totalErrors': errors.length, 'errors': errors};
  }
}
