# Chapter LXI — The Envoy Rides

*In which Kael forges the Envoy — a messenger who carries Missives across the wire, guards them with Couriers, and reports every journey to the Colossus.*

> **Package:** This feature is in `titan_envoy` — add `titan_envoy: ^0.1.0` to your `pubspec.yaml`.

---

The Questboard had grown beyond the Forge.

What had started as a local registry of heroes and quests now reached outward — to distant APIs that served quest data, to authentication servers that verified heroes' identities, to analytics endpoints that tracked completion rates. Every feature Kael built needed to talk to the outside world.

"We're using raw `HttpClient` everywhere," Fen said, scrolling through a service file. "Each screen has its own retry logic. Some have timeouts, some don't. The auth token injection is copy-pasted in four places. And when a request fails, we don't know about it until a user complains."

"We need a messenger," Kael said. "One that knows how to carry any message, adapt to any route, and report back to the Colossus what it's seen."

Rhea looked up from her workbench. "An Envoy."

---

## The Envoy

The **Envoy** is the HTTP client of the Titan ecosystem. Like Dio, but built from Titan's principles: decoupled, composable, observable.

```dart
import 'package:titan_envoy/titan_envoy.dart';

final envoy = Envoy(baseUrl: 'https://api.questboard.io');

// Simple GET
final response = await envoy.get('/quests');
print(response.data); // Parsed JSON
print(response.statusCode); // 200

// POST with body
final created = await envoy.post('/quests', data: {
  'title': 'Defeat the Shadow Wyrm',
  'reward': 500,
});
```

Every request is a **Missive** — a structured message carrying method, URL, headers, data, and configuration. Every response is a **Dispatch** — carrying the status code, parsed body, headers, and timing.

```dart
// Missive — the request
final missive = Missive(
  method: Method.get,
  uri: Uri.parse('https://api.questboard.io/quests'),
  headers: {'Accept': 'application/json'},
  queryParameters: {'status': 'active', 'limit': '10'},
);

// Send it
final dispatch = await envoy.send(missive);

// Dispatch — the response
print(dispatch.statusCode);      // 200
print(dispatch.duration);         // Duration(milliseconds: 142)
print(dispatch.isSuccess);        // true
print(dispatch.jsonMap);          // Map<String, dynamic>
print(dispatch.contentType);      // application/json
```

---

## Couriers — The Interceptor Chain

"But what about retries? Auth headers? Logging?" Fen asked.

"That's what the Couriers are for," Kael said.

A **Courier** is an interceptor — a link in a chain of responsibility that can inspect, modify, or short-circuit any Missive or Dispatch passing through.

```dart
abstract class Courier {
  Future<Dispatch> intercept(Missive missive, CourierChain chain);
}
```

Every Courier receives the Missive and a `chain` that lets it proceed to the next Courier (or the actual HTTP call). It can modify the Missive before sending, modify the Dispatch after receiving, retry on failure, or return a cached response without making a network call at all.

### LogCourier — The Chronicle's Eye

```dart
final envoy = Envoy(baseUrl: 'https://api.questboard.io');

envoy.addCourier(LogCourier(
  logHeaders: true,
  logBody: false,
  logErrors: true,
));

// Every request and response is now logged:
// [Envoy] → GET https://api.questboard.io/quests
// [Envoy] ← 200 OK (142ms)
```

### RetryCourier — The Persistent Messenger

```dart
envoy.addCourier(RetryCourier(
  maxRetries: 3,
  retryDelay: Duration(seconds: 1),
  backoffMultiplier: 2.0,      // 1s → 2s → 4s
  maxDelay: Duration(seconds: 30),
  retryOn: {500, 502, 503},    // Only retry server errors
));
```

The RetryCourier uses exponential backoff with jitter — each retry waits longer than the last, with a random offset to prevent thundering herds.

### AuthCourier — The Herald's Seal

```dart
envoy.addCourier(AuthCourier(
  tokenProvider: () async => authService.accessToken,
  onUnauthorized: () async {
    // Auto-refresh on 401
    await authService.refreshToken();
  },
));

// Every request now carries the auth token:
// Authorization: Bearer eyJ...
// If a 401 comes back, the token refreshes and the request retries.
```

### CacheCourier — The Trove's Memory

```dart
final cache = MemoryCache(maxEntries: 100);

envoy.addCourier(CacheCourier(
  cache: cache,
  defaultPolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 5)),
));

// Strategies:
// CachePolicy.cacheFirst()       — Use cache if available, else network
// CachePolicy.networkFirst()     — Try network, fall back to cache
// CachePolicy.cacheOnly()        — Only use cache (offline mode)
// CachePolicy.networkOnly()      — Skip cache entirely
// CachePolicy.staleWhileRevalidate() — Return stale, refresh in background
```

### DedupCourier — The Single Voice

```dart
envoy.addCourier(DedupCourier());

// If 10 widgets request GET /quests simultaneously,
// only ONE network call is made. All 10 get the same response.
```

### MetricsCourier — The Colossus Connection

This is where the Envoy reports home.

```dart
envoy.addCourier(MetricsCourier(
  onMetric: (metric) {
    // metric.method, metric.url, metric.statusCode, 
    // metric.duration, metric.success, metric.cached
    print('${metric.method} ${metric.url} → ${metric.statusCode}');
  },
));
```

---

## Cancellation with Recall

"What if a user navigates away mid-request?" Fen asked.

"They issue a Recall," Rhea said.

```dart
final recall = Recall();

// Start request
final future = envoy.get('/quests/heavy-dataset', recall: recall);

// User navigates away — cancel it
recall.cancel('User left the page');

try {
  final response = await future;
} on EnvoyError catch (e) {
  print(e.type); // EnvoyErrorType.cancelled
  print(e.message); // 'User left the page'
}
```

---

## File Uploads with Parcel

Parcels carry mixed content — fields and files in a single multipart request.

```dart
final parcel = Parcel()
  ..addField('title', 'Shadow Wyrm Quest')
  ..addField('difficulty', 'legendary')
  ..addFile(ParcelFile.fromBytes(
    field: 'banner',
    bytes: imageBytes,
    filename: 'wyrm-banner.png',
    contentType: 'image/png',
  ));

final response = await envoy.post('/quests', data: parcel);
```

---

## Error Handling

Every error is an **EnvoyError** with a typed category:

```dart
try {
  final response = await envoy.get('/quests');
} on EnvoyError catch (e) {
  switch (e.type) {
    case EnvoyErrorType.connectionError:
      showOfflineMessage();
    case EnvoyErrorType.timeout:
      showTimeoutMessage();
    case EnvoyErrorType.cancelled:
      // User cancelled, do nothing
      break;
    case EnvoyErrorType.badResponse:
      showErrorMessage(e.statusCode, e.message);
    case EnvoyErrorType.parseError:
      reportCorruptResponse(e);
    case EnvoyErrorType.unknown:
      reportUnknownError(e);
  }
}
```

---

## The Colossus Watches

"Now connect it," Kael said. "The Colossus should see everything the Envoy does."

The connection is one line — completely decoupled:

```dart
// In your app setup
envoy.addCourier(MetricsCourier(
  onMetric: (m) => Colossus.instance.trackApiMetric(m.toJson()),
));
```

Now every API call appears in:
- **Relay endpoints:** `GET /api/metrics` and `GET /api/errors`
- **MCP tools:** `get_api_metrics` and `get_api_errors`
- **Performance dashboards** alongside frame rates and memory usage

```
# API Metrics (Envoy)
**Total:** 47 | **Successful:** 44 | **Failed:** 3 | **Avg Duration:** 186ms

| # | Method | URL            | Status | Duration | Cached |
|---|--------|----------------|--------|----------|--------|
| 1 | GET    | /quests        | 200    | 142ms    | No     |
| 2 | GET    | /quests        | 200    | 12ms     | Yes    |
| 3 | POST   | /quests        | 201    | 320ms    | No     |
| 4 | GET    | /heroes/kael   | 500    | 3200ms   | No     |
```

---

## Composing the Full Stack

Fen assembled the final configuration:

```dart
final envoy = Envoy(
  baseUrl: 'https://api.questboard.io',
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 30),
  defaultHeaders: {
    'X-App-Version': '2.1.0',
    'Accept': 'application/json',
  },
);

// Build the courier chain (order matters!)
envoy.addCourier(LogCourier(logBody: false));
envoy.addCourier(AuthCourier(
  tokenProvider: () => authService.accessToken,
  onUnauthorized: () => authService.refreshToken(),
));
envoy.addCourier(DedupCourier());
envoy.addCourier(CacheCourier(
  cache: MemoryCache(maxEntries: 200),
  defaultPolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 5)),
));
envoy.addCourier(RetryCourier(maxRetries: 2));
envoy.addCourier(MetricsCourier(
  onMetric: (m) => Colossus.instance.trackApiMetric(m.toJson()),
));
```

**The Chain:** Log → Auth → Dedup → Cache → Retry → Metrics → Network

Each Courier is independent. Remove one, add another — the chain adapts. No tight coupling. No god class. Just composable layers, each doing one thing well.

---

## What the Envoy Carries

| Titan Name | Standard Term | Purpose |
|------------|---------------|---------|
| **Envoy** | HTTP Client | Main client with base URL, timeouts, courier chain |
| **Missive** | Request | Method, URI, headers, data, query params, config |
| **Dispatch** | Response | Status code, parsed data, raw body, headers, timing |
| **Courier** | Interceptor | Chain-of-responsibility middleware |
| **Recall** | Cancel Token | Cancellation with reason and future-based notification |
| **Parcel** | FormData | Multipart fields and files |
| **EnvoyError** | HTTP Error | Typed error with category (timeout, cancelled, badResponse...) |
| **EnvoyMetric** | Request Metric | Method, URL, status, duration, cached, timestamp |
| **EnvoyCache** | Cache Interface | Pluggable cache adapter (MemoryCache built-in) |
| **CachePolicy** | Cache Strategy | Per-request caching behavior |

---

The Envoy rode out from the Forge, carrying Missives to every endpoint the Questboard needed. Couriers guarded each journey — logging, authenticating, caching, deduplicating, retrying, measuring. And the Colossus watched every ride, building a map of the Questboard's relationship with the outside world.

"Decoupled," Fen said, watching the metrics stream in. "Every piece works alone. But together..."

"Together they're an army," Kael finished.

---

*Next: [Chapter LXII — The Silent Watch](chapter-62-the-silent-watch.md) — HTTP interception with Sentinel, DevTools integration, and the bridge that lets the toolsmiths see everything the Colossus sees.*
