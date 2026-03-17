import 'dart:convert';
import 'dart:developer' as developer;

import '../colossus.dart';

// ---------------------------------------------------------------------------
// DevTools Bridge — Expose Colossus data via dart:developer APIs
// ---------------------------------------------------------------------------

/// **DevToolsBridge** connects Colossus to Flutter DevTools.
///
/// Provides three integration layers:
///
/// 1. **Service extensions** — expose Colossus data to DevTools
///    extension tabs via `registerExtension`
/// 2. **Timeline annotations** — feed Colossus events into the
///    DevTools Performance timeline via `Timeline.timeSync`
/// 3. **Event streaming** — push real-time events to DevTools
///    via `postEvent`
///
/// ```dart
/// // Automatically installed by Colossus.init() when enableDevTools is true.
/// // Or manually:
/// DevToolsBridge.install(Colossus.instance);
/// ```
class DevToolsBridge {
  DevToolsBridge._();

  static bool _installed = false;
  static Colossus? _colossus;

  /// Whether the bridge is installed.
  static bool get isInstalled => _installed;

  /// Install all DevTools integrations for the given [Colossus] instance.
  ///
  /// Registers VM service extensions that DevTools extension tabs
  /// can query. Safe to call multiple times — subsequent calls are no-ops.
  static void install(Colossus colossus) {
    if (_installed) return;
    _colossus = colossus;
    _installed = true;

    _registerExtensions(colossus);
  }

  /// Uninstall the bridge.
  ///
  /// Service extensions cannot be unregistered from the VM, but this
  /// clears the Colossus reference so they return empty responses.
  static void uninstall() {
    _colossus = null;
    _installed = false;
  }

  // -----------------------------------------------------------------------
  // Service Extensions — queryable from DevTools extension tabs
  // -----------------------------------------------------------------------

  static void _registerExtensions(Colossus colossus) {
    _tryRegister('ext.colossus.getPerformance', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      final decree = c.decree();
      return developer.ServiceExtensionResponse.result(
        jsonEncode(decree.toMap()),
      );
    });

    _tryRegister('ext.colossus.getApiMetrics', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      return developer.ServiceExtensionResponse.result(
        jsonEncode(c.apiMetrics),
      );
    });

    _tryRegister('ext.colossus.getSentinelRecords', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      return developer.ServiceExtensionResponse.result(
        jsonEncode(c.sentinelRecords.map((r) => r.toDetailJson()).toList()),
      );
    });

    _tryRegister('ext.colossus.getTerrain', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      return developer.ServiceExtensionResponse.result(
        jsonEncode(c.terrain.toJson()),
      );
    });

    _tryRegister('ext.colossus.getMemorySnapshot', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      return developer.ServiceExtensionResponse.result(
        jsonEncode(c.vessel.snapshot().toMap()),
      );
    });

    _tryRegister('ext.colossus.getAlerts', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      return developer.ServiceExtensionResponse.result(
        jsonEncode(c.alertHistory.map((a) => a.toMap()).toList()),
      );
    });

    _tryRegister('ext.colossus.getFrameworkErrors', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      return developer.ServiceExtensionResponse.result(
        jsonEncode(c.frameworkErrors.map((e) => e.toMap()).toList()),
      );
    });

    _tryRegister('ext.colossus.getEvents', (method, params) async {
      final c = _colossus;
      if (c == null) return _emptyResponse();
      final source = params['source'];
      final events = source != null
          ? c.events.where((e) => e['source'] == source).toList()
          : c.events;
      return developer.ServiceExtensionResponse.result(jsonEncode(events));
    });
  }

  /// Register a service extension, ignoring errors if already registered.
  static void _tryRegister(
    String method,
    developer.ServiceExtensionHandler handler,
  ) {
    try {
      developer.registerExtension(method, handler);
    } catch (_) {
      // Extension already registered (e.g. after hot restart)
    }
  }

  static developer.ServiceExtensionResponse _emptyResponse() {
    return developer.ServiceExtensionResponse.result(jsonEncode({}));
  }

  // -----------------------------------------------------------------------
  // Timeline — annotate DevTools Performance timeline
  // -----------------------------------------------------------------------

  /// Record a page load in the DevTools Performance timeline.
  ///
  /// The event appears as a named span alongside frame timing,
  /// making it easy to correlate navigation with jank.
  static void timelinePageLoad(String route, Duration duration) {
    developer.Timeline.instantSync(
      'Colossus:PageLoad',
      arguments: {
        'route': route,
        'durationMs': duration.inMilliseconds.toString(),
      },
    );
  }

  /// Record a Tremor alert in the DevTools Performance timeline.
  static void timelineTremor(String name, String message, String severity) {
    developer.Timeline.instantSync(
      'Colossus:Tremor',
      arguments: {'name': name, 'message': message, 'severity': severity},
    );
  }

  /// Record an API call in the DevTools Performance timeline.
  static void timelineApiCall(
    String method,
    String url,
    int? statusCode,
    int durationMs,
  ) {
    developer.Timeline.instantSync(
      'Colossus:API',
      arguments: {
        'method': method,
        'url': url,
        'statusCode': (statusCode ?? 0).toString(),
        'durationMs': durationMs.toString(),
      },
    );
  }

  // -----------------------------------------------------------------------
  // Event Streaming — push real-time events to DevTools
  // -----------------------------------------------------------------------

  /// Push a Tremor alert to the DevTools Extension event stream.
  ///
  /// DevTools extension tabs can listen to these events via
  /// `serviceManager.service.onExtensionEvent` for real-time
  /// dashboard updates without polling.
  static void postTremorAlert(
    String name,
    String category,
    String severity,
    String message,
  ) {
    developer.postEvent('colossus:alert', {
      'name': name,
      'category': category,
      'severity': severity,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Push an API metric to the DevTools Extension event stream.
  static void postApiMetric(Map<String, dynamic> metric) {
    developer.postEvent('colossus:api', metric);
  }

  /// Push a route change to the DevTools Extension event stream.
  static void postRouteChange(String? from, String to, String action) {
    developer.postEvent('colossus:route', {
      'from': from,
      'to': to,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Push a framework error to the DevTools Extension event stream.
  static void postFrameworkError(String category, String message) {
    developer.postEvent('colossus:frameworkError', {
      'category': category,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // -----------------------------------------------------------------------
  // Structured Logging — visible in standard DevTools Logging tab
  // -----------------------------------------------------------------------

  /// Log a Colossus event to the DevTools Logging tab.
  ///
  /// Visible even without the Colossus extension tab installed.
  static void log(String message, {int level = 800, Object? error}) {
    developer.log(message, name: 'colossus', level: level, error: error);
  }
}
