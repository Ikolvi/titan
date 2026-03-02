import 'package:flutter/scheduler.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'alerts/tremor.dart';
import 'export/inscribe.dart';
import 'integration/colossus_lens_tab.dart';
import 'integration/shade_lens_tab.dart';
import 'metrics/decree.dart';
import 'metrics/mark.dart';
import 'monitors/pulse.dart';
import 'monitors/stride.dart';
import 'monitors/vessel.dart';
import 'recording/imprint.dart';
import 'recording/phantom.dart';
import 'recording/shade.dart';
import 'recording/shade_vault.dart';
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
    assert(_instance != null, 'Colossus.init() must be called first.');
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

  // -----------------------------------------------------------------------
  // State
  // -----------------------------------------------------------------------

  final Map<String, int> _rebuildsPerWidget = {};
  final DateTime _sessionStart = DateTime.now();
  Chronicle? _chronicle;
  ColossusLensTab? _lensTab;
  ShadeLensTab? _shadeLensTab;

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
  // Performance recording state (survives Lens close/reopen)
  // -----------------------------------------------------------------------

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
  }) : _tremors = tremors,
       _enableLensTab = enableLensTab,
       _enableChronicle = enableChronicle;

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
    );

    if (shadeStoragePath != null) {
      colossus._vault = ShadeVault(shadeStoragePath);
    }

    if (exportDirectory != null) {
      colossus._exportDirectory = exportDirectory;
    }

    _instance = colossus;
    Titan.put(colossus);

    return colossus;
  }

  /// Shut down the Colossus monitor and clean up all resources.
  static void shutdown() {
    if (_instance != null) {
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
    }

    // Register Spark text controller factory so useTextController()
    // automatically creates ShadeTextControllers for text recording.
    // Performance: factory runs once per hook init (first build only);
    // ShadeTextController adds a single O(1) isRecording check per
    // text change — zero overhead when not recording.
    Spark.textControllerFactory = ({String? text, String? fieldId}) {
      return ShadeTextController(shade: shade, text: text, fieldId: fieldId);
    };
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

    _chronicle?.info('Colossus shut down');
    Spark.textControllerFactory = null;
    _instance = null;
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
