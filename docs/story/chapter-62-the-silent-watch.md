# Chapter LXII — The Silent Watch

*In which the Colossus gains an unsleeping eye that sees every HTTP request crossing the wire — and builds a bridge to the toolsmiths beyond the fortress walls.*

> **Package:** This feature is in `titan_colossus` — add `import 'package:titan_colossus/titan_colossus.dart';` to use it.

---

The Colossus was watching. It always was.

Pulse counted frames. Stride measured page loads. Vessel tracked Pillars. Echo tallied rebuilds. Tremor raised alarms. The Relay spoke to machines beyond the fortress. Together, the monitors formed a surveillance network that rivaled any APM suite on the market.

But there was a blind spot.

"We can see every frame render," Fen said, pulling up the Lens overlay on the quest detail screen. "We can see every Pillar allocate. Every rebuild. Every page transition. But when a quest fails to load..."

She tapped a quest tile. The screen showed a loading spinner. Three seconds. Five seconds. The spinner turned red.

"...we have no idea what happened on the wire."

Kael stared at the empty error message. The Envoy had thrown an `EnvoyError` with `type: badResponse`, status 502. But that was the *end* of the story. He didn't know what headers the server returned. He didn't know if the request body was malformed. He didn't know if a redirect chain had added four extra round-trips. He didn't know if the response body contained a diagnostic message from the API gateway.

"We need a network inspector," Fen said. "Like Charles Proxy, but built in."

"Not just built in," Kael corrected. "Built *into the Colossus*. Feeding the same monitors. Raising the same Tremors. Visible through the same Lens."

He opened a new file and wrote one word at the top.

**Sentinel.**

---

## The Sentinel Watches

> *A sentinel stands at the gate and records every soul that passes. Not to judge — only to remember.*

The idea was audacious in its simplicity. Every HTTP library in Dart — `package:http`, Dio, the Envoy, raw `HttpClient` — flows through a single chokepoint: `dart:io`'s `HttpClient` class. And `dart:io` provides a mechanism to intercept that creation: `HttpOverrides`.

If Kael wrapped the `HttpOverrides`, he could see *everything*.

```dart
Colossus.init(
  enableSentinel: true,
);
```

One parameter. One boolean. The Sentinel opened its eyes.

Behind the scenes, Sentinel installed an `HttpOverrides` wrapper that created a special `HttpClient` — one that looked and behaved exactly like the real thing, but recorded every request and response that passed through it.

"It doesn't modify anything," Kael explained, showing Fen the record list in the Lens. "It doesn't add headers. It doesn't change URLs. It doesn't buffer or delay. It just... watches."

```dart
// Every HTTP transaction becomes a SentinelRecord
final records = Colossus.instance.sentinelRecords;
for (final r in records) {
  print('${r.method} ${r.url} → ${r.statusCode} (${r.duration.inMilliseconds}ms)');
}

// Output:
// GET https://api.questboard.io/quests → 200 (142ms)
// POST https://api.questboard.io/quests/42/complete → 201 (89ms)
// GET https://api.questboard.io/heroes/7 → 502 (3012ms)  ← there it is
```

The third record told the whole story. A 502 from the heroes endpoint. Three seconds of waiting. Kael could now see not just *that* it failed, but *how*.

---

## The Record

> *Every soul that passes the gate leaves a footprint. The Sentinel preserves each one in perfect detail.*

A `SentinelRecord` captures the complete HTTP round-trip:

```dart
class SentinelRecord {
  final String id;              // Unique request ID
  final String method;          // GET, POST, PUT, DELETE...
  final Uri url;                // Full URL with query params
  final DateTime timestamp;     // When the request started
  final Duration duration;      // Total round-trip time

  // Request
  final Map<String, List<String>> requestHeaders;
  final List<int>? requestBody;
  final int requestSize;
  final String? requestContentType;

  // Response
  final int? statusCode;        // null if connection failed
  final Map<String, List<String>>? responseHeaders;
  final List<int>? responseBody;
  final int? responseSize;
  final String? responseContentType;

  // Outcome
  final bool success;           // true for 2xx
  final String? error;          // Error message if failed
}
```

"Headers, body, timing, status — everything," Fen said, scrolling through a record's detail JSON. "And the request body too? We can see what we *sent*?"

"Captured before it hits the wire," Kael nodded. "The Sentinel wraps the `HttpClientRequest` and records every byte written to it. When `close()` is called—"

"It captures the response too."

"Using a `StreamTransformer`. The response body is a stream of bytes. The transformer observes every chunk and fires the record when the stream completes. Zero interference with the consumer. The data flows through untouched."

Records can be exported in two formats:

```dart
// Compact metric format (for Colossus API tracking)
final metric = record.toMetricJson();
// { method, url, statusCode, durationMs, success, source: 'sentinel' }

// Full detail format (for network inspector UI)
final detail = record.toDetailJson();
// { ...metric, id, requestHeaders, requestBody, responseHeaders, responseBody }
```

---

## The Configuration

> *A sentinel that records everything drowns in its own scrolls. Wisdom lies in knowing what to watch.*

The `SentinelConfig` controls what gets captured:

```dart
Colossus.init(
  enableSentinel: true,
  sentinelConfig: SentinelConfig(
    // Don't capture Relay's own traffic
    excludePatterns: [r'localhost:864\d'],

    // Or capture only specific endpoints
    includePatterns: ['api.questboard.io'],

    // Limit body capture to 32 KB
    maxBodyCapture: 32 * 1024,

    // Skip headers for privacy
    captureHeaders: false,

    // Skip response bodies (just track timing)
    captureResponseBody: false,

    // Keep the last 1000 records
    maxRecords: 1000,
  ),
);
```

"Why the exclude patterns?" Fen asked.

"The Relay runs an HTTP server on port 8642," Kael said. "If the MCP server queries the Relay, and the Relay's response triggers a Sentinel record, and *that* record is then visible to the MCP server, which queries again..."

"Infinite feedback loop."

"Exactly. So the Sentinel excludes its own fortress by default."

The `includePatterns` work as an allowlist — when set, only URLs matching at least one pattern are captured. Both accept regex strings:

```dart
SentinelConfig(
  // Capture only API calls, ignore CDN and analytics
  includePatterns: [
    r'api\.questboard\.io',
    r'auth\.questboard\.io',
  ],
  // But always exclude health checks
  excludePatterns: [
    r'/health$',
    r'/ping$',
  ],
)
```

---

## The Colossus Connection

> *The Sentinel doesn't just watch — it reports.*

When Sentinel captures a record, it doesn't simply store it in a list. It feeds the record into the Colossus pipeline:

```dart
// Inside Colossus.init():
Sentinel.install(
  config: sentinelConfig,
  onRecord: (record) {
    // 1. Store for Lens UI / Relay API
    _sentinelRecords.add(record);

    // 2. Feed into Colossus API metrics
    trackApiMetric(record.toMetricJson());

    // 3. Enforce max records
    while (_sentinelRecords.length > sentinelConfig.maxRecords) {
      _sentinelRecords.removeFirst();
    }
  },
);
```

This meant that every HTTP call Sentinel observed was automatically:

- Counted in Stride's API latency percentiles (p50, p95, p99)
- Tracked in the API metrics dashboard
- Evaluated by Tremors (api_latency_high, api_error_rate)
- Available through the Relay's `/sentinel/records` endpoint
- Visible in the Lens overlay

"Wait," Fen said. "The MetricsCourier in Envoy already reports to Colossus. Won't we get duplicates?"

"No — the MetricsCourier reports at the Envoy layer, with Envoy-specific metadata like cache hits and courier chain timing. The Sentinel reports at the `dart:io` layer, with raw HTTP details. Different perspectives on the same journey."

"And if someone uses `package:http` directly? No Envoy at all?"

"The Sentinel catches it anyway. That's the point. *Everything* flows through `dart:io`."

---

## The Relay Extends

The Sentinel's records are available through two new Relay endpoints:

```
GET    /sentinel/records   → All captured HTTP records
DELETE /sentinel/records   → Clear the record buffer
```

An MCP server — or any HTTP client — could query the running app's network history:

```bash
# What HTTP calls has the app made?
curl http://localhost:8642/sentinel/records \
  -H "Authorization: Bearer $TOKEN"

# Clear records before a test run
curl -X DELETE http://localhost:8642/sentinel/records \
  -H "Authorization: Bearer $TOKEN"
```

The AI scribes loved this. Now they could ask the running app: "What network calls did you make when the user tapped that button?" and get back a complete HTTP transaction log — headers, bodies, timing, status codes — all without proxy configuration, certificate pinning overrides, or external tools.

---

## The Bridge to DevTools

> *A fortress that speaks only to its own garrison speaks to no one. The bridge extends the Colossus's voice to the world beyond.*

The Sentinel was only half of what Kael built that night.

"DevTools," Rhea said, looking up from her screen. She had the standard Flutter DevTools open — the Performance tab, the Memory tab, the Network tab. "Colossus has better data than any of these. But it's locked inside the Lens overlay. I can't see it here."

Kael knew what she meant. DevTools was the universal observatory — every Flutter developer had it open. If Colossus data could appear *there*, it wouldn't just be useful. It would be ubiquitous.

He called it the **DevToolsBridge**.

```dart
Colossus.init(
  enableDevTools: true,  // On by default in debug mode
);
```

The bridge wove three threads between Colossus and DevTools:

### 1. Service Extensions — The Query Gate

DevTools queries the running app through **service extensions** — named RPC endpoints registered via `dart:developer`. The DevToolsBridge registered eight:

```
ext.colossus.getPerformance      → Pulse + Stride + Vessel + Echo decree
ext.colossus.getApiMetrics       → All tracked API calls
ext.colossus.getSentinelRecords  → Raw HTTP transaction log
ext.colossus.getTerrain          → Scout's navigation graph
ext.colossus.getMemorySnapshot   → Vessel's Pillar + leak data
ext.colossus.getAlerts           → Tremor alert history
ext.colossus.getFrameworkErrors  → Captured Flutter errors
ext.colossus.getEvents           → Integration events (filterable by source)
```

Any DevTools extension tab could call these endpoints and get structured JSON back:

```dart
// Inside a DevTools extension:
final response = await serviceManager.callServiceExtension(
  'ext.colossus.getPerformance',
);
final decree = jsonDecode(response.json!);
print(decree['pulse']['fps']);        // 59.8
print(decree['vessel']['pillars']);   // 8
print(decree['stride']['avgMs']);     // 145
```

"We can build a Colossus tab right inside DevTools," Rhea said, her eyes bright. "Real-time FPS. API latency heatmaps. Pillar lifecycle diagrams. All pulling from the same monitors."

### 2. Timeline Annotations — The Marks on the Wall

The DevTools Performance tab shows a timeline of frame renders. But frames alone don't tell the story. *Why* did that frame jank? Was it a page transition? A network call? A Tremor alarm?

The DevToolsBridge annotated the timeline with Colossus events:

```dart
// Page loads appear as timeline marks
DevToolsBridge.timelinePageLoad('/quests/42', Duration(milliseconds: 312));

// Tremor alerts mark the moment performance degraded
DevToolsBridge.timelineTremor('fps_low', 'FPS dropped to 42', 'warning');

// API calls correlate network latency with frame timing
DevToolsBridge.timelineApiCall('GET', '/api/quests', 200, 142);
```

These appeared as named spans in the Performance timeline — `Colossus:PageLoad`, `Colossus:Tremor`, `Colossus:API` — interleaved with frame timings. A developer could look at a janky frame and see: "Ah, that's when the quest detail page loaded a 312ms API call."

### 3. Event Streaming — The Living Current

Service extensions are pull-based — you ask, you receive. But a real-time dashboard needs *push* — events streaming as they happen.

The DevToolsBridge used `dart:developer`'s `postEvent` to create a live stream:

```dart
// Tremor fires → DevTools hears it immediately
DevToolsBridge.postTremorAlert(
  'api_latency_high',
  'api',
  'warning',
  'API p95 latency exceeded 500ms',
);

// Route changes stream in real-time
DevToolsBridge.postRouteChange('/quests', '/quests/42', 'navigate');

// API metrics flow continuously
DevToolsBridge.postApiMetric(record.toMetricJson());

// Framework errors arrive as they're caught
DevToolsBridge.postFrameworkError('overflow', 'RenderFlex overflowed by 42px');
```

A DevTools extension could subscribe to these events:

```dart
serviceManager.service.onExtensionEvent.listen((event) {
  if (event.extensionKind == 'colossus:alert') {
    showAlertBadge(event.extensionData!.data);
  }
});
```

No polling. No timers. Just events flowing from the app to DevTools as they happen — the same way the Colossus already flowed events to the Relay and the Lens.

### Structured Logging

For developers without a custom DevTools extension, the bridge also wrote to the standard Logging tab:

```dart
DevToolsBridge.log('Sentinel captured 502 from /api/heroes/7');
DevToolsBridge.log('Tremor fired: memory_high (12 Pillars)', level: 900);
```

Visible in DevTools Logging without any extensions installed. Zero friction.

---

## How the Sentinel Works

> *Every great trick, once explained, seems obvious. The art was in seeing the trick in the first place.*

Fen wanted to understand the internals. Kael walked her through it.

**Layer 1 — The Override**

```dart
// Sentinel.install() wraps the current HttpOverrides
final previous = HttpOverrides.current;
HttpOverrides.global = _SentinelHttpOverrides(
  previous: previous,  // Chain, don't replace
  config: config,
  onRecord: onRecord,
);
```

The key insight: chaining. The previous `HttpOverrides` isn't discarded — it's stored and delegated to for `findProxyFromEnvironment()` and other non-interception methods. `createHttpClient()` is the only method the Sentinel overrides.

**Layer 2 — The Client**

```dart
// createHttpClient() returns a _SentinelHttpClient
// It wraps the real HttpClient and intercepts only open()/openUrl()
_SentinelHttpClient(inner: previousOverrides.createHttpClient(context))
```

The wrapped client delegates twenty-four properties and methods untouched — `autoUncompress`, `connectionTimeout`, `idleTimeout`, `maxConnectionsPerHost`, `authenticate`, `badCertificateCallback` — everything. Only `open()` and `openUrl()` are intercepted, because those are where new requests start.

**Layer 3 — The Request**

When `open()` is called, the Sentinel wraps the returned `HttpClientRequest`:

```dart
// The request wrapper buffers body bytes and wraps the response
class _SentinelRequest implements HttpClientRequest {
  void add(List<int> data) {
    _bodyBuffer.add(data);  // Capture request body
    _inner.add(data);       // Forward to real request
  }

  Future<HttpClientResponse> close() async {
    final response = await _inner.close();
    return _SentinelResponse(response, ...);  // Wrap the response
  }
}
```

**Layer 4 — The Response**

The response is the most delicate part. `HttpClientResponse` implements `Stream<List<int>>` — the body is a stream of byte chunks. The Sentinel must observe every chunk *without disturbing the consumer*.

"This is where it gets tricky," Kael said. "The consumer might call `listen()`, or `drain()`, or `fold()`, or `toBytes()`. Each one consumes the stream differently. If we wrap `listen()` with an `onDone` callback..."

"The consumer could replace it," Fen finished.

"Exactly. `drain()` calls `listen(null).asFuture()`, and `asFuture()` sets `subscription.onDone = completer.complete(...)`. That *replaces* our callback. The record never fires."

"So how do you solve it?"

```dart
// A StreamTransformer whose handleDone fires BEFORE the
// subscription's replaceable onDone callback
Stream<List<int>> listen(...) {
  return _inner.transform(
    StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        _bodyBuffer.add(data);  // Capture response chunk
        sink.add(data);         // Forward untouched
      },
      handleDone: (sink) {
        _fireRecord();          // Record fires HERE — unreplaceable
        sink.close();           // THEN close triggers onDone
      },
      handleError: (e, st, sink) {
        _fireErrorRecord(e);
        sink.addError(e, st);
      },
    ),
  );
}
```

"The transformer's `handleDone` fires as part of the stream pipeline — *before* `sink.close()` propagates to the subscription's `onDone`. No consumer can replace it. The record always fires."

Fen nodded slowly. "Elegant."

"Hard-won," Kael corrected.

---

## What the Silent Watch Carries

| Titan Name | Standard Term | Purpose |
|------------|---------------|---------|
| **Sentinel** | HTTP Interceptor | Installs HttpOverrides to capture all HTTP traffic |
| **SentinelRecord** | HTTP Transaction | Complete request + response capture with timing |
| **SentinelConfig** | Interceptor Config | URL filters, body limits, max records |
| **DevToolsBridge** | DevTools Integration | Service extensions, timeline, events, logging |
| `Sentinel.install()` | Enable interception | One call, all HTTP traffic captured |
| `Sentinel.uninstall()` | Disable interception | Restores previous HttpOverrides |
| `Sentinel.createClient()` | Direct client factory | Bypasses zone-scoped overrides (for tests) |
| `ext.colossus.*` | Service extensions | 8 queryable endpoints for DevTools tabs |
| `colossus:alert` | Event stream | Real-time Tremor alerts via postEvent |
| `colossus:api` | Event stream | Real-time API metrics via postEvent |
| `colossus:route` | Event stream | Real-time route changes via postEvent |

---

The Sentinel stood at the gate, silent and unwavering. Every HTTP request that left the Questboard — every quest fetch, every hero lookup, every auth token refresh, every analytics ping — passed through its gaze. Not altered. Not delayed. Simply *recorded*.

And through the DevToolsBridge, the Colossus's intelligence flowed outward to the toolsmiths' observatory. Service extensions answered queries. Timeline annotations marked moments. Event streams carried the living pulse. Structured logs spoke to any developer who opened the Logging tab.

"We can see everything now," Fen said quietly, watching the Sentinel records scroll by in DevTools. GET. POST. 200. 502. 142ms. 3012ms. Every journey the Envoy made, every message the app sent, preserved in perfect fidelity.

"Not everything," Kael said, staring at the screen. "We can see what crosses the wire. But we still can't see what the *user* sees. The visual state. The layout. The actual pixels on screen."

Rhea set down her stylus. "You want to see through the user's eyes."

Kael nodded. "I want to *scry*."

---

*Next: [Chapter LXIII — The Eye of Scry](chapter-63-the-eye-of-scry.md) — Screen observation, live element detection, and AI-driven interaction with the running app.*
