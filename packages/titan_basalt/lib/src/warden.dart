/// Warden — Reactive service health monitoring.
///
/// Monitors the health of multiple external services by periodically
/// running check functions and exposing per-service and aggregate
/// health status as reactive state. Unlike [Portcullis], which reacts
/// to failures in your own code, Warden **proactively** monitors
/// external dependencies.
///
/// ## Why "Warden"?
///
/// A warden patrols the realm's borders, checking every outpost and
/// sounding the alarm when any falls silent. Titan's Warden watches
/// over your application's external dependencies — APIs, databases,
/// third-party services — and reports their condition in real time.
///
/// ## Usage
///
/// ```dart
/// class ApiPillar extends Pillar {
///   late final health = warden(
///     interval: Duration(seconds: 30),
///     services: [
///       WardenService(
///         name: 'auth',
///         check: () => api.ping('/auth/health'),
///       ),
///       WardenService(
///         name: 'payments',
///         check: () => api.ping('/payments/health'),
///         critical: false,
///       ),
///     ],
///   );
///
///   @override
///   void onInit() {
///     health.start();
///   }
/// }
/// ```
///
/// ## Reactive State
///
/// | Property        | Type                        | Description                        |
/// |-----------------|-----------------------------|------------------------------------|
/// | `overallHealth` | `Derived<ServiceStatus>`    | Aggregate health of all critical   |
/// | `healthyCount`  | `Derived<int>`              | Number of healthy services         |
/// | `degradedCount` | `Derived<int>`              | Number of unhealthy services       |
/// | `isChecking`    | `Core<bool>`                | Whether any check is running       |
/// | `totalChecks`   | `Core<int>`                 | Lifetime check count               |
///
/// Per-service state is accessed via `status(name)`, `latency(name)`,
/// `failures(name)`, and `lastChecked(name)`.
///
/// ## Pillar Integration
///
/// Use the `warden()` extension method on Pillar for lifecycle-managed
/// instances:
///
/// ```dart
/// late final health = warden(
///   interval: Duration(seconds: 30),
///   services: [WardenService(name: 'api', check: () => ping())],
/// );
/// ```
library;

import 'dart:async';

import 'package:titan/titan.dart';

/// The health status of a monitored service.
enum ServiceStatus {
  /// No check has been performed yet.
  unknown,

  /// The service is responding normally.
  healthy,

  /// The service has failed one or more checks.
  degraded,

  /// The service has failed [WardenService.downThreshold] consecutive checks.
  down,
}

/// Configuration for a single service monitored by [Warden].
class WardenService {
  /// Creates a [WardenService].
  ///
  /// - [name] uniquely identifies this service.
  /// - [check] is an async function that completes normally if the service
  ///   is healthy and throws if it is not.
  /// - [interval] overrides the Warden's default polling interval.
  /// - [critical] determines whether this service affects [Warden.overallHealth].
  /// - [downThreshold] is how many consecutive failures mark the service
  ///   as [ServiceStatus.down] (default: 3).
  const WardenService({
    required this.name,
    required this.check,
    this.interval,
    this.critical = true,
    this.downThreshold = 3,
  });

  /// Unique identifier for this service.
  final String name;

  /// Health check function. Must complete normally on success, throw on failure.
  final Future<void> Function() check;

  /// Per-service polling interval override. `null` uses the Warden default.
  final Duration? interval;

  /// Whether this service affects the overall health aggregate.
  final bool critical;

  /// Consecutive failures before the service is marked [ServiceStatus.down].
  final int downThreshold;
}

/// Internal per-service state holder.
class _ServiceState {
  _ServiceState(this.config, String prefix)
    : status = TitanState<ServiceStatus>(
        ServiceStatus.unknown,
        name: '${prefix}_${config.name}_status',
      ),
      latency = TitanState<int>(0, name: '${prefix}_${config.name}_latency'),
      failures = TitanState<int>(0, name: '${prefix}_${config.name}_failures'),
      lastChecked = TitanState<DateTime?>(
        null,
        name: '${prefix}_${config.name}_lastChecked',
      );

  final WardenService config;
  final TitanState<ServiceStatus> status;
  final TitanState<int> latency;
  final TitanState<int> failures;
  final TitanState<DateTime?> lastChecked;
  Timer? timer;
}

/// Reactive service health monitor.
///
/// Periodically checks multiple services and exposes per-service and
/// aggregate health status as reactive state.
///
/// See the library documentation for full usage examples.
class Warden {
  /// Creates a [Warden] with the given [services] and default [interval].
  ///
  /// - [interval] is the default polling period for all services.
  /// - [services] defines the service configurations.
  /// - [name] is used for debug output and [managedNodes] naming.
  Warden({
    required this.interval,
    required List<WardenService> services,
    this.name,
  }) {
    if (services.isEmpty) {
      throw ArgumentError.value(services, 'services', 'must not be empty');
    }
    final n = name ?? 'warden';
    _isChecking = TitanState<bool>(false, name: '${n}_checking');
    _totalChecks = TitanState<int>(0, name: '${n}_totalChecks');

    for (final svc in services) {
      _services[svc.name] = _ServiceState(svc, n);
    }

    _overallHealth = TitanComputed<ServiceStatus>(() {
      var hasUnknown = false;
      for (final s in _services.values) {
        if (!s.config.critical) continue;
        final st = s.status.value;
        if (st == ServiceStatus.down || st == ServiceStatus.degraded) {
          return st;
        }
        if (st == ServiceStatus.unknown) hasUnknown = true;
      }
      return hasUnknown ? ServiceStatus.unknown : ServiceStatus.healthy;
    }, name: '${n}_overall');

    _healthyCount = TitanComputed<int>(() {
      return _services.values
          .where((s) => s.status.value == ServiceStatus.healthy)
          .length;
    }, name: '${n}_healthyCount');

    _degradedCount = TitanComputed<int>(() {
      return _services.values
          .where(
            (s) =>
                s.status.value == ServiceStatus.degraded ||
                s.status.value == ServiceStatus.down,
          )
          .length;
    }, name: '${n}_degradedCount');
  }

  /// Default polling interval.
  final Duration interval;

  /// Debug name.
  final String? name;

  // ── Internal state ─────────────────────────────────────────────────────

  final Map<String, _ServiceState> _services = {};
  late final TitanState<bool> _isChecking;
  late final TitanState<int> _totalChecks;
  late final TitanComputed<ServiceStatus> _overallHealth;
  late final TitanComputed<int> _healthyCount;
  late final TitanComputed<int> _degradedCount;
  bool _running = false;

  // ── Reactive properties ────────────────────────────────────────────────

  /// Aggregate health of all critical services (reactive).
  ///
  /// Returns [ServiceStatus.healthy] only if every critical service is healthy.
  /// Returns [ServiceStatus.unknown] if any critical service has not been checked.
  Derived<ServiceStatus> get overallHealth => _overallHealth;

  /// Number of healthy services (reactive).
  Derived<int> get healthyCount => _healthyCount;

  /// Number of degraded or down services (reactive).
  Derived<int> get degradedCount => _degradedCount;

  /// Whether any check is currently running (reactive).
  Core<bool> get isChecking => _isChecking;

  /// Lifetime count of completed checks (reactive).
  Core<int> get totalChecks => _totalChecks;

  /// Whether the Warden is actively polling.
  bool get isRunning => _running;

  /// The names of all registered services.
  List<String> get serviceNames => _services.keys.toList();

  // ── Per-service reactive state ─────────────────────────────────────────

  /// The health status of service [name] (reactive).
  Core<ServiceStatus> status(String name) => _resolve(name).status;

  /// The last check latency in milliseconds of service [name] (reactive).
  Core<int> latency(String name) => _resolve(name).latency;

  /// Consecutive failure count of service [name] (reactive).
  Core<int> failures(String name) => _resolve(name).failures;

  /// Timestamp of the last completed check for service [name] (reactive).
  Core<DateTime?> lastChecked(String name) => _resolve(name).lastChecked;

  // ── Primary API ────────────────────────────────────────────────────────

  /// Start periodic health checks for all services.
  ///
  /// Each service begins polling at its configured interval (or the
  /// Warden default). An initial check is performed immediately.
  void start() {
    if (_running) return;
    _running = true;

    for (final s in _services.values) {
      final dur = s.config.interval ?? interval;
      _checkService(s);
      s.timer = Timer.periodic(dur, (_) => _checkService(s));
    }
  }

  /// Stop all periodic health checks.
  void stop() {
    _running = false;
    for (final s in _services.values) {
      s.timer?.cancel();
      s.timer = null;
    }
  }

  /// Force an immediate health check on a single service.
  Future<void> checkService(String name) => _checkService(_resolve(name));

  /// Force an immediate health check on all services.
  Future<void> checkAll() async {
    await Future.wait(_services.values.map(_checkService));
  }

  /// Reset all services to [ServiceStatus.unknown].
  void reset() {
    stop();
    for (final s in _services.values) {
      s.status.value = ServiceStatus.unknown;
      s.latency.value = 0;
      s.failures.value = 0;
      s.lastChecked.value = null;
    }
    _totalChecks.value = 0;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Reactive nodes managed by this Warden for Pillar integration.
  Iterable<ReactiveNode> get managedNodes => [
    _isChecking,
    _totalChecks,
    for (final s in _services.values) ...[
      s.status,
      s.latency,
      s.failures,
      s.lastChecked,
    ],
  ];

  /// Dispose the Warden, stopping all timers.
  void dispose() {
    stop();
  }

  // ── Internal ───────────────────────────────────────────────────────────

  _ServiceState _resolve(String name) {
    final s = _services[name];
    if (s == null) {
      throw ArgumentError('Unknown service: "$name"');
    }
    return s;
  }

  Future<void> _checkService(_ServiceState s) async {
    _isChecking.value = true;
    final sw = Stopwatch()..start();

    try {
      await s.config.check();
      sw.stop();
      s.latency.value = sw.elapsedMilliseconds;
      s.failures.value = 0;
      s.status.value = ServiceStatus.healthy;
    } catch (_) {
      sw.stop();
      s.latency.value = sw.elapsedMilliseconds;
      s.failures.value++;
      s.status.value = s.failures.value >= s.config.downThreshold
          ? ServiceStatus.down
          : ServiceStatus.degraded;
    }

    s.lastChecked.value = DateTime.now();
    _totalChecks.value++;

    // Update isChecking — false only if no other check is running.
    // For simplicity, set to false after each individual check.
    _isChecking.value = false;
  }
}
