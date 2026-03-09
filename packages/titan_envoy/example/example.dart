// ignore_for_file: avoid_print

/// Envoy — Titan's HTTP client with interceptors, caching, and ecosystem
/// integration.
///
/// This example demonstrates core Envoy capabilities:
/// - [Envoy] — HTTP client with interceptor pipeline
/// - [Courier] — Request/response interceptors
/// - [CacheCourier] — Response caching with multiple strategies
/// - [Recall] — Request cancellation
/// - [EnvoyPillar] — HTTP-backed Pillar integration
library;

import 'package:titan_envoy/titan_envoy.dart';

// ---------------------------------------------------------------------------
// Basic HTTP requests
// ---------------------------------------------------------------------------

Future<void> basicRequests() async {
  final envoy = Envoy(baseUrl: 'https://jsonplaceholder.typicode.com');

  // GET
  final dispatch = await envoy.get('/posts/1');
  print('Title: ${dispatch.data['title']}');

  // POST
  final created = await envoy.post('/posts', data: {
    'title': 'Hello from Envoy',
    'body': 'Titan HTTP client',
    'userId': 1,
  });
  print('Created post ID: ${created.data['id']}');

  envoy.dispose();
}

// ---------------------------------------------------------------------------
// Interceptor pipeline (Couriers)
// ---------------------------------------------------------------------------

Future<void> courierPipeline() async {
  final envoy = Envoy(baseUrl: 'https://jsonplaceholder.typicode.com');

  // Add logging, retry, and caching
  envoy.addCourier(LogCourier());
  envoy.addCourier(RetryCourier(maxRetries: 3));
  envoy.addCourier(CacheCourier(
    cache: MemoryCache(maxEntries: 50),
    policy: CachePolicy(
      strategy: CacheStrategy.staleWhileRevalidate,
      ttl: Duration(minutes: 5),
    ),
  ));

  // Requests now flow through the courier pipeline
  final dispatch = await envoy.get('/posts');
  print('Fetched ${(dispatch.data as List).length} posts');

  envoy.dispose();
}

// ---------------------------------------------------------------------------
// Cancel in-flight requests
// ---------------------------------------------------------------------------

Future<void> cancellation() async {
  final envoy = Envoy(baseUrl: 'https://jsonplaceholder.typicode.com');
  final recall = Recall();

  try {
    // ignore: unawaited_futures
    envoy.get('/posts', recall: recall);
    recall.cancel('User navigated away');
  } on EnvoyError catch (e) {
    if (e.type == EnvoyErrorType.cancel) {
      print('Request cancelled: ${e.message}');
    }
  }

  envoy.dispose();
}

// ---------------------------------------------------------------------------
// Request throttling
// ---------------------------------------------------------------------------

Future<void> throttling() async {
  final envoy = Envoy(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    gate: Gate(maxConcurrent: 2), // max 2 concurrent requests
  );

  // Only 2 requests execute at a time; others queue automatically
  final futures = List.generate(
    10,
    (i) => envoy.get('/posts/${i + 1}'),
  );

  final results = await Future.wait(futures);
  print('Fetched ${results.length} posts with throttling');

  envoy.dispose();
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  print('=== Basic Requests ===');
  await basicRequests();

  print('\n=== Courier Pipeline ===');
  await courierPipeline();

  print('\n=== Cancellation ===');
  await cancellation();

  print('\n=== Throttling ===');
  await throttling();
}
