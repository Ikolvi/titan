# Envoy — Titan's HTTP Client & API Layer

[![pub package](https://img.shields.io/pub/v/titan_envoy.svg)](https://pub.dev/packages/titan_envoy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Envoy** is a full-featured HTTP client built for the [Titan](https://pub.dev/packages/titan) ecosystem. It provides interceptors, caching, auth integration, metrics, WebSocket, SSE, and route-based data loading — all with zero external HTTP dependencies.

## Features

| Feature | Class | Purpose |
|---------|-------|---------|
| HTTP Client | **Envoy** | Full-featured client with interceptor pipeline, timeouts, and redirects |
| Request | **Missive** | Request builder with method, headers, body, query params, cancel token |
| Response | **Dispatch** | Response wrapper with status, headers, body, and timing metadata |
| Interceptor | **Courier** | Base interceptor with `onRequest`, `onResponse`, `onError` hooks |
| Logging | **LogCourier** | Request/response logging with configurable detail levels |
| Retry | **RetryCourier** | Automatic retry with exponential backoff and configurable conditions |
| Auth | **AuthCourier** | Token injection with automatic refresh on 401 responses |
| Caching | **CacheCourier** | HTTP caching with 5 strategies (networkFirst, cacheFirst, staleWhileRevalidate, etc.) |
| Metrics | **MetricsCourier** | Per-request metrics collection with Colossus integration |
| Dedup | **DedupCourier** | Deduplicates concurrent identical GET requests |
| Cookies | **CookieCourier** | Cookie jar management (set-cookie/cookie headers) |
| Throttle | **Gate** | Request throttling with configurable concurrency limits |
| Cancel Token | **Recall** | Cancel in-flight requests |
| Form Data | **Parcel** | Multipart form data with file uploads |
| WebSocket | **EnvoySocket** | WebSocket client with `SocketStatus` lifecycle management |
| SSE | **EnvoySse** | Server-Sent Events client with event parsing |
| SSL Pinning | **EnvoyPin** | Certificate pinning with SHA-256 fingerprints |
| Proxy | **EnvoyProxy** | HTTP/SOCKS proxy configuration |
| Cache | **MemoryCache** | In-memory TTL-based cache with LRU eviction |
| Pillar Base | **EnvoyPillar** | Base class for HTTP-backed Pillars |
| DI Module | **EnvoyModule** | DI module for registering Envoy in Titan's Vault |
| Data Extensions | **EnvoyPillarExtension** | `envoyQuarry` and `envoyCodex` for route-based data loading |

## Installation

```yaml
dependencies:
  titan: ^1.1.3
  titan_envoy: ^1.0.0
```

## Quick Start

```dart
import 'package:titan_envoy/titan_envoy.dart';

// Create a client
final envoy = Envoy(baseUrl: 'https://api.example.com');

// Simple GET
final dispatch = await envoy.get('/users');
print(dispatch.data); // parsed JSON

// POST with body
final created = await envoy.post('/users', data: {'name': 'Kael'});

// PUT, PATCH, DELETE
await envoy.put('/users/1', data: {'name': 'Kael the Great'});
await envoy.patch('/users/1', data: {'title': 'Hero'});
await envoy.delete('/users/1');
```

## Interceptors (Couriers)

Couriers form a pipeline that processes every request and response:

```dart
final envoy = Envoy(baseUrl: 'https://api.example.com');

// Add logging
envoy.addCourier(LogCourier());

// Add automatic retry (3 attempts with exponential backoff)
envoy.addCourier(RetryCourier(maxRetries: 3));

// Add auth token injection
envoy.addCourier(AuthCourier(
  tokenProvider: () async => getAccessToken(),
  refreshTokenProvider: () async => refreshToken(),
));

// Add response caching
envoy.addCourier(CacheCourier(
  cache: MemoryCache(maxEntries: 100),
  policy: CachePolicy(
    strategy: CacheStrategy.staleWhileRevalidate,
    ttl: Duration(minutes: 5),
  ),
));

// Deduplicate concurrent identical requests
envoy.addCourier(DedupCourier());
```

### Custom Courier

```dart
class ApiKeyCourier extends Courier {
  final String apiKey;
  ApiKeyCourier(this.apiKey);

  @override
  Future<Missive> onRequest(Missive missive) async {
    return missive.copyWith(
      headers: {...missive.headers, 'X-Api-Key': apiKey},
    );
  }
}
```

## Caching

Five built-in cache strategies:

```dart
// Network first, fall back to cache
CachePolicy(strategy: CacheStrategy.networkFirst, ttl: Duration(minutes: 10))

// Cache first, fetch if missing or expired
CachePolicy(strategy: CacheStrategy.cacheFirst, ttl: Duration(hours: 1))

// Return stale data immediately, revalidate in background
CachePolicy(strategy: CacheStrategy.staleWhileRevalidate, ttl: Duration(minutes: 5))

// Always network, never cache
CachePolicy(strategy: CacheStrategy.networkOnly)

// Always cache, never network
CachePolicy(strategy: CacheStrategy.cacheOnly)
```

## Cancel Requests

```dart
final recall = Recall();

// Start a request with a cancel token
final future = envoy.get('/slow-endpoint', recall: recall);

// Cancel it
recall.cancel('User navigated away');
```

## Request Throttling (Gate)

```dart
final envoy = Envoy(
  baseUrl: 'https://api.example.com',
  gate: Gate(maxConcurrent: 4), // max 4 concurrent requests
);
```

## WebSocket

```dart
final socket = EnvoySocket(url: 'wss://api.example.com/ws');

// Listen for messages
socket.stream.listen((message) => print('Received: $message'));

// Send messages
socket.send('Hello, server!');
socket.sendJson({'type': 'ping'});

// Check status
print(socket.status); // SocketStatus.connected

// Close
await socket.close();
```

## Server-Sent Events (SSE)

```dart
final sse = EnvoySse(url: 'https://api.example.com/events');

sse.stream.listen((event) {
  print('Event: ${event.event}');
  print('Data: ${event.data}');
  print('ID: ${event.id}');
});

await sse.close();
```

## Multipart Form Data

```dart
final parcel = Parcel()
  ..addField('name', 'Kael')
  ..addFile(ParcelFile(
    field: 'avatar',
    filename: 'avatar.png',
    bytes: avatarBytes,
    contentType: 'image/png',
  ));

final dispatch = await envoy.post('/upload', data: parcel);
```

## Security

```dart
// SSL certificate pinning
final envoy = Envoy(
  baseUrl: 'https://api.example.com',
  pin: EnvoyPin(fingerprints: [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ]),
);

// Proxy configuration
final envoy = Envoy(
  baseUrl: 'https://api.example.com',
  proxy: EnvoyProxy(host: 'proxy.corp.com', port: 8080),
);
```

## Titan Integration

### EnvoyPillar

Base class for Pillars that need HTTP:

```dart
class UserPillar extends EnvoyPillar {
  UserPillar() : super(baseUrl: 'https://api.example.com');

  late final users = core<List<User>>([]);

  Future<void> loadUsers() async {
    final dispatch = await envoy.get('/users');
    users.set((dispatch.data as List).map(User.fromJson).toList());
  }
}
```

### EnvoyModule

Register Envoy instances via Titan's DI:

```dart
class AppModule extends TitanModule {
  @override
  void register(TitanContainer container) {
    EnvoyModule.register(
      container,
      baseUrl: 'https://api.example.com',
      couriers: [LogCourier(), RetryCourier()],
    );
  }
}
```

### Data Loading Extensions

Use `envoyQuarry` and `envoyCodex` for route-based data fetching:

```dart
class ProductPillar extends EnvoyPillar {
  ProductPillar() : super(baseUrl: 'https://api.example.com');

  // SWR data query
  late final product = envoyQuarry<Product>(
    path: '/products/1',
    fromJson: Product.fromJson,
  );

  // Paginated data
  late final products = envoyCodex<Product>(
    path: '/products',
    fromJson: Product.fromJson,
  );
}
```

## Colossus Integration

Track API metrics with the MetricsCourier:

```dart
envoy.addCourier(MetricsCourier(
  onMetric: (metric) {
    // metric.latency, metric.statusCode, metric.url, metric.bytes
    Colossus.instance.trackApiMetric(metric.toJson());
  },
));
```

## Error Handling

```dart
try {
  final dispatch = await envoy.get('/users');
} on EnvoyError catch (e) {
  switch (e.type) {
    case EnvoyErrorType.connectTimeout:
      print('Connection timed out');
    case EnvoyErrorType.receiveTimeout:
      print('Response timed out');
    case EnvoyErrorType.cancel:
      print('Request was cancelled');
    case EnvoyErrorType.response:
      print('Server error: ${e.response?.statusCode}');
    case EnvoyErrorType.other:
      print('Unknown error: ${e.message}');
    default:
      print('Error: ${e.message}');
  }
}
```

## Ecosystem

Envoy is part of the [Titan](https://pub.dev/packages/titan) ecosystem:

| Package | Purpose |
|---------|---------|
| [titan](https://pub.dev/packages/titan) | Core reactive engine — Pillar, Core, Derived, DI |
| [titan_basalt](https://pub.dev/packages/titan_basalt) | Infrastructure — Trove, Moat, Portcullis, Saga |
| [titan_bastion](https://pub.dev/packages/titan_bastion) | Flutter widgets — Vestige, Beacon, Spark |
| [titan_atlas](https://pub.dev/packages/titan_atlas) | Routing — Atlas, Passage, Sentinel |
| [titan_argus](https://pub.dev/packages/titan_argus) | Auth — Argus, Garrison |
| [titan_colossus](https://pub.dev/packages/titan_colossus) | Performance monitoring — Colossus, Pulse, Scry |
| **titan_envoy** | **HTTP client — Envoy, Courier, Gate** |

## License

MIT — see [LICENSE](LICENSE) for details.
