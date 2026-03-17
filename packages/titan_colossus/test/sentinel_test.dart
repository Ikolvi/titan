import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  group('SentinelRecord', () {
    test('toMetricJson contains required fields', () {
      final record = SentinelRecord(
        id: 'test-1',
        method: 'GET',
        url: Uri.parse('https://api.example.com/heroes'),
        timestamp: DateTime(2025, 1, 1),
        duration: const Duration(milliseconds: 150),
        statusCode: 200,
        success: true,
        requestSize: 0,
        responseSize: 512,
      );

      final json = record.toMetricJson();

      expect(json['method'], 'GET');
      expect(json['url'], 'https://api.example.com/heroes');
      expect(json['statusCode'], 200);
      expect(json['durationMs'], 150);
      expect(json['success'], true);
      expect(json['source'], 'sentinel');
      expect(json['requestSize'], 0);
      expect(json['responseSize'], 512);
      expect(json['timestamp'], isNotNull);
    });

    test('toDetailJson includes headers and body', () {
      final record = SentinelRecord(
        id: 'test-2',
        method: 'POST',
        url: Uri.parse('https://api.example.com/quests'),
        timestamp: DateTime(2025, 1, 1),
        duration: const Duration(milliseconds: 80),
        statusCode: 201,
        success: true,
        requestHeaders: {
          'content-type': ['application/json'],
        },
        requestBody: utf8.encode('{"name":"Kael"}'),
        requestSize: 15,
        requestContentType: 'application/json',
        responseHeaders: {
          'x-request-id': ['abc123'],
        },
        responseBody: utf8.encode('{"id":1}'),
        responseSize: 8,
        responseContentType: 'application/json',
      );

      final json = record.toDetailJson();

      // Inherits metric fields
      expect(json['method'], 'POST');
      expect(json['statusCode'], 201);
      expect(json['source'], 'sentinel');

      // Detail fields
      expect(json['id'], 'test-2');
      expect(
        json['requestHeaders'],
        containsPair('content-type', ['application/json']),
      );
      expect(json['requestBody'], '{"name":"Kael"}');
      expect(json['requestContentType'], 'application/json');
      expect(json['responseHeaders'], containsPair('x-request-id', ['abc123']));
      expect(json['responseBody'], '{"id":1}');
      expect(json['responseContentType'], 'application/json');
    });

    test('toDetailJson handles null body gracefully', () {
      final record = SentinelRecord(
        id: 'test-3',
        method: 'GET',
        url: Uri.parse('https://api.example.com/heroes'),
        timestamp: DateTime(2025, 1, 1),
        duration: const Duration(milliseconds: 50),
      );

      final json = record.toDetailJson();
      expect(json['requestBody'], isNull);
      expect(json['responseBody'], isNull);
    });

    test('toDetailJson handles binary body', () {
      final record = SentinelRecord(
        id: 'test-4',
        method: 'GET',
        url: Uri.parse('https://api.example.com/image'),
        timestamp: DateTime(2025, 1, 1),
        duration: const Duration(milliseconds: 300),
        responseBody: [0xFF, 0xD8, 0xFF, 0xE0], // JPEG magic bytes
        responseSize: 4,
      );

      final json = record.toDetailJson();
      // Binary data can't be decoded as UTF-8
      expect(json['responseBody'], startsWith('<binary'));
    });

    test('success defaults to false', () {
      final record = SentinelRecord(
        id: 'test-5',
        method: 'GET',
        url: Uri.parse('https://api.example.com/fail'),
        timestamp: DateTime(2025, 1, 1),
        duration: const Duration(milliseconds: 0),
        error: 'Connection refused',
      );

      expect(record.success, false);
      expect(record.error, 'Connection refused');
      expect(record.statusCode, isNull);
    });

    test('toMetricJson error field present for failed requests', () {
      final record = SentinelRecord(
        id: 'test-6',
        method: 'DELETE',
        url: Uri.parse('https://api.example.com/quests/1'),
        timestamp: DateTime(2025, 1, 1),
        duration: const Duration(milliseconds: 5000),
        error: 'SocketException: Connection timed out',
      );

      final json = record.toMetricJson();
      expect(json['error'], contains('Connection timed out'));
      expect(json['success'], false);
    });
  });

  group('SentinelConfig', () {
    test('defaults are sensible', () {
      const config = SentinelConfig();

      expect(config.maxBodyCapture, 64 * 1024);
      expect(config.excludePatterns, isEmpty);
      expect(config.includePatterns, isNull);
      expect(config.captureRequestBody, true);
      expect(config.captureResponseBody, true);
      expect(config.captureHeaders, true);
      expect(config.maxRecords, 500);
    });

    test('custom values are respected', () {
      final config = SentinelConfig(
        maxBodyCapture: 1024,
        excludePatterns: [r'localhost:\d+'],
        includePatterns: [r'api\.example\.com'],
        captureRequestBody: false,
        captureResponseBody: false,
        captureHeaders: false,
        maxRecords: 100,
      );

      expect(config.maxBodyCapture, 1024);
      expect(config.excludePatterns, hasLength(1));
      expect(config.includePatterns, hasLength(1));
      expect(config.captureRequestBody, false);
      expect(config.captureResponseBody, false);
      expect(config.captureHeaders, false);
      expect(config.maxRecords, 100);
    });
  });

  group('Sentinel install/uninstall', () {
    tearDown(() {
      Sentinel.uninstall();
    });

    test('isInstalled is false by default', () {
      expect(Sentinel.isInstalled, false);
    });

    test('install sets isInstalled to true', () {
      Sentinel.install(onRecord: (_) {});
      expect(Sentinel.isInstalled, true);
    });

    test('uninstall sets isInstalled to false', () {
      Sentinel.install(onRecord: (_) {});
      expect(Sentinel.isInstalled, true);

      Sentinel.uninstall();
      expect(Sentinel.isInstalled, false);
    });

    test('double install is a no-op', () {
      var callCount = 0;
      Sentinel.install(onRecord: (_) => callCount++);
      Sentinel.install(onRecord: (_) => callCount += 100);

      // Second install should be ignored — the original callback stays
      expect(Sentinel.isInstalled, true);
    });

    test('double uninstall is safe', () {
      Sentinel.install(onRecord: (_) {});
      Sentinel.uninstall();
      Sentinel.uninstall(); // Should not throw
      expect(Sentinel.isInstalled, false);
    });

    test('install wraps HttpOverrides.global', () {
      final previousOverrides = HttpOverrides.current;
      Sentinel.install(onRecord: (_) {});

      // After install, global overrides should be the Sentinel wrapper
      expect(HttpOverrides.current, isNot(same(previousOverrides)));
    });

    test('uninstall restores previous HttpOverrides', () {
      final previousOverrides = HttpOverrides.current;
      Sentinel.install(onRecord: (_) {});
      Sentinel.uninstall();

      // After uninstall, should restore previous
      expect(HttpOverrides.current, same(previousOverrides));
    });
  });

  group('Sentinel HTTP interception', () {
    late HttpServer server;
    late List<SentinelRecord> records;
    late int serverPort;

    // Flutter test runs in a zone with its own HttpOverrides, so
    // HttpClient() bypasses our global Sentinel override. We use
    // Sentinel.createClient() to get a properly wrapped client.

    setUp(() async {
      records = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = server.port;

      server.listen((request) {
        if (request.uri.path == '/echo') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"echo":true}');
          request.response.close();
        } else if (request.uri.path == '/error') {
          request.response.statusCode = 500;
          request.response.write('Internal Server Error');
          request.response.close();
        } else if (request.uri.path == '/large') {
          request.response.statusCode = 200;
          request.response.write('x' * 200);
          request.response.close();
        } else {
          request.response.statusCode = 404;
          request.response.close();
        }
      });

      Sentinel.install(
        config: const SentinelConfig(maxBodyCapture: 128),
        onRecord: records.add,
        chainPreviousOverrides: false,
      );
    });

    tearDown(() async {
      Sentinel.uninstall();
      await server.close(force: true);
    });

    test('captures GET request', () async {
      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      // Allow event loop to deliver the record
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      final record = records.first;
      expect(record.method, 'GET');
      expect(record.url.path, '/echo');
      expect(record.statusCode, 200);
      expect(record.success, true);
      expect(record.duration.inMicroseconds, greaterThan(0));
      expect(record.id, startsWith('sentinel-'));
    });

    test('captures POST request with body', () async {
      final client = Sentinel.createClient()!;
      try {
        final request = await client.postUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        request.headers.contentType = ContentType.json;
        request.write('{"hero":"Kael"}');
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      final record = records.first;
      expect(record.method, 'POST');
      expect(record.requestSize, greaterThan(0));
      expect(record.requestBody, isNotNull);
      expect(utf8.decode(record.requestBody!), '{"hero":"Kael"}');
    });

    test('captures 500 error as failed request', () async {
      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/error'),
        );
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      final record = records.first;
      expect(record.statusCode, 500);
      expect(record.success, false);
    });

    test('captures response body', () async {
      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      final record = records.first;
      expect(record.responseBody, isNotNull);
      expect(utf8.decode(record.responseBody!), '{"echo":true}');
    });

    test('truncates body at maxBodyCapture', () async {
      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/large'),
        );
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      final record = records.first;
      // maxBodyCapture is 128, response is 200 chars → should be capped
      expect(record.responseBody!.length, lessThanOrEqualTo(128));
    });

    test('captures headers when configured', () async {
      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        request.headers.add('X-Custom', 'test-value');
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      final record = records.first;
      expect(record.requestHeaders, isNotEmpty);
      expect(record.responseHeaders, isNotEmpty);
    });

    test('multiple requests generate sequential IDs', () async {
      final client = Sentinel.createClient()!;
      try {
        for (var i = 0; i < 3; i++) {
          final request = await client.getUrl(
            Uri.parse('http://localhost:$serverPort/echo'),
          );
          final response = await request.close();
          await response.drain<void>();
        }
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(records, hasLength(3));
      final ids = records.map((r) => r.id).toSet();
      expect(ids, hasLength(3)); // All unique
    });
  });

  group('Sentinel URL filtering', () {
    late HttpServer server;
    late List<SentinelRecord> records;
    late int serverPort;

    setUp(() async {
      records = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = server.port;

      server.listen((request) {
        request.response.statusCode = 200;
        request.response.close();
      });
    });

    tearDown(() async {
      Sentinel.uninstall();
      await server.close(force: true);
    });

    test('excludePatterns filters matching URLs', () async {
      Sentinel.install(
        config: SentinelConfig(excludePatterns: [r'localhost:\d+']),
        onRecord: records.add,
        chainPreviousOverrides: false,
      );

      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(records, isEmpty); // Excluded
    });

    test('includePatterns only captures matching URLs', () async {
      Sentinel.install(
        config: SentinelConfig(includePatterns: [r'api\.production\.com']),
        onRecord: records.add,
        chainPreviousOverrides: false,
      );

      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(records, isEmpty); // Not in include list
    });
  });

  group('Sentinel config: disabled capture', () {
    late HttpServer server;
    late List<SentinelRecord> records;
    late int serverPort;

    setUp(() async {
      records = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = server.port;

      server.listen((request) {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"ok":true}');
        request.response.close();
      });
    });

    tearDown(() async {
      Sentinel.uninstall();
      await server.close(force: true);
    });

    test('captureHeaders=false skips header capture', () async {
      Sentinel.install(
        config: const SentinelConfig(captureHeaders: false),
        onRecord: records.add,
        chainPreviousOverrides: false,
      );

      final client = Sentinel.createClient()!;
      try {
        final request = await client.getUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      expect(records.first.requestHeaders, isEmpty);
    });

    test('captureRequestBody=false skips request body capture', () async {
      Sentinel.install(
        config: const SentinelConfig(captureRequestBody: false),
        onRecord: records.add,
        chainPreviousOverrides: false,
      );

      final client = Sentinel.createClient()!;
      try {
        final request = await client.postUrl(
          Uri.parse('http://localhost:$serverPort/echo'),
        );
        request.write('test body');
        final response = await request.close();
        await response.drain<void>();
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(records, hasLength(1));
      // Body should be null or empty when capture is disabled
      expect(records.first.requestBody, isNull);
    });
  });
}
