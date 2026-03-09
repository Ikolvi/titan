/// **Relay** — Platform-agnostic campaign execution bridge.
///
/// This file defines the [Relay] interface and [RelayConfig].
/// The actual implementation is provided by conditional imports:
/// - `relay_io.dart` for non-web platforms (dart:io HttpServer)
/// - `relay_web.dart` for web (WebSocket client connecting to MCP server)
///
/// See [RelayConfig] for configuration options.
library;

import 'dart:async';

import 'relay_io.dart' if (dart.library.html) 'relay_web.dart' as platform;

// ---------------------------------------------------------------------------
// RelayConfig — Configuration
// ---------------------------------------------------------------------------

/// Configuration for the [Relay] HTTP bridge.
///
/// On native platforms, Relay starts an HTTP server on [host]:[port].
/// On web, Relay connects as a WebSocket client to [targetUrl]
/// (typically the MCP server's `/relay` endpoint).
///
/// ```dart
/// // Native — starts HTTP server
/// const config = RelayConfig(
///   port: 8642,
///   host: '0.0.0.0',
///   authToken: 'my-secret-token',
/// );
///
/// // Web — connects to MCP server
/// const config = RelayConfig(
///   targetUrl: 'ws://localhost:8643/relay',
///   authToken: 'my-secret-token',
/// );
/// ```
class RelayConfig {
  /// TCP port to listen on (native only).
  ///
  /// Defaults to `8642`. Choose a port that doesn't conflict with
  /// other services on the target platform.
  /// Ignored on web — use [targetUrl] instead.
  final int port;

  /// Network interface to bind to (native only).
  ///
  /// - `'0.0.0.0'` — all interfaces (reachable from other devices)
  /// - `'127.0.0.1'` — localhost only (desktop/emulator testing)
  ///
  /// Defaults to `'0.0.0.0'` for maximum reach (mobile device testing).
  /// Ignored on web — use [targetUrl] instead.
  final String host;

  /// WebSocket URL to connect to (web only).
  ///
  /// On web, Relay acts as a WebSocket **client** connecting to
  /// the MCP server's `/relay` endpoint. The MCP server forwards
  /// tool commands over this WebSocket instead of using HTTP.
  ///
  /// Example: `'ws://localhost:8643/relay'`
  ///
  /// When null on web, Relay is silently disabled (same as the
  /// old stub behavior).
  /// Ignored on native — use [host] and [port] instead.
  final String? targetUrl;

  /// Bearer token for request authentication.
  ///
  /// When non-null, every request (except `GET /health`) must include
  /// `Authorization: Bearer <token>`. Requests without a valid token
  /// receive HTTP 401.
  ///
  /// On web, sent as a query parameter (`?token=<value>`) during the
  /// WebSocket handshake.
  ///
  /// When null, authentication is disabled (development convenience).
  final String? authToken;

  /// Request timeout for campaign execution.
  ///
  /// Campaigns involving many Stratagems may take several minutes.
  /// Defaults to 10 minutes.
  final Duration requestTimeout;

  /// Whether to log relay events to Chronicle.
  final bool enableLogging;

  /// Reconnect delay after WebSocket disconnection (web only).
  ///
  /// Defaults to 2 seconds. Uses exponential backoff up to 30 seconds.
  final Duration reconnectDelay;

  /// Creates a [RelayConfig].
  const RelayConfig({
    this.port = 8642,
    this.host = '0.0.0.0',
    this.targetUrl,
    this.authToken,
    this.requestTimeout = const Duration(minutes: 10),
    this.enableLogging = true,
    this.reconnectDelay = const Duration(seconds: 2),
  });
}

// ---------------------------------------------------------------------------
// RelayStatus — Runtime status
// ---------------------------------------------------------------------------

/// Runtime status of the [Relay] server.
class RelayStatus {
  /// Whether the server is currently running.
  final bool isRunning;

  /// The port the server is listening on (null if not running).
  final int? port;

  /// The host/interface the server is bound to.
  final String? host;

  /// Total number of requests handled since startup.
  final int requestsHandled;

  /// Total number of campaigns executed.
  final int campaignsExecuted;

  /// When the server was started (null if not running).
  final DateTime? startedAt;

  /// Creates a [RelayStatus].
  const RelayStatus({
    required this.isRunning,
    this.port,
    this.host,
    this.requestsHandled = 0,
    this.campaignsExecuted = 0,
    this.startedAt,
  });

  /// Serializes to JSON for the `/status` endpoint.
  Map<String, dynamic> toJson() => {
    'isRunning': isRunning,
    'port': port,
    'host': host,
    'requestsHandled': requestsHandled,
    'campaignsExecuted': campaignsExecuted,
    'startedAt': startedAt?.toIso8601String(),
    'version': '1.0.0',
  };
}

// ---------------------------------------------------------------------------
// RelayHandler — Callback interface
// ---------------------------------------------------------------------------

/// Callback interface for Relay to interact with Colossus.
///
/// Decouples the HTTP server from Colossus internals. Colossus
/// implements this interface and passes it to Relay on startup.
abstract interface class RelayHandler {
  /// Execute a Campaign from parsed JSON.
  ///
  /// Returns the campaign result as a JSON map.
  Future<Map<String, dynamic>> executeCampaign(Map<String, dynamic> json);

  /// Get the current Terrain as JSON.
  Map<String, dynamic> getTerrain();

  /// Get the full AI blueprint context.
  Future<Map<String, dynamic>> getBlueprint();

  /// Analyze verdicts and produce a debrief report.
  Map<String, dynamic> debriefVerdicts(List<Map<String, dynamic>> verdicts);

  /// Get a live performance report (Decree) as JSON.
  ///
  /// Returns the serialized [Decree] including Pulse, Stride,
  /// Vessel, and Echo metrics.
  Map<String, dynamic> getPerformanceReport();

  /// Get per-frame timing history from Pulse.
  ///
  /// Returns a list of [FrameMark] maps with build/raster durations,
  /// jank flags, and timestamps.
  Map<String, dynamic> getFrameHistory();

  /// Get individual page load records from Stride.
  ///
  /// Returns a list of [PageLoadMark] maps with paths, durations,
  /// and timestamps.
  Map<String, dynamic> getPageLoads();

  /// Get a live memory snapshot from Vessel.
  ///
  /// Returns Pillar counts, DI instances, and detailed leak
  /// suspects with ages.
  Map<String, dynamic> getMemorySnapshot();

  /// Get fired Tremor performance alerts.
  ///
  /// Returns the alert history with tremor names, severities,
  /// messages, and timestamps.
  Map<String, dynamic> getAlerts();

  /// List saved Shade recording sessions.
  ///
  /// Returns session summaries with IDs, names, durations,
  /// and event counts.
  Future<Map<String, dynamic>> listSessions();

  /// Get the current Shade recording/replaying status.
  ///
  /// Returns whether recording or replaying is active,
  /// the elapsed time, and event count.
  Map<String, dynamic> getRecordingStatus();

  /// Get captured Flutter framework errors.
  ///
  /// Returns overflow, build, layout, paint, and gesture errors
  /// intercepted from [FlutterError.onError] since initialization.
  Map<String, dynamic> getFrameworkErrors();

  /// Start a new Shade recording session.
  ///
  /// Returns confirmation with session name and status.
  /// Optionally accepts a [name] and [description] for the session.
  Map<String, dynamic> startRecording({String? name, String? description});

  /// Stop the current Shade recording and return session summary.
  ///
  /// Returns the session metadata (id, name, duration, event count).
  /// Throws [StateError] if not currently recording.
  Map<String, dynamic> stopRecording();

  /// Export the current Blueprint data to disk.
  ///
  /// Generates a [BlueprintExport] from the live Scout terrain
  /// and saves `blueprint.json` and `blueprint-prompt.md`.
  /// Returns the paths of the exported files.
  Future<Map<String, dynamic>> exportBlueprint({String? directory});

  /// Get the full Blueprint export data without writing to disk.
  ///
  /// Returns the complete `BlueprintExport.toJson()` plus the
  /// AI prompt text. Useful for MCP servers or external tools
  /// that handle file I/O outside the app sandbox.
  Map<String, dynamic> getBlueprintData();

  /// Get tracked API metrics from Envoy HTTP client.
  ///
  /// Returns a summary with total count, recent metrics, and optional
  /// filtering by success/failure. Populated via
  /// [Colossus.trackApiMetric].
  Map<String, dynamic> getApiMetrics();

  /// Get tracked API errors (non-successful requests).
  ///
  /// Returns only failed API calls for quick triage.
  Map<String, dynamic> getApiErrors();

  /// Get the currently configured Tremor thresholds.
  ///
  /// Returns tremor names, categories, severities, and fired states.
  Map<String, dynamic> getTremors();

  /// Add a new Tremor at runtime.
  ///
  /// [config] must include `type` (factory name) and type-specific
  /// parameters like `threshold`, `widget`, etc.
  /// Returns the resulting tremor configuration.
  Map<String, dynamic> addTremor(Map<String, dynamic> config);

  /// Remove a Tremor by name.
  ///
  /// Returns whether a tremor was found and removed.
  Map<String, dynamic> removeTremor(String name);

  /// Reset all Tremor fired states and optionally clear alert history.
  ///
  /// Returns the reset result.
  Map<String, dynamic> resetTremors({bool clearHistory = false});

  /// Reload the current page.
  ///
  /// When [fullRebuild] is `true`, triggers a full widget tree reassembly.
  /// Otherwise, re-navigates to the current route.
  Future<Map<String, dynamic>> reloadPage({bool fullRebuild = false});

  /// Get a summary of the widget tree (element count, types, depth).
  ///
  /// Returns statistical analysis of the current widget tree.
  Map<String, dynamic> getWidgetTree();

  /// Get integration events from Colossus bridges.
  ///
  /// Returns events from atlas, basalt, argus, bastion, and custom
  /// bridges. Optionally filter by [source].
  Map<String, dynamic> getEvents({String? source});

  /// Replay a saved Shade session by ID.
  ///
  /// Loads the session from the ShadeVault and replays it using
  /// Phantom. Returns the replay result.
  Future<Map<String, dynamic>> replaySession(
    String sessionId, {
    double speedMultiplier,
  });

  /// Get navigation route history from integration events.
  ///
  /// Returns atlas events in chronological order with current route.
  Map<String, dynamic> getRouteHistory();

  /// Capture a screenshot of the running Flutter app.
  ///
  /// Uses [Fresco] to capture a PNG image of the current screen.
  /// Returns base64-encoded PNG bytes. [pixelRatio] controls
  /// resolution (default 0.5).
  Future<Map<String, dynamic>> captureScreenshot({double pixelRatio});

  /// Audit the current screen for accessibility issues.
  ///
  /// Walks the widget tree and semantics data to detect:
  /// - Interactive elements missing semantic labels
  /// - Touch targets smaller than 48×48 dp
  /// - Missing semantic roles on interactive widgets
  /// Returns structured results with issue list and summary.
  Map<String, dynamic> auditAccessibility();

  /// Inspect the Titan DI container (Vault).
  ///
  /// Returns all registered types, which are instantiated vs lazy,
  /// and which are Pillar subclasses.
  Map<String, dynamic> inspectDi();

  /// Inspect the Envoy HTTP client configuration and couriers.
  ///
  /// Returns base URL, timeouts, headers, and a serialized list
  /// of active couriers with their per-type configuration.
  /// Looks up Envoy from [Titan] DI container.
  Map<String, dynamic> inspectEnvoy();

  /// Configure the Envoy HTTP client at runtime.
  ///
  /// Accepts a [config] map with optional keys:
  /// - `baseUrl` — set the base URL
  /// - `connectTimeout`, `sendTimeout`, `receiveTimeout` — set timeouts (ms)
  /// - `followRedirects`, `maxRedirects` — redirect settings
  /// - `setHeaders` — add/overwrite default headers
  /// - `removeHeaders` — remove default headers by name
  /// - `addCourier` — add a built-in courier by type name
  /// - `removeCourierAt` — remove a courier by chain index
  /// - `clearCouriers` — remove all couriers
  ///
  /// Returns a summary of applied changes and the resulting state.
  Map<String, dynamic> configureEnvoy(Map<String, dynamic> config);
}

// ---------------------------------------------------------------------------
// Relay — Public API
// ---------------------------------------------------------------------------

/// **Relay** — Embedded bridge for AI-driven campaign execution.
///
/// Relay is a cross-platform bridge that connects AI assistants
/// to the running Flutter app. It exposes endpoints for executing
/// Campaigns, querying Terrain, capturing screenshots, and more.
///
/// ## Quick Start
///
/// ```dart
/// final relay = Relay();
/// await relay.start(
///   config: RelayConfig(port: 8642),
///   handler: colossusHandler,
/// );
/// ```
///
/// ## Platform Behavior
///
/// On non-web platforms, starts a real `dart:io` `HttpServer`.
/// On web, connects to the MCP server's `/relay` WebSocket endpoint
/// as a client — reversing the connection direction since browsers
/// cannot host HTTP servers.
///
/// ## Security
///
/// Configure [RelayConfig.authToken] to require bearer authentication.
/// Without it, any process on the network can issue commands.
class Relay {
  final platform.RelayPlatform _platform = platform.RelayPlatform();

  /// Current status of the Relay server.
  RelayStatus get status => _platform.status;

  /// Whether the Relay server is currently running.
  bool get isRunning => _platform.status.isRunning;

  /// Start the Relay HTTP server.
  ///
  /// Binds to [config.host]:[config.port] and begins accepting
  /// requests. Uses [handler] to dispatch to Colossus.
  ///
  /// Returns immediately on web (no-op).
  ///
  /// ```dart
  /// await relay.start(
  ///   config: RelayConfig(port: 8642),
  ///   handler: colossusHandler,
  /// );
  /// ```
  Future<void> start({
    required RelayConfig config,
    required RelayHandler handler,
  }) => _platform.start(config: config, handler: handler);

  /// Stop the Relay HTTP server.
  ///
  /// Closes the server socket and rejects new connections.
  /// In-flight requests are allowed to complete.
  Future<void> stop() => _platform.stop();
}
