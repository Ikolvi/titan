/// Envoy — Titan's HTTP Client & API Layer
///
/// A full-featured HTTP client built for the Titan ecosystem, providing
/// interceptors, caching, auth integration, metrics, and route-based
/// data loading — all with zero external dependencies.
///
/// | Concept | Titan Name | Class |
/// |---------|-----------|-------|
/// | HTTP Client | **Envoy** | `Envoy` |
/// | Request | **Missive** | `Missive` |
/// | Response | **Dispatch** | `Dispatch` |
/// | Interceptor | **Courier** | `Courier` |
/// | Cancel Token | **Recall** | `Recall` |
/// | Cache | **EnvoyCache** | `EnvoyCache` |
/// | Form Data | **Parcel** | `Parcel` |
/// | Metrics | **EnvoyMetric** | `EnvoyMetric` |
/// | Throttle Gate | **Gate** | `Gate` |
/// | WebSocket | **EnvoySocket** | `EnvoySocket` |
/// | SSE | **EnvoySse** | `EnvoySse` |
/// | SSL Pinning | **EnvoyPin** | `EnvoyPin` |
/// | Proxy Config | **EnvoyProxy** | `EnvoyProxy` |
/// | Cookie Jar | **CookieCourier** | `CookieCourier` |
/// | Pillar Base | **EnvoyPillar** | `EnvoyPillar` |
/// | DI Module | **EnvoyModule** | `EnvoyModule` |
/// | Quarry/Codex | **EnvoyPillarExtension** | `envoyQuarry`, `envoyCodex` |
///
/// ## Quick Start
///
/// ```dart
/// import 'package:titan_envoy/titan_envoy.dart';
///
/// final envoy = Envoy(baseUrl: 'https://api.example.com');
///
/// // Simple GET
/// final dispatch = await envoy.get('/users');
/// print(dispatch.data); // parsed JSON
///
/// // POST with body
/// final created = await envoy.post('/users', data: {'name': 'Kael'});
///
/// // With interceptors
/// envoy.addCourier(LogCourier());
/// envoy.addCourier(RetryCourier(maxRetries: 3));
/// envoy.addCourier(AuthCourier(tokenProvider: () => getToken()));
/// ```
///
/// ## Colossus Integration
///
/// ```dart
/// envoy.addCourier(MetricsCourier(
///   onMetric: (metric) => Colossus.instance.trackApiMetric(metric.toJson()),
/// ));
/// ```
library;

// Core types
export 'src/missive.dart';
export 'src/dispatch.dart';
export 'src/envoy_error.dart';
export 'src/recall.dart';
export 'src/parcel.dart';

// Client
export 'src/envoy.dart';

// Interceptor system
export 'src/courier.dart';

// Built-in couriers
export 'src/couriers/log_courier.dart';
export 'src/couriers/retry_courier.dart';
export 'src/couriers/auth_courier.dart';
export 'src/couriers/cache_courier.dart';
export 'src/couriers/metrics_courier.dart';
export 'src/couriers/dedup_courier.dart';
export 'src/couriers/cookie_courier.dart';

// Throttling
export 'src/gate.dart';

// WebSocket & SSE (IO-only; web stubs provided for compilation)
export 'src/envoy_socket.dart'
    if (dart.library.js_interop) 'src/web_stubs/envoy_socket_web.dart';
export 'src/envoy_sse.dart'
    if (dart.library.js_interop) 'src/web_stubs/envoy_sse_web.dart';

// Security
export 'src/security.dart';

// Cache system
export 'src/cache/envoy_cache.dart';
export 'src/cache/cache_policy.dart';
export 'src/cache/memory_cache.dart';

// Metrics
export 'src/metrics.dart';

// Titan ecosystem integration
export 'src/envoy_pillar.dart';
export 'src/envoy_module.dart';
export 'src/envoy_extension.dart';
