/// **Relay** — Platform-agnostic campaign execution bridge.
///
/// This file defines the [Relay] interface and [RelayConfig].
/// The actual implementation is provided by conditional imports:
/// - `relay_io.dart` for non-web platforms (dart:io HttpServer)
/// - `relay_stub.dart` for web (graceful no-op)
///
/// See [RelayConfig] for configuration options.
library;

import 'dart:async';

import 'relay_io.dart' if (dart.library.html) 'relay_stub.dart' as platform;

// ---------------------------------------------------------------------------
// RelayConfig — Configuration
// ---------------------------------------------------------------------------

/// Configuration for the [Relay] HTTP bridge.
///
/// ```dart
/// const config = RelayConfig(
///   port: 8642,
///   host: '0.0.0.0',
///   authToken: 'my-secret-token',
/// );
/// ```
class RelayConfig {
  /// TCP port to listen on.
  ///
  /// Defaults to `8642`. Choose a port that doesn't conflict with
  /// other services on the target platform.
  final int port;

  /// Network interface to bind to.
  ///
  /// - `'0.0.0.0'` — all interfaces (reachable from other devices)
  /// - `'127.0.0.1'` — localhost only (desktop/emulator testing)
  ///
  /// Defaults to `'0.0.0.0'` for maximum reach (mobile device testing).
  final String host;

  /// Bearer token for request authentication.
  ///
  /// When non-null, every request (except `GET /health`) must include
  /// `Authorization: Bearer <token>`. Requests without a valid token
  /// receive HTTP 401.
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

  /// Creates a [RelayConfig].
  const RelayConfig({
    this.port = 8642,
    this.host = '0.0.0.0',
    this.authToken,
    this.requestTimeout = const Duration(minutes: 10),
    this.enableLogging = true,
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
}

// ---------------------------------------------------------------------------
// Relay — Public API
// ---------------------------------------------------------------------------

/// **Relay** — Embedded HTTP server for AI-driven campaign execution.
///
/// Relay is a cross-platform HTTP bridge that runs inside the Flutter
/// app. It exposes endpoints for AI assistants to execute Campaigns,
/// query Terrain, and retrieve Debrief reports — enabling fully
/// automated testing without human interaction.
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
/// On web, `start()` completes immediately as a no-op (browsers
/// cannot host HTTP servers).
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
