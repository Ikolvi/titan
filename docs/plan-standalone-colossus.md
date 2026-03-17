# Plan: Standalone Colossus — Framework-Agnostic Monitoring

> **Goal:** Make Colossus work independently of Titan's state management and HTTP client, so it can monitor **any** Flutter app — including those using Bloc, Riverpod, Provider, or plain widgets — with zero-config HTTP interception like Charles Proxy.

---

## Table of Contents

1. [Current State](#1-current-state)
2. [Target Architecture](#2-target-architecture)
3. [Phase 1: Sentinel — Built-In HTTP Interception](#3-phase-1-sentinel--built-in-http-interception)
4. [Phase 2: Abstraction Interfaces](#4-phase-2-abstraction-interfaces)
5. [Phase 3: Colossus Core Extraction](#5-phase-3-colossus-core-extraction)
6. [Phase 4: Titan Adapter Package](#6-phase-4-titan-adapter-package)
7. [Phase 5: Bloc Adapter Package](#7-phase-5-bloc-adapter-package)
8. [Phase 6: Lens UI Migration](#8-phase-6-lens-ui-migration)
9. [Migration Path for Existing Users](#9-migration-path-for-existing-users)
10. [API Design](#10-api-design)
11. [What Stays, What Moves, What's New](#11-what-stays-what-moves-whats-new)
12. [Risk Assessment](#12-risk-assessment)
13. [Flutter DevTools Integration](#13-flutter-devtools-integration)

---

## 1. Current State

### How Colossus Gets API Data Today

Colossus has **no built-in HTTP interception**. It relies entirely on Envoy's `MetricsCourier` interceptor:

```
App Code → Envoy HTTP Client → MetricsCourier → Colossus.trackApiMetric()
```

This means:
- **Only works if the app uses Envoy** (Titan's HTTP client)
- **No visibility into dio, package:http, retrofit, or raw HttpClient calls**
- Requires `ColossusEnvoy.connect()` or `ColossusPlugin(autoEnvoyMetrics: true)`

### What Data Colossus Already Stores

The `trackApiMetric()` method accepts a `Map<String, dynamic>` with:

```dart
{
  'method': 'GET',
  'url': 'https://api.example.com/users',
  'statusCode': 200,
  'durationMs': 142,
  'success': true,
  'error': null,        // Error message if failed
  'requestSize': null,  // Request body size in bytes
  'responseSize': 1024, // Response body size in bytes
  'cached': false,
  'timestamp': '2026-03-17T10:23:45.123Z',
}
```

This data model is **already framework-agnostic** — the `Map<String, dynamic>` format has no Envoy-specific types. The missing piece is the **collection mechanism**.

### Titan Core Dependencies (6 touch points)

| Dependency | Where | What It Does |
|-----------|-------|-------------|
| `extends Pillar` | `Colossus` class | Lifecycle (onInit/onDispose) |
| `Titan.put/remove` | `Colossus.init/shutdown` | DI registration |
| `Titan.instances` | `Vessel`, Lens, Relay DI inspector | Instance introspection |
| `Herald.emit()` | `_evaluateTremors()` | Broadcast performance alerts |
| `Chronicle()` | Colossus, Relay (50+ sites) | Structured logging |
| `Vigil.capture()` | `_evaluateTremors()` | Error reporting |
| `Core<T>` | Shade (2 fields), Lens tabs (16+ fields) | Reactive state |
| `Beacon/Vestige` | Lens UI (6 tabs) | Reactive widget building |
| `Spark` | `onInit()` | Text controller factory injection |
| `TitanPlugin` | `ColossusPlugin` | Zero-config widget wrapping |
| `TitanObserver` | `ColossusBastion` | Pillar lifecycle tracking |

---

## 2. Target Architecture

### Three-Layer Design

```
┌──────────────────────────────────────────────────────┐
│                    App Layer                          │
│  (Your Flutter app — Titan, Bloc, Riverpod, etc.)    │
└──────────────────┬───────────────────────────────────┘
                   │
┌──────────────────┼───────────────────────────────────┐
│     Adapter Layer (choose one)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │colossus_titan│ │ colossus_bloc│ │colossus_bare │  │
│  │              │ │              │ │ (no SM)      │  │
│  │ Pillar       │ │ BlocObserver │ │ ValueNotifier│  │
│  │ Beacon       │ │ get_it       │ │ InheritedW.  │  │
│  │ Herald       │ │ StreamCtrl   │ │ StreamCtrl   │  │
│  │ Atlas obs.   │ │ GoRouter obs.│ │ Manual       │  │
│  │ Envoy bridge │ │ Dio bridge   │ │ Sentinel only│  │
│  └──────────────┘ └──────────────┘ └──────────────┘  │
└──────────────────┬───────────────────────────────────┘
                   │
┌──────────────────┼───────────────────────────────────┐
│               colossus_core                           │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────────────┐│
│  │ Pulse  │ │ Stride │ │ Vessel │ │ Sentinel (NEW) ││
│  │ (FPS)  │ │ (Pages)│ │(Memory)│ │ (HTTP capture) ││
│  ├────────┤ ├────────┤ ├────────┤ ├────────────────┤│
│  │ Shade  │ │ Scry   │ │ Relay  │ │ Echo           ││
│  │(Record)│ │ (AI)   │ │ (HTTP) │ │ (Rebuilds)     ││
│  ├────────┤ ├────────┤ ├────────┤ ├────────────────┤│
│  │ Scout  │ │Campaign│ │ Decree │ │ Tremor         ││
│  │(Disco.)│ │(Tests) │ │(Report)│ │ (Alerts)       ││
│  └────────┘ └────────┘ └────────┘ └────────────────┘│
│  ┌─────────────────────────────────────────────────┐ │
│  │          Abstraction Interfaces                  │ │
│  │  ColossusLogger · ColossusEventBus ·             │ │
│  │  ColossusErrorReporter · ColossusServiceLocator · │ │
│  │  ColossusReactiveValue                           │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### Key Differentiator: Sentinel

Unlike Charles Proxy (external proxy), Sentinel intercepts HTTP at the **Dart VM level** using `HttpOverrides`. This means:

- **Zero config** — no proxy settings, no certificates, no network changes
- **Works on all platforms** (iOS, Android, macOS, Windows, Linux)
- **Captures ALL HTTP calls** — dio, package:http, Envoy, raw HttpClient, retrofit
- **In-process** — no network round-trips, no data leaves the device
- **Web platform** — uses `fetch` API interception via JS interop
- **Structured data** — captures request/response headers, bodies, timing, errors

---

## 3. Phase 1: Sentinel — Built-In HTTP Interception

### Overview

**Sentinel** intercepts all HTTP traffic at the `dart:io` level, like Charles Proxy but built into the app. Named after the silent watchers of ancient fortifications — they see everything that enters and exits.

### How It Works

#### Non-Web (iOS, Android, macOS, Windows, Linux)

```dart
class SentinelHttpOverrides extends HttpOverrides {
  final HttpOverrides? _previous;
  final void Function(SentinelRecord record) _onRecord;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = _previous?.createHttpClient(context)
        ?? super.createHttpClient(context);
    return _SentinelHttpClient(client, _onRecord);
  }
}
```

`_SentinelHttpClient` wraps the real `HttpClient` and delegates every call, timing the request and capturing request/response data:

```dart
class _SentinelHttpClient implements HttpClient {
  final HttpClient _inner;
  final void Function(SentinelRecord) _onRecord;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final stopwatch = Stopwatch()..start();
    final request = await _inner.openUrl(method, url);
    return _SentinelRequest(request, method, url, stopwatch, _onRecord);
  }
  // ... delegate all other HttpClient methods ...
}
```

`_SentinelRequest` wraps `HttpClientRequest` to capture the request body and headers, then wraps the response:

```dart
class _SentinelRequest implements HttpClientRequest {
  // Captures: headers, cookies, content-type, body bytes
  // When close() is called, wraps the HttpClientResponse
}

class _SentinelResponse implements HttpClientResponse {
  // Captures: status code, headers, response body bytes
  // On stream completion, fires the SentinelRecord callback
}
```

#### Web Platform

On web, `dart:io` doesn't exist. Use a separate `sentinel_web.dart` that patches the `fetch` API:

```dart
// Uses package:web to intercept window.fetch
// Wraps the native fetch with timing and body capture
```

Or more practically: on web, Sentinel can hook into `BrowserClient` from `package:http` or use a custom `Client` wrapper.

### Data Model

```dart
/// A complete HTTP transaction record captured by Sentinel.
@immutable
class SentinelRecord {
  /// Unique request ID for correlation.
  final String id;

  /// HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS).
  final String method;

  /// Full request URL including query parameters.
  final Uri url;

  /// When the request was initiated.
  final DateTime timestamp;

  /// Total round-trip duration.
  final Duration duration;

  // ── Request ──

  /// Request headers (name → value list).
  final Map<String, List<String>> requestHeaders;

  /// Request body bytes (null for GET/HEAD, capped at maxBodyCapture).
  final List<int>? requestBody;

  /// Request body size in bytes (always accurate, even if body is capped).
  final int requestSize;

  /// Detected request content type.
  final String? requestContentType;

  // ── Response ──

  /// HTTP response status code (null if connection failed).
  final int? statusCode;

  /// Response headers.
  final Map<String, List<String>>? responseHeaders;

  /// Response body bytes (capped at maxBodyCapture).
  final List<int>? responseBody;

  /// Response body size in bytes.
  final int? responseSize;

  /// Detected response content type.
  final String? responseContentType;

  // ── Outcome ──

  /// Whether the request was successful (2xx status).
  final bool success;

  /// Error message if the request failed (connection error, timeout, etc.).
  final String? error;

  /// Whether this response was served from cache.
  final bool cached;

  /// Convert to the existing Colossus API metric format for backward compat.
  Map<String, dynamic> toMetricJson() => {
    'method': method,
    'url': url.toString(),
    'statusCode': statusCode,
    'durationMs': duration.inMilliseconds,
    'success': success,
    'error': error,
    'requestSize': requestSize,
    'responseSize': responseSize,
    'cached': cached,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Full record with request/response details (for Lens inspector).
  Map<String, dynamic> toDetailJson() => {
    ...toMetricJson(),
    'id': id,
    'requestHeaders': requestHeaders,
    'requestBody': requestBody != null ? _tryDecodeUtf8(requestBody!) : null,
    'requestContentType': requestContentType,
    'responseHeaders': responseHeaders,
    'responseBody': responseBody != null ? _tryDecodeUtf8(responseBody!) : null,
    'responseContentType': responseContentType,
  };
}
```

### Configuration

```dart
class SentinelConfig {
  /// Maximum body size to capture (bytes). Bodies larger than this
  /// are truncated. Set to 0 to skip body capture entirely.
  /// Default: 64 KB.
  final int maxBodyCapture;

  /// URL patterns to exclude from capture (regex).
  /// Example: [r'localhost:\d+'] to skip Relay's own requests.
  final List<String> excludePatterns;

  /// URL patterns to include (if set, only matching URLs are captured).
  final List<String>? includePatterns;

  /// Whether to capture request bodies. Default: true.
  final bool captureRequestBody;

  /// Whether to capture response bodies. Default: true.
  final bool captureResponseBody;

  /// Whether to capture headers. Default: true.
  final bool captureHeaders;

  /// Maximum records to retain in memory. Default: 500.
  final int maxRecords;

  const SentinelConfig({
    this.maxBodyCapture = 64 * 1024,
    this.excludePatterns = const [],
    this.includePatterns,
    this.captureRequestBody = true,
    this.captureResponseBody = true,
    this.captureHeaders = true,
    this.maxRecords = 500,
  });
}
```

### Integration with Colossus

Sentinel feeds data into the existing `trackApiMetric()` pipeline:

```dart
// In Colossus.init():
static Colossus init({
  // ... existing params ...
  bool enableSentinel = true,         // NEW — on by default
  SentinelConfig sentinelConfig = const SentinelConfig(),
}) {
  // ... existing init ...

  if (enableSentinel) {
    Sentinel.install(
      config: sentinelConfig,
      onRecord: (record) {
        colossus.trackApiMetric(record.toMetricJson());
        colossus._sentinelRecords.add(record); // Full records for inspector
      },
    );
  }
}
```

### Sentinel vs. Envoy MetricsCourier

| Feature | Sentinel (NEW) | Envoy MetricsCourier |
|---------|---------------|---------------------|
| Works with any HTTP client | ✅ | ❌ Envoy only |
| Captures request/response bodies | ✅ | ❌ |
| Captures headers | ✅ | ❌ |
| Zero configuration | ✅ | Requires `ColossusEnvoy.connect()` |
| Cache status detection | ✅ (response headers) | ✅ (Envoy cache courier) |
| Web platform | ⚠️ Limited | ✅ Full |
| Request mutation (retry, auth) | ❌ Read-only | ✅ Full interceptor |
| Performance overhead | Minimal (wraps IO) | Zero (already in chain) |

**Both can coexist.** See [Dual-Source Strategy](#dual-source-strategy-sentinel--envoy-coexistence) below for how they complement each other.

### Wrapping Complexity — Exactly What Sentinel Wraps

Sentinel needs to wrap three `dart:io` classes. Here's the exact API surface:

#### `HttpClient` Wrapper (~26 members)

The wrapper class `_SentinelHttpClient implements HttpClient` must delegate every member:

| Category | Members to Delegate | Sentinel Intercepts? |
|----------|--------------------|--------------------|
| **Request openers** | `open`, `openUrl` | ✅ **Yes** — these are the 2 primary intercept points. Wrap the returned `HttpClientRequest`. |
| **Convenience methods** | `get`, `getUrl`, `post`, `postUrl`, `put`, `putUrl`, `delete`, `deleteUrl`, `head`, `headUrl`, `patch`, `patchUrl` | ❌ No — these all delegate to `open`/`openUrl` internally, so they're automatically intercepted. Just forward them. |
| **Lifecycle** | `close` | ❌ Forward only |
| **Properties** | `autoUncompress`, `connectionTimeout`, `idleTimeout`, `maxConnectionsPerHost`, `userAgent` | ❌ Forward only (get/set) |
| **Callbacks** | `authenticate`, `authenticateProxy`, `badCertificateCallback`, `connectionFactory`, `findProxy`, `keyLog` | ❌ Forward only (get/set) |

**Actual intercept code: ~20 lines** (wrap `open` and `openUrl`).  
**Delegation boilerplate: ~60 lines** (forward all properties and other methods).  
**Total: ~80 lines.**

The key insight: only `open()` and `openUrl()` need interception logic. Everything else is pure delegation.

```dart
class _SentinelHttpClient implements HttpClient {
  final HttpClient _inner;
  final void Function(SentinelRecord) _onRecord;

  // THE ONLY 2 INTERCEPT POINTS:
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async {
    final request = await _inner.open(method, host, port, path);
    return _SentinelRequest(request, method, Uri(host: host, port: port, path: path), _onRecord);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    return _SentinelRequest(request, method, url, _onRecord);
  }

  // Everything else: pure delegation
  @override set autoUncompress(bool v) => _inner.autoUncompress = v;
  @override bool get autoUncompress => _inner.autoUncompress;
  // ... ~20 more forwarding lines ...
}
```

#### `HttpClientRequest` Wrapper (~18 members)

`_SentinelRequest implements HttpClientRequest` captures the request body and wraps the response:

| Category | Members | Sentinel Intercepts? |
|----------|---------|---------------------|
| **Body writers** | `add(List<int>)`, `write(Object)`, `writeln`, `writeAll`, `writeCharCode`, `addStream` | ✅ **Yes** — copy bytes to a buffer while forwarding to the real request. This captures the request body. |
| **Close** | `close()` → `Future<HttpClientResponse>` | ✅ **Yes** — wraps the returned `HttpClientResponse` in `_SentinelResponse`. Starts the response capture. |
| **Properties** | `headers`, `cookies`, `contentLength`, `method`, `uri`, `persistentConnection`, `bufferOutput`, `encoding`, `followRedirects`, `maxRedirects` | ❌ Forward only — but **read** `headers`, `method`, `uri` to populate the `SentinelRecord`. |
| **Abort** | `abort` | ❌ Forward + record as error |

**Actual intercept code: ~30 lines** (buffer body bytes + wrap response).  
**Delegation boilerplate: ~25 lines.**  
**Total: ~55 lines.**

```dart
class _SentinelRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final List<int> _bodyBuffer = [];
  final Stopwatch _stopwatch = Stopwatch()..start();

  // Intercept body writes — just add to buffer while forwarding
  @override
  void add(List<int> data) {
    if (_captureBody) _bodyBuffer.addAll(data);
    _inner.add(data);
  }

  // Intercept close — wrap the response for body capture
  @override
  Future<HttpClientResponse> close() async {
    final response = await _inner.close();
    return _SentinelResponse(response, _buildRecord);
  }
}
```

#### `HttpClientResponse` Wrapper (~15 members)

`_SentinelResponse` wraps the response `Stream<List<int>>` to capture body bytes:

| Category | Members | Sentinel Intercepts? |
|----------|---------|---------------------|
| **Stream** | `listen()` | ✅ **Yes** — transforms the stream to copy bytes, then fires `onRecord` when stream completes. |
| **Properties** | `statusCode`, `headers`, `cookies`, `contentLength`, `reasonPhrase`, `isRedirect`, `redirects`, `certificate`, `connectionInfo`, `persistentConnection`, `compressionState` | ❌ Forward only — but **read** `statusCode`, `headers`, `contentLength` for the record. |
| **Methods** | `detachSocket`, `redirect` | ❌ Forward only |

**Actual intercept code: ~25 lines** (transform stream + fire callback).  
**Delegation boilerplate: ~30 lines.**  
**Total: ~55 lines.**

```dart
class _SentinelResponse extends Stream<List<int>> implements HttpClientResponse {
  final HttpClientResponse _inner;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final buffer = <int>[];
    return _inner.listen(
      (data) {
        if (_captureBody) buffer.addAll(data);
        onData?.call(data);
      },
      onError: onError,
      onDone: () {
        _fireRecord(buffer); // Create SentinelRecord with full data
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }
}
```

#### Total Wrapping Summary

| Class | Lines (intercept) | Lines (delegation) | Total |
|-------|-------------------|-------------------|-------|
| `_SentinelHttpClient` | ~20 | ~60 | ~80 |
| `_SentinelRequest` | ~30 | ~25 | ~55 |
| `_SentinelResponse` | ~25 | ~30 | ~55 |
| `Sentinel` (installer) | ~20 | — | ~20 |
| `SentinelRecord` (data) | ~80 | — | ~80 |
| `SentinelConfig` | ~30 | — | ~30 |
| **Total** | **~205** | **~115** | **~320 lines** |

**~320 lines of code** for complete HTTP interception. The delegation boilerplate (~115 lines) is mechanical — every line is just `@override X get y => _inner.y;`.

### Dual-Source Strategy: Sentinel + Envoy Coexistence

When both Sentinel and Envoy's MetricsCourier are active, they complement each other:

#### What Each Source Provides

| Data Point | Sentinel | Envoy MetricsCourier |
|-----------|----------|---------------------|
| Method, URL, status | ✅ | ✅ |
| Duration/timing | ✅ | ✅ |
| Success/error | ✅ | ✅ |
| Request headers | ✅ | ❌ |
| Request body | ✅ | ❌ |
| Response headers | ✅ | ❌ |
| Response body | ✅ | ❌ |
| Response size | ✅ | ✅ |
| Cache hit detection | ⚠️ Via headers only | ✅ Envoy CacheCourier aware |
| Retry count | ❌ | ✅ Envoy RetryCourier aware |
| Auth token injection | ❌ (sees final headers) | ✅ Sees pre/post auth |
| Dedup detection | ❌ | ✅ Envoy DedupCourier aware |
| Interceptor chain timing | ❌ (sees total time) | ✅ (sees per-courier time) |
| Non-Envoy HTTP calls | ✅ | ❌ |
| Third-party SDK HTTP calls | ✅ | ❌ |
| WebSocket connections | ❌ | ❌ |

#### Deduplication Strategy

When both sources report the same request, Colossus merges them:

```dart
void _mergeMetrics(SentinelRecord sentinel, Map<String, dynamic> envoyMetric) {
  // Match by: method + URL + timestamp within 100ms window
  // Keep Sentinel's rich data (headers, bodies)
  // Overlay Envoy's metadata (cache status, retry info)
  final merged = {
    ...sentinel.toDetailJson(),
    'cached': envoyMetric['cached'] ?? sentinel.toMetricJson()['cached'],
    'source': 'sentinel+envoy', // Both contributed
  };
}
```

**Matching algorithm:**

```dart
bool _isSameRequest(SentinelRecord s, Map<String, dynamic> e) {
  if (s.method != e['method']) return false;
  if (s.url.toString() != e['url']) return false;
  final sDt = s.timestamp;
  final eDt = DateTime.parse(e['timestamp'] as String);
  return sDt.difference(eDt).abs() < const Duration(milliseconds: 100);
}
```

When a match is found:
1. The `SentinelRecord` provides headers, bodies, and raw timing
2. The `EnvoyMetric` provides cache status, retry info, courier chain insights
3. Colossus stores the merged record with `source: 'sentinel+envoy'`
4. MCP tools and Lens display the richest available data

When no match (e.g., non-Envoy HTTP call from a third-party SDK):
- Sentinel record stored with `source: 'sentinel'`
- Full headers/bodies available

When Envoy-only (web platform where Sentinel can't intercept):
- Envoy metric stored with `source: 'envoy'`
- No headers/bodies (MetricsCourier doesn't capture those)

#### Configuration

```dart
Colossus.init(
  enableSentinel: true,  // Capture all HTTP via HttpOverrides
  sentinelConfig: SentinelConfig(
    // Exclude Relay's own requests from being captured
    excludePatterns: [r'localhost:864\d'],
    // Don't capture large response bodies (e.g., images)
    maxBodyCapture: 64 * 1024, // 64 KB
  ),
);

// If using Envoy, MetricsCourier can ALSO be active:
ColossusEnvoy.connect(); // Adds Envoy-specific metadata
// Both sources feed into Colossus.instance.apiMetrics
// Sentinel-specific details in Colossus.instance.sentinelRecords
```

#### Platform Matrix

| Platform | Sentinel | Envoy MetricsCourier | Best Strategy |
|----------|----------|---------------------|---------------|
| iOS | ✅ HttpOverrides | ✅ If using Envoy | Both — Sentinel for coverage, Envoy for metadata |
| Android | ✅ HttpOverrides | ✅ If using Envoy | Both |
| macOS | ✅ HttpOverrides | ✅ If using Envoy | Both |
| Windows | ✅ HttpOverrides | ✅ If using Envoy | Both |
| Linux | ✅ HttpOverrides | ✅ If using Envoy | Both |
| **Web** | ❌ No dart:io | ✅ If using Envoy | Envoy only (or custom fetch wrapper) |

**Web limitation:** `HttpOverrides` requires `dart:io` which is unavailable on web. For web apps:
- If using Envoy: MetricsCourier works as-is
- If using `package:http` with `BrowserClient`: could provide a `SentinelBrowserClient` wrapper
- If using `dio` with `dio_web_adapter`: could provide a `SentinelDioInterceptor` 
- Universal web solution: Not possible at the dart:io level; requires client-specific wrappers

### Relay Endpoints (MCP Tools)

New/enhanced endpoints for the MCP server:

```
GET /api/metrics          — Summary stats (existing, now includes Sentinel data)
GET /api/errors           — Failed requests (existing, now includes Sentinel data)
GET /api/records          — NEW: Full SentinelRecords with headers/bodies
GET /api/records/:id      — NEW: Single record detail
GET /api/records/search   — NEW: Search by URL pattern, method, status
DELETE /api/records       — NEW: Clear captured records
```

### Lens: Network Inspector Tab

New Lens tab showing a Charles-like network inspector:

```
┌─────────────────────────────────────────────────────┐
│  🔍 Network  │  Shade  │  Perf  │  Blueprint  │ ...│
├─────────────────────────────────────────────────────┤
│ ⚡ 23 requests │ 2 errors │ avg 142ms │ ▶ Recording │
├─────────────────────────────────────────────────────┤
│ ✅ GET  /api/users           200  142ms   1.2 KB    │
│ ✅ GET  /api/users/42        200   89ms   0.4 KB    │
│ ❌ POST /api/orders          500  312ms   0.1 KB    │
│ ✅ GET  /api/products?q=x    200  201ms   4.1 KB    │
│ ⏳ GET  /api/notifications   ---  ...     ---       │
├─────────────────────────────────────────────────────┤
│ ▼ Request Detail: POST /api/orders                  │
│   Status: 500 Internal Server Error                 │
│   Duration: 312ms                                   │
│   Request Headers:                                  │
│     Content-Type: application/json                  │
│     Authorization: Bearer ***                       │
│   Request Body:                                     │
│     {"items": [{"id": 42, "qty": 1}]}              │
│   Response Body:                                    │
│     {"error": "Out of stock", "code": "OOS"}       │
└─────────────────────────────────────────────────────┘
```

---

## 4. Phase 2: Abstraction Interfaces

Six interfaces in `colossus_core` replace direct Titan dependencies.

### 4.1 ColossusLogger

```dart
/// Replaces: Chronicle('name'), chronicle.info/warning/error()
abstract class ColossusLogger {
  void info(String message, [Map<String, dynamic>? data]);
  void warning(String message, [Map<String, dynamic>? data]);
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Factory that creates named loggers.
typedef ColossusLoggerFactory = ColossusLogger Function(String name);

/// Sink for capturing log entries (used by Lens).
abstract class ColossusLogSink {
  void write(ColossusLogEntry entry);
}

class ColossusLogEntry {
  final String loggerName;
  final String level; // 'info', 'warning', 'error'
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
}
```

### 4.2 ColossusEventBus

```dart
/// Replaces: Herald.emit(), Herald.allEvents
abstract class ColossusEventBus {
  void emit(Object event);
  Stream<Object> get allEvents;
  void dispose();
}
```

### 4.3 ColossusErrorReporter

```dart
/// Replaces: Vigil.capture(), Vigil.errors, Vigil.history
abstract class ColossusErrorReporter {
  void capture(String message, {ColossusErrorSeverity severity});
  Stream<Object> get errors;
  List<Object> get history;
  void clearHistory();
}

enum ColossusErrorSeverity { info, warning, error, fatal }
```

### 4.4 ColossusServiceLocator

```dart
/// Replaces: Titan.put/get/find/remove/instances
abstract class ColossusServiceLocator {
  void register<T>(T instance);
  T resolve<T>();
  T? tryResolve<T>();
  void unregister<T>();
  bool has<T>();

  /// All registered instances (for Vessel/Lens/DI inspector).
  Map<Type, dynamic> get instances;
  Set<Type> get registeredTypes;
}
```

### 4.5 ColossusReactiveValue

```dart
/// Replaces: Core<T> used in Shade
abstract class ColossusReactiveValue<T> {
  T get value;
  set value(T newValue);
  T peek();
  void addListener(void Function() listener);
  void removeListener(void Function() listener);
  void dispose();
}
```

### 4.6 ColossusBindings

```dart
/// Central configuration object that wires all implementations.
class ColossusBindings {
  final ColossusLoggerFactory createLogger;
  final ColossusEventBus eventBus;
  final ColossusErrorReporter errorReporter;
  final ColossusServiceLocator serviceLocator;
  final ColossusReactiveValue<T> Function<T>(T initial) createReactiveValue;

  /// Optional log sink for Lens display.
  final ColossusLogSink? logSink;

  const ColossusBindings({
    required this.createLogger,
    required this.eventBus,
    required this.errorReporter,
    required this.serviceLocator,
    required this.createReactiveValue,
    this.logSink,
  });

  static ColossusBindings? _instance;
  static ColossusBindings get instance {
    if (_instance == null) {
      throw StateError(
        'ColossusBindings not installed. Call ColossusBindings.install() '
        'or use a framework adapter (colossus_titan, colossus_bloc).',
      );
    }
    return _instance!;
  }

  static void install(ColossusBindings bindings) => _instance = bindings;
  static bool get isInstalled => _instance != null;

  /// Install default bindings (no external state management).
  ///
  /// Uses ValueNotifier for reactive values, StreamController for
  /// events, dart:developer for logging. Good enough for standalone
  /// Colossus without Titan or Bloc.
  static void installDefaults() {
    install(ColossusBindings(
      createLogger: (name) => _DefaultLogger(name),
      eventBus: _DefaultEventBus(),
      errorReporter: _DefaultErrorReporter(),
      serviceLocator: _DefaultServiceLocator(),
      createReactiveValue: <T>(initial) => _ValueNotifierReactive<T>(initial),
    ));
  }
}
```

### Default Implementations (built into colossus_core)

The package ships with lightweight default implementations so it works without any adapter:

| Interface | Default Implementation | Backed By |
|-----------|----------------------|-----------|
| `ColossusLogger` | `_DefaultLogger` | `dart:developer log()` |
| `ColossusEventBus` | `_DefaultEventBus` | `StreamController<Object>.broadcast()` |
| `ColossusErrorReporter` | `_DefaultErrorReporter` | In-memory list + `StreamController` |
| `ColossusServiceLocator` | `_DefaultServiceLocator` | `Map<Type, dynamic>` |
| `ColossusReactiveValue<T>` | `_ValueNotifierReactive<T>` | `ValueNotifier<T>` |

This means **Colossus works out of the box with zero dependencies** — no Titan, no Bloc, no get_it. Adapter packages enhance the experience by integrating with existing state management.

---

## 5. Phase 3: Colossus Core Extraction

### Package: `colossus_core`

```yaml
name: colossus_core
description: "Framework-agnostic performance monitoring, AI testing, and HTTP inspection for Flutter apps."
dependencies:
  flutter:
    sdk: flutter
  flutter_test:
    sdk: flutter
```

**Zero external dependencies.** Everything uses Flutter SDK + dart:io.

### What Goes Into colossus_core

| Component | Current Location | Changes Needed |
|-----------|-----------------|----------------|
| `Colossus` class | `colossus.dart` | Remove `extends Pillar`, use manual lifecycle |
| `Pulse` (FPS) | `monitors/pulse.dart` | None — pure Flutter/Scheduler |
| `Stride` (page loads) | `monitors/stride.dart` | None — pure Dart |
| `Vessel` (memory) | `monitors/vessel.dart` | Replace `Titan.instances` → `serviceLocator.instances` |
| `Echo` (rebuilds) | `widgets/echo.dart` | None — pure Flutter widget |
| `Shade` (recording) | `recording/shade.dart` | Replace `Core<T>` → `ColossusReactiveValue<T>` |
| `Phantom` (replay) | `recording/phantom.dart` | None — pure Flutter gestures |
| `Scry` (AI observe) | `testing/scry.dart` | None — pure Flutter widget introspection |
| `StratagemRunner` | `testing/stratagem_runner.dart` | None — uses Shade + Flutter test |
| `Campaign` | `testing/campaign.dart` | None — pure Dart data model |
| `Scout/Terrain` | `discovery/*.dart` | None — pure Dart graph algorithms |
| `Gauntlet` | `discovery/gauntlet.dart` | None — pure Dart test generation |
| `Relay` (HTTP server) | `relay/*.dart` | Replace `Chronicle` → `ColossusLogger` |
| `Tremor` (alerts) | `alerts/tremor.dart` | Replace `Herald.emit` → `eventBus.emit` |
| `Decree` (reports) | `metrics/decree.dart` | None — pure Dart data model |
| `Inscribe` (export) | `export/*.dart` | None — pure Dart templating |
| `Sentinel` (**NEW**) | `sentinel/*.dart` | New component — HTTP interception |

### Colossus Class After Extraction

```dart
/// No longer extends Pillar — manages its own lifecycle.
class Colossus {
  static Colossus? _instance;
  static Colossus get instance => _instance!;
  static bool get isActive => _instance != null;

  // Monitors
  final Pulse pulse;
  final Vessel vessel;
  final Stride stride;
  final Sentinel? sentinel;   // NEW

  // Internal services (from bindings)
  ColossusLogger? _logger;
  ColossusEventBus? _eventBus;

  bool _initialized = false;

  static Colossus init({
    // ... existing config params ...
    bool enableSentinel = true,
    SentinelConfig sentinelConfig = const SentinelConfig(),
    ColossusBindings? bindings, // Explicit bindings (optional)
  }) {
    if (_instance != null) return _instance!;

    // Auto-install default bindings if none provided
    if (!ColossusBindings.isInstalled) {
      if (bindings != null) {
        ColossusBindings.install(bindings);
      } else {
        ColossusBindings.installDefaults();
      }
    }

    // ... create instance ...

    // Register in service locator
    ColossusBindings.instance.serviceLocator.register(colossus);

    // Manual lifecycle
    colossus._initialize();

    return colossus;
  }

  void _initialize() {
    if (_initialized) return;
    _initialized = true;

    final bindings = ColossusBindings.instance;
    _logger = bindings.createLogger('Colossus');
    _eventBus = bindings.eventBus;

    _logger?.info('Colossus initialized');

    // Start monitors
    pulse.onUpdate = _onPulseUpdate;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
    vessel.onUpdate = _onVesselUpdate;
    vessel.start();
    stride.onPageLoad = _onPageLoad;

    // Start Sentinel HTTP interception
    sentinel?.install();

    // Hook FlutterError.onError
    _previousErrorHandler = FlutterError.onError;
    FlutterError.onError = _captureFlutterError;
  }

  void dispose() {
    if (!_initialized) return;
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    vessel.dispose();
    sentinel?.uninstall();
    relay.stop();
    FlutterError.onError = _previousErrorHandler;
    _logger?.info('Colossus shut down');
    _initialized = false;
    _instance = null;
  }

  // Tremor evaluation — uses interfaces instead of static Titan APIs
  void _evaluateTremors() {
    // ...
    for (final tremor in _tremors) {
      if (tremor.evaluate(context)) {
        final event = ColossusTremor(tremor: tremor, message: msg);
        _alertHistory.add(event);

        // Was: Herald.emit(event)
        _eventBus?.emit(event);

        // Was: _chronicle?.warning(...)
        _logger?.warning('Tremor: ${event.message}');

        // Was: Vigil.capture(...)
        ColossusBindings.instance.errorReporter.capture(
          'Performance alert: ${tremor.name}',
          severity: ColossusErrorSeverity.warning,
        );
      }
    }
  }
}
```

---

## 6. Phase 4: Titan Adapter Package

### Package: `colossus_titan`

```yaml
name: colossus_titan
dependencies:
  colossus_core: ^1.0.0
  titan: ^1.1.4
  titan_bastion: ^1.1.1
  titan_atlas: ^1.1.2
  titan_basalt: ^1.12.7
  titan_argus: ^1.0.5
  titan_envoy: ^1.1.2
```

### TitanBindings

```dart
class TitanBindings extends ColossusBindings {
  TitanBindings()
      : super(
          createLogger: (name) => _ChronicleLogger(name),
          eventBus: _HeraldEventBus(),
          errorReporter: _VigilReporter(),
          serviceLocator: _TitanServiceLocator(),
          createReactiveValue: <T>(initial) => _CoreReactive<T>(initial),
          logSink: _LensChronicleLogSink(),
        );
}

class _ChronicleLogger implements ColossusLogger {
  final Chronicle _chronicle;
  _ChronicleLogger(String name) : _chronicle = Chronicle(name);

  @override void info(String msg, [Map? data]) => _chronicle.info(msg, data);
  @override void warning(String msg, [Map? data]) => _chronicle.warning(msg);
  @override void error(String msg, [Object? e, StackTrace? st]) =>
      _chronicle.error(msg, e, st);
}

class _HeraldEventBus implements ColossusEventBus {
  @override void emit(Object event) => Herald.emit(event);
  @override Stream<Object> get allEvents =>
      Herald.allEvents.map((e) => e.payload);
  @override void dispose() {} // Herald is global
}

class _TitanServiceLocator implements ColossusServiceLocator {
  @override void register<T>(T instance) => Titan.put(instance);
  @override T resolve<T>() => Titan.get<T>();
  @override T? tryResolve<T>() => Titan.find<T>();
  @override void unregister<T>() => Titan.remove<T>();
  @override bool has<T>() => Titan.has<T>();
  @override Map<Type, dynamic> get instances => Titan.instances;
  @override Set<Type> get registeredTypes => Titan.registeredTypes;
}

class _CoreReactive<T> implements ColossusReactiveValue<T> {
  final Core<T> _core;
  _CoreReactive(T initial) : _core = Core<T>(initial);

  @override T get value => _core.value;
  @override set value(T v) => _core.value = v;
  @override T peek() => _core.peek();
  @override void addListener(void Function() l) => _core.addListener(l);
  @override void removeListener(void Function() l) => _core.removeListener(l);
  @override void dispose() => _core.dispose();
}
```

### What Moves to colossus_titan

| Component | Purpose |
|-----------|---------|
| `ColossusPlugin` | `TitanPlugin` for zero-config Beacon integration |
| `ColossusAtlasObserver` | Atlas route timing |
| `ColossusArgus` | Auth event monitoring |
| `ColossusBasalt` | Resilience primitive monitoring |
| `ColossusBastion` | Pillar lifecycle tracking |
| `ColossusEnvoy` | Envoy metric forwarding (supplements Sentinel) |
| Lens UI (all tabs) | Built with Beacon/Vestige/Pillar — Titan-specific |

### Usage (Titan App — Unchanged)

```dart
void main() {
  // Option A: Plugin (existing API — unchanged)
  runApp(
    Beacon(
      plugins: [ColossusPlugin()],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );

  // Option B: Manual (existing API — unchanged)
  ColossusBindings.install(TitanBindings());
  Colossus.init();
  runApp(Lens(child: MyApp()));
}
```

---

## 7. Phase 5: Bloc Adapter Package

### Package: `colossus_bloc`

```yaml
name: colossus_bloc
dependencies:
  colossus_core: ^1.0.0
  flutter_bloc: ^8.0.0
  get_it: ^7.0.0   # or injectable, riverpod, etc.
```

### BlocBindings

```dart
class BlocBindings extends ColossusBindings {
  BlocBindings({GetIt? getIt})
      : super(
          createLogger: (name) => _DeveloperLogger(name),
          eventBus: _StreamEventBus(),
          errorReporter: _InMemoryReporter(),
          serviceLocator: _GetItServiceLocator(getIt ?? GetIt.instance),
          createReactiveValue: <T>(initial) => _ValueNotifierReactive<T>(initial),
        );
}
```

### ColossusBlocObserver

```dart
/// Replaces ColossusBastion — tracks Bloc lifecycle and state changes.
class ColossusBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (Colossus.isActive) {
      Colossus.instance.trackEvent({
        'source': 'bloc',
        'type': 'bloc_create',
        'bloc': bloc.runtimeType.toString(),
      });
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (Colossus.isActive) {
      Colossus.instance.trackEvent({
        'source': 'bloc',
        'type': 'state_change',
        'bloc': bloc.runtimeType.toString(),
      });
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (Colossus.isActive) {
      Colossus.instance.trackEvent({
        'source': 'bloc',
        'type': 'bloc_error',
        'bloc': bloc.runtimeType.toString(),
        'error': error.toString(),
      });
    }
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (Colossus.isActive) {
      Colossus.instance.trackEvent({
        'source': 'bloc',
        'type': 'bloc_close',
        'bloc': bloc.runtimeType.toString(),
      });
    }
  }
}
```

### ColossusGoRouterObserver

```dart
/// Replaces ColossusAtlasObserver — tracks GoRouter navigation.
class ColossusGoRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (Colossus.isActive) {
      final path = _extractPath(route);
      Colossus.instance.stride.startTiming(path);
      Colossus.instance.trackEvent({
        'source': 'go_router',
        'type': 'navigate',
        'to': path,
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (Colossus.isActive) {
      Colossus.instance.trackEvent({
        'source': 'go_router',
        'type': 'pop',
        'from': _extractPath(route),
      });
    }
  }
  // ... didReplace, didRemove ...
}
```

### ColossusProvider Widget

```dart
/// Zero-config widget that initializes Colossus for Bloc apps.
/// Replaces ColossusPlugin (which requires Beacon/TitanPlugin).
class ColossusProvider extends StatefulWidget {
  final Widget child;
  final bool enableLens;
  final bool enableSentinel;
  final List<Tremor> tremors;
  final SentinelConfig sentinelConfig;

  const ColossusProvider({
    required this.child,
    this.enableLens = true,
    this.enableSentinel = true,
    this.tremors = const [],
    this.sentinelConfig = const SentinelConfig(),
  });

  @override
  State<ColossusProvider> createState() => _ColossusProviderState();
}

class _ColossusProviderState extends State<ColossusProvider> {
  @override
  void initState() {
    super.initState();
    ColossusBindings.install(BlocBindings());
    Colossus.init(
      enableSentinel: widget.enableSentinel,
      sentinelConfig: widget.sentinelConfig,
      tremors: widget.tremors,
    );
    Bloc.observer = ColossusBlocObserver();
  }

  @override
  void dispose() {
    Colossus.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableLens) {
      return ColossusLensLite(child: widget.child); // Simplified Lens
    }
    return widget.child;
  }
}
```

### Usage (Bloc App)

```dart
void main() {
  runApp(
    ColossusProvider(
      enableLens: kDebugMode,
      tremors: [Tremor.fps(), Tremor.apiLatency(threshold: Duration(seconds: 1))],
      child: MaterialApp.router(
        routerConfig: goRouter,
      ),
    ),
  );
}

// GoRouter setup:
final goRouter = GoRouter(
  observers: [ColossusGoRouterObserver()],
  routes: [...],
);
```

**That's it.** Zero Titan. Zero Envoy. Full Colossus monitoring with:
- FPS/jank tracking (Pulse)
- Page load timing (Stride + GoRouter observer)
- Memory monitoring (Vessel — works with get_it instances)
- HTTP interception (Sentinel — captures dio, http, everything)
- Bloc lifecycle tracking (ColossusBlocObserver)
- AI testing (Scry, Relay, Campaign, Stratagem)
- Session recording (Shade)
- Debug overlay (ColossusLensLite)

---

## 8. Phase 6: Lens UI Migration

### Strategy

Two versions of Lens:

#### A. `ColossusLensLite` (in `colossus_core`)

A simplified debug overlay built entirely with Flutter primitives (`StatefulWidget`, `ValueNotifier`, `ValueListenableBuilder`). No Beacon, no Vestige, no Pillar.

Includes tabs:
- **Network** — Sentinel inspector (Charles-like)
- **Performance** — FPS, jank, page loads
- **Memory** — Pillar/Bloc count, leak suspects
- **Errors** — Framework errors, API errors
- **Shade** — Recording controls
- **Blueprint** — Terrain, Stratagems

Does NOT include:
- "Pillars" tab (Titan-specific — shows Titan.instances)
- "Herald" tab (Titan-specific — shows Herald events)
- "Vigil" tab (Titan-specific — shows Vigil errors)
- "Chronicle" tab (Titan-specific — shows Chronicle logs)

#### B. `Lens` (in `colossus_titan` — existing, unchanged)

Full Lens with all built-in tabs (Pillars, Herald, Vigil, Chronicle) plus Colossus plugin tabs. Uses Beacon/Vestige. Available only for Titan apps.

---

## 9. Migration Path for Existing Users

### For Titan Users (no breakage)

```dart
// Before (titan_colossus 2.x):
dependencies:
  titan_colossus: ^2.0.7

// After (colossus_titan 3.0):
dependencies:
  colossus_titan: ^3.0.0  // Re-exports colossus_core + adds Titan integration
```

The `colossus_titan` package re-exports everything from `colossus_core` plus adds Titan-specific features. User code is unchanged because:

1. `ColossusPlugin` still exists (in `colossus_titan`)
2. `Lens` still exists (in `colossus_titan`)
3. All bridge classes still exist (in `colossus_titan`)
4. API is the same: `Colossus.init()`, `Colossus.instance.decree()`, etc.

The only required change:

```yaml
# pubspec.yaml
# Old:
titan_colossus: ^2.0.7
# New:
colossus_titan: ^3.0.0
```

```dart
// Import change:
// Old:
import 'package:titan_colossus/titan_colossus.dart';
// New:
import 'package:colossus_titan/colossus_titan.dart';
```

### For New Bloc/Riverpod Users

```dart
// Just add:
dependencies:
  colossus_bloc: ^1.0.0
  # or:
  colossus_core: ^1.0.0  // Standalone, no state management adapter
```

---

## 10. API Design

### Standalone (No State Management)

```dart
void main() {
  // Option A: Auto defaults
  Colossus.init();

  // Option B: Custom config
  Colossus.init(
    enableSentinel: true,
    sentinelConfig: SentinelConfig(
      maxBodyCapture: 128 * 1024,
      excludePatterns: [r'localhost:\d+'],
    ),
    tremors: [
      Tremor.fps(threshold: 50),
      Tremor.apiLatency(threshold: Duration(seconds: 2)),
      Tremor.apiErrorRate(threshold: 10),
    ],
  );

  runApp(
    ColossusLensLite(
      enabled: kDebugMode,
      child: MaterialApp(home: MyApp()),
    ),
  );
}

// Works. Captures all HTTP calls. No Titan. No Bloc. No Envoy.
```

### With Titan

```dart
void main() {
  runApp(
    Beacon(
      plugins: [
        ColossusPlugin(
          enableSentinel: true,  // NEW: also capture non-Envoy HTTP calls
        ),
      ],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
  // Gets Sentinel + Envoy MetricsCourier + all Titan bridges
}
```

### With Bloc

```dart
void main() {
  runApp(
    ColossusProvider(
      child: MaterialApp.router(
        routerConfig: GoRouter(
          observers: [ColossusGoRouterObserver()],
          routes: [...],
        ),
      ),
    ),
  );
}
```

---

## 11. What Stays, What Moves, What's New

### File-Level Breakdown

| Current File | Destination | Change |
|-------------|-------------|--------|
| `colossus.dart` | `colossus_core` | Remove `extends Pillar`, use interfaces |
| `colossus_plugin.dart` | `colossus_titan` | Unchanged |
| `monitors/pulse.dart` | `colossus_core` | None |
| `monitors/stride.dart` | `colossus_core` | None |
| `monitors/vessel.dart` | `colossus_core` | `Titan.instances` → `serviceLocator.instances` |
| `recording/shade.dart` | `colossus_core` | `Core<T>` → `ColossusReactiveValue<T>` |
| `recording/phantom.dart` | `colossus_core` | None |
| `recording/imprint.dart` | `colossus_core` | None |
| `recording/tableau*.dart` | `colossus_core` | None |
| `recording/fresco.dart` | `colossus_core` | None |
| `recording/shade_vault.dart` | `colossus_core` | None |
| `testing/scry.dart` | `colossus_core` | None |
| `testing/stratagem*.dart` | `colossus_core` | None |
| `testing/campaign.dart` | `colossus_core` | None |
| `testing/verdict.dart` | `colossus_core` | None |
| `testing/debrief.dart` | `colossus_core` | None |
| `testing/screen_auditor.dart` | `colossus_core` | None |
| `testing/auth_stratagem*.dart` | `colossus_core` | None |
| `discovery/scout.dart` | `colossus_core` | None |
| `discovery/terrain.dart` | `colossus_core` | None |
| `discovery/gauntlet.dart` | `colossus_core` | None |
| `discovery/lineage.dart` | `colossus_core` | None |
| `discovery/march.dart` | `colossus_core` | None |
| `discovery/outpost.dart` | `colossus_core` | None |
| `discovery/signet.dart` | `colossus_core` | None |
| `discovery/route_param*.dart` | `colossus_core` | None |
| `relay/relay.dart` | `colossus_core` | `Chronicle` → `ColossusLogger` |
| `relay/relay_io.dart` | `colossus_core` | `Chronicle` → `ColossusLogger` |
| `relay/relay_web.dart` | `colossus_core` | `Chronicle` → `ColossusLogger` |
| `alerts/tremor.dart` | `colossus_core` | Remove `Herald`/`Vigil` refs from docs |
| `metrics/decree.dart` | `colossus_core` | None |
| `metrics/mark.dart` | `colossus_core` | None |
| `export/inscribe.dart` | `colossus_core` | None |
| `export/inscribe_io.dart` | `colossus_core` | None |
| `export/blueprint_export.dart` | `colossus_core` | None |
| `framework_error.dart` | `colossus_core` | None |
| `widgets/echo.dart` | `colossus_core` | None |
| `widgets/shade_listener.dart` | `colossus_core` | `Core<bool>` listener → interface |
| `widgets/shade_text_ctrl.dart` | `colossus_core` | None |
| `mcp/mcp_ws_client.dart` | `colossus_core` | `Chronicle` → `ColossusLogger` |
| **NEW: `sentinel/*.dart`** | `colossus_core` | **New component** |
| **NEW: `interfaces/*.dart`** | `colossus_core` | **New interfaces** |
| `integration/lens.dart` | `colossus_titan` | Unchanged (uses Titan primitives) |
| `integration/*_lens_tab.dart` | `colossus_titan` | Unchanged |
| `integration/colossus_atlas*.dart` | `colossus_titan` | Unchanged |
| `integration/colossus_argus.dart` | `colossus_titan` | Unchanged |
| `integration/colossus_basalt.dart` | `colossus_titan` | Unchanged |
| `integration/colossus_bastion.dart` | `colossus_titan` | Unchanged |
| `integration/colossus_envoy.dart` | `colossus_titan` | Unchanged |

### Line Count Summary

| Category | Approximate Lines |
|----------|------------------|
| Files moving unchanged to `colossus_core` | ~12,000 |
| Files needing interface migration (~10 lines each) | ~100 lines changed |
| New interfaces + default implementations | ~400 new lines |
| New Sentinel HTTP interception | ~600 new lines |
| New ColossusLensLite (simplified Lens) | ~800 new lines |
| Files moving unchanged to `colossus_titan` | ~4,000 |
| New TitanBindings adapter | ~120 new lines |
| New `colossus_bloc` package | ~300 new lines |

**Total new code: ~2,200 lines.** Everything else is move-only.

---

## 12. Risk Assessment

### Low Risk
- **Sentinel HTTP interception** — Well-proven pattern (`HttpOverrides`), used by alice, http_inspector, and others
- **Interface extraction** — Mechanical refactoring, 6 clearly-scoped interfaces
- **Bloc adapter** — Small wrapper package, no complex logic

### Medium Risk
- **ColossusLensLite** — Rebuilding a simplified Lens without Beacon/Vestige requires careful Flutter state management. Could be simplified by using `ChangeNotifier` + `AnimatedBuilder` patterns
- **Web Sentinel** — `fetch` API interception on web is less standardized; may need `package:http`'s `BrowserClient` wrapping instead

### Low-No Risk (for existing Titan users)
- **Backward compatibility** — `colossus_titan` re-exports `colossus_core` and adds all bridges. Existing code needs only an import path change
- **Feature parity** — Titan users get everything they have today plus Sentinel as a bonus

### Mitigation
- **Phase the work**: Sentinel can ship as a standalone addition to `titan_colossus` before the full extraction
- **Feature flag**: `enableSentinel` defaults to `true` but can be disabled
- **Deduplication**: If both Sentinel and MetricsCourier report the same request, deduplicate by method+URL+timestamp within a 50ms window

---

## 13. Flutter DevTools Integration

### Overview

Flutter DevTools is the standard debugging/profiling tool for Flutter apps. Colossus can integrate with DevTools in two directions:

1. **Outbound** — Feed Colossus data INTO DevTools (custom extension tab, timeline events, structured logs)
2. **Inbound** — Consume VM service data FROM DevTools (HTTP profiling, memory, CPU profiling)

This provides advantages that Sentinel + Lens alone cannot offer.

### 13.1 DevTools Extension Tab

The `devtools_extensions` package allows any pub package to register a custom tab inside DevTools. Colossus would ship a DevTools extension alongside its Lens overlay.

#### How It Works

1. Add an `extension/devtools/` directory to the `colossus_core` (or `titan_colossus`) package
2. Build a web app (Flutter web) that runs inside the DevTools iframe
3. DevTools auto-discovers the extension when the host app depends on the package

#### Directory Structure

```
colossus_core/
├── lib/
├── extension/
│   └── devtools/
│       ├── build/              ← Pre-built Flutter web app
│       │   ├── index.html
│       │   ├── main.dart.js
│       │   └── ...
│       └── config.yaml
│           # name: colossus
│           # issueTracker: https://github.com/...
│           # version: 1.0.0
│           # materialIconCodePoint: '0xe1a0'
└── pubspec.yaml
```

#### Communication: App ↔ DevTools Extension

The extension tab communicates with the running app via VM service extensions registered with `dart:developer.registerExtension`:

```dart
// In the running app (colossus_core/lib/src/devtools_bridge.dart):
import 'dart:developer';

void registerColossusServiceExtensions() {
  // Expose performance metrics
  registerExtension('ext.colossus.getPerformance', (method, params) async {
    final decree = Colossus.instance.getDecree();
    return ServiceExtensionResponse.result(jsonEncode(decree.toJson()));
  });

  // Expose API metrics
  registerExtension('ext.colossus.getApiMetrics', (method, params) async {
    final metrics = Colossus.instance.apiMetrics;
    return ServiceExtensionResponse.result(jsonEncode(metrics));
  });

  // Expose Sentinel records (with headers/bodies)
  registerExtension('ext.colossus.getSentinelRecords', (method, params) async {
    final records = Colossus.instance.sentinelRecords
        .map((r) => r.toDetailJson()).toList();
    return ServiceExtensionResponse.result(jsonEncode(records));
  });

  // Expose terrain/blueprint
  registerExtension('ext.colossus.getTerrain', (method, params) async {
    final terrain = Colossus.instance.terrain;
    return ServiceExtensionResponse.result(jsonEncode(terrain?.toJson()));
  });

  // Expose memory snapshot
  registerExtension('ext.colossus.getMemorySnapshot', (method, params) async {
    final snapshot = Colossus.instance.vessel.snapshot();
    return ServiceExtensionResponse.result(jsonEncode(snapshot));
  });

  // Expose tremor alerts
  registerExtension('ext.colossus.getAlerts', (method, params) async {
    final alerts = Colossus.instance.alertHistory;
    return ServiceExtensionResponse.result(jsonEncode(alerts));
  });
}
```

The DevTools extension tab (Flutter web app) calls these via the VM service protocol:

```dart
// In extension/devtools/ web app:
import 'package:devtools_extensions/devtools_extensions.dart';

class ColossusDevToolsExtension extends DevToolsExtension {
  @override
  Widget build(BuildContext context) {
    return ColossusDevToolsPanel(); // Full-featured monitoring UI
  }
}

// Calling the service extension from DevTools:
Future<Map<String, dynamic>> fetchPerformance() async {
  final response = await serviceManager.callServiceExtension(
    'ext.colossus.getPerformance',
  );
  return response.json!;
}
```

#### What This Enables

| Feature | Lens (overlay) | DevTools Extension |
|---------|---------------|-------------------|
| Visible in production builds | ✅ (if included) | ❌ Debug/profile only |
| Usable without DevTools connection | ✅ | ❌ |
| Full desktop screen space | ❌ (overlay) | ✅ Full panel |
| Resizable, dockable panels | ❌ | ✅ |
| Side-by-side with Memory/CPU tabs | ❌ | ✅ |
| Persists after hot reload | ⚠️ (Pillar survives) | ✅ |
| Available on web apps | ✅ | ✅ |
| Zero runtime overhead | ❌ (renders overlay) | ✅ (only active when DevTools open) |
| Team sharing (same DevTools URL) | ❌ | ✅ |
| Keyboard shortcuts for navigation | Limited | ✅ |

**Key advantage:** DevTools extension gets a full panel with desktop-class layout, vs. Lens which is constrained to a draggable overlay. For complex views like the network inspector, blueprint graph, or campaign results, DevTools has far more screen real estate.

### 13.2 `dart:developer` — Push Colossus Events to DevTools

#### Timeline Events

Colossus can annotate the DevTools Performance timeline with its own events, making Colossus data visible alongside frame timing:

```dart
import 'dart:developer';

// In Stride (page load monitor):
void _onPageLoad(String route, Duration duration) {
  Timeline.timeSync('Colossus:PageLoad', () {
    // The page load appears in the DevTools Performance timeline
    // alongside frame timing, build phases, etc.
  }, arguments: {
    'route': route,
    'durationMs': duration.inMilliseconds.toString(),
  });
}

// In Vessel (memory monitor):
void _onLeakSuspect(String type, Duration age) {
  Timeline.instantSync('Colossus:LeakSuspect', arguments: {
    'type': type,
    'ageSec': age.inSeconds.toString(),
  });
}
```

**Advantage:** When investigating a janky frame in DevTools Performance view, the developer can see Colossus annotations (page loads, API calls, leak suspects) correlated in the same timeline — zero context switching.

#### Structured Logs via `postEvent`

Push Colossus events to the DevTools Extension stream for real-time monitoring in the extension tab:

```dart
import 'dart:developer';

// Push Tremor alerts to DevTools
void _onTremorFired(TremorAlert alert) {
  postEvent('colossus:alert', {
    'name': alert.name,
    'category': alert.category.name,
    'severity': alert.severity.name,
    'message': alert.message,
  });
}

// Push API metrics
void _onApiMetric(Map<String, dynamic> metric) {
  postEvent('colossus:api', metric);
}

// Push route changes
void _onRouteChange(String from, String to) {
  postEvent('colossus:route', {'from': from, 'to': to});
}
```

The DevTools extension tab listens to these events for a live dashboard without polling:

```dart
// In DevTools extension:
serviceManager.service.onExtensionEvent.listen((event) {
  if (event.extensionKind == 'colossus:alert') {
    // Update alerts panel in real-time
  }
  if (event.extensionKind == 'colossus:api') {
    // Update network inspector in real-time
  }
});
```

#### Structured Logs via `developer.log`

Colossus can also emit structured logs visible in the DevTools Logging tab:

```dart
import 'dart:developer' as developer;

void _logColossusEvent(String message, {Object? error}) {
  developer.log(
    message,
    name: 'colossus',
    level: error != null ? 1000 : 800,
    error: error,
  );
}
```

This means even without the Colossus extension tab installed, developers can see Colossus events in the standard DevTools Logging view.

#### CPU Profiling with UserTag

`UserTag` groups CPU samples in the DevTools CPU profiler. Colossus can tag its own operations:

```dart
import 'dart:developer';

final _colossusTag = UserTag('Colossus');
final _sentinelTag = UserTag('Sentinel');

void processSentinelRecord(SentinelRecord record) {
  final previous = _sentinelTag.makeCurrent();
  try {
    // Process the record — CPU samples are grouped under "Sentinel"
    _processRecord(record);
  } finally {
    previous.makeCurrent();
  }
}
```

**Advantage:** If Colossus itself causes performance overhead, it will show up as a distinct tag in the CPU profiler — easy to spot and optimize.

### 13.3 Inbound: Consume VM Service Data

#### Alternative HTTP Profiling via `dart:developer`

`dart:io`'s `HttpClient` already reports HTTP data to the VM service when DevTools is connected. Colossus could consume this instead of (or in addition to) Sentinel:

```dart
import 'dart:developer';

// Read HttpClient profiling data collected by the VM:
List<Map<String, dynamic>> getVmHttpProfiles() {
  return getHttpClientProfilingData();
}
```

**Comparison: VM HTTP Profiling vs. Sentinel**

| Aspect | VM HTTP Profiling | Sentinel (HttpOverrides) |
|--------|------------------|-------------------------|
| Activation | Only when DevTools is connected | Always active |
| Request body capture | ❌ | ✅ |
| Response body capture | ❌ | ✅ |
| Full headers | Partial | ✅ |
| Performance overhead | Near-zero (VM-native) | Minimal (wrapper layer) |
| Works on web | ❌ | ❌ (both `dart:io` only) |
| Production use | ❌ Debug/profile only | ✅ |
| Third-party SDK traffic | ✅ (VM sees all) | ✅ (HttpOverrides catches all) |
| Custom metadata | ❌ | ✅ (merge with Envoy) |

**Verdict:** VM profiling doesn't replace Sentinel. It's lighter but limited — no bodies, no headers, debug-only. Sentinel is the right choice for production monitoring. However, using `getHttpClientProfilingData()` as a **fallback** when Sentinel is disabled could provide minimal coverage with zero wrapping.

#### Memory Timeline Data

The VM service exposes memory data that Vessel could consume for richer analysis:

- Heap usage over time (old space, new space)
- GC events with pause durations
- Allocation profiles by class

This data is accessible through the VM service protocol (`getMemoryUsage`, `getAllocationProfile`) when DevTools is connected. The DevTools extension tab can query these directly and correlate with Vessel's Pillar tracking.

**Advantage:** Vessel currently counts Pillar instances and tracks dispose timing. With VM memory data, it could also show total heap impact of Pillars, detect GC pressure from leaked listeners, and correlate memory spikes with page transitions.

### 13.4 Advantages Summary

| Advantage | Mechanism | Impact |
|-----------|-----------|--------|
| **Full-panel monitoring UI** | DevTools extension tab | Professional monitoring dashboard with desktop layout, far richer than overlay |
| **Timeline correlation** | `Timeline.timeSync` / `Timeline.instantSync` | See Colossus events alongside frame timing in Performance tab — no context switching |
| **Real-time streaming** | `postEvent` → Extension stream | Live dashboards in DevTools extension without polling |
| **Standard Logging fallback** | `developer.log` | Colossus events visible in Logging tab even without extension installed |
| **CPU profiling visibility** | `UserTag` | Colossus overhead clearly tagged in CPU profiler |
| **Heap correlation** | VM `getMemoryUsage` / `getAllocationProfile` | Vessel enriched with real heap data, GC pressure metrics |
| **HTTP fallback** | `getHttpClientProfilingData` | Minimal HTTP monitoring when Sentinel is disabled (debug builds only) |
| **Zero-overhead when unused** | Extension only runs when DevTools is open | No runtime cost in production; Lens overlay still available for on-device debugging |
| **Team collaboration** | DevTools shared connection | Multiple developers can connect to the same running app's Colossus data |

### 13.5 Recommended Approach

**Don't choose between Lens and DevTools — ship both.**

```
┌─────────────────────────────────────────────────────┐
│                  Colossus Core                       │
│  Pulse · Stride · Vessel · Echo · Sentinel · Scout  │
│  Shade · Phantom · Tremor · Relay · Campaign        │
├────────────────────┬────────────────────────────────┤
│   Lens Overlay     │   DevTools Extension Tab       │
│   (on-device)      │   (desktop, debug builds)      │
│                    │                                │
│   • Quick debug    │   • Deep analysis              │
│   • Production OK  │   • Full screen panels         │
│   • No DevTools    │   • Timeline correlation       │
│     needed         │   • Memory/CPU integration     │
│   • Touch-friendly │   • Keyboard shortcuts         │
│                    │   • Team sharing               │
└────────────────────┴────────────────────────────────┘
```

**Lens** stays for on-device, production, quick-look debugging.  
**DevTools extension** adds desktop-class analysis with deep VM integration.

#### Implementation Effort

| Task | Effort | Lines |
|------|--------|-------|
| Register VM service extensions (`registerExtension`) | Small | ~80 |
| Timeline annotations (`Timeline.timeSync`, `postEvent`) | Small | ~60 |
| `developer.log` integration | Trivial | ~15 |
| `UserTag` for CPU profiler | Trivial | ~10 |
| DevTools extension web app (basic) | Medium | ~500–800 |
| DevTools extension web app (full-featured) | Large | ~2,000–3,000 |
| VM memory data consumption | Medium | ~150 |
| `getHttpClientProfilingData` fallback | Small | ~40 |

**Phase recommendation:**

1. **Quick win (Phase 0):** Add `registerExtension` + `postEvent` + `Timeline.timeSync` to Colossus (~150 lines). This makes Colossus data available in standard DevTools tabs immediately — no custom extension UI needed.
2. **Phase 1:** Build a basic DevTools extension tab that polls the registered extensions for a Colossus dashboard (~800 lines).
3. **Phase 2:** Expand to full-featured extension with real-time streaming, network inspector, blueprint visualizer (~2,000+ lines).

Phase 0 can ship with the **current** `titan_colossus` package — it's additive and non-breaking. It doesn't depend on the Sentinel or decoupling work.

### 13.6 Web Platform Bonus

DevTools extension solves a key Sentinel limitation: **web apps can't use HttpOverrides**. But DevTools extensions work on web too:

- The DevTools extension tab communicates via VM service protocol (works on all platforms)
- On web, `registerExtension` and `postEvent` still work
- Colossus can push whatever data it has (Envoy metrics, Navigator events, widget tree stats) to DevTools regardless of platform
- The VM's own HTTP profiling is unavailable on web, but Envoy's MetricsCourier data can be exposed via `registerExtension`

This means the DevTools extension provides a unified monitoring experience across all platforms, even where Sentinel can't operate.
