import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

// Access internal transport types via the package src.
import 'package:titan_envoy/src/transport/transport.dart';
import 'package:titan_envoy/src/transport/transport_io.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // TransportResponse
  // ═══════════════════════════════════════════════════════════════════

  group('TransportResponse', () {
    test('stores status code, headers, and body bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final response = TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        bodyBytes: bytes,
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/json');
      expect(response.bodyBytes, bytes);
      expect(response.bodyBytes.length, 4);
    });

    test('handles empty body', () {
      final response = TransportResponse(
        statusCode: 204,
        headers: {},
        bodyBytes: Uint8List(0),
      );

      expect(response.statusCode, 204);
      expect(response.bodyBytes.isEmpty, isTrue);
      expect(response.headers.isEmpty, isTrue);
    });

    test('preserves multi-valued headers as comma-separated', () {
      final response = TransportResponse(
        statusCode: 200,
        headers: {'accept': 'text/html, application/json'},
        bodyBytes: Uint8List(0),
      );

      expect(response.headers['accept'], 'text/html, application/json');
    });

    test('handles large body bytes', () {
      final largeBody = Uint8List(1024 * 1024); // 1MB
      for (var i = 0; i < largeBody.length; i++) {
        largeBody[i] = i % 256;
      }

      final response = TransportResponse(
        statusCode: 200,
        headers: {'content-length': '${largeBody.length}'},
        bodyBytes: largeBody,
      );

      expect(response.bodyBytes.length, 1024 * 1024);
      expect(response.bodyBytes[0], 0);
      expect(response.bodyBytes[255], 255);
      expect(response.bodyBytes[256], 0);
    });

    test('supports all standard HTTP status codes', () {
      for (final code in [
        100,
        200,
        201,
        204,
        301,
        302,
        400,
        401,
        403,
        404,
        500,
        502,
        503,
        504,
      ]) {
        final response = TransportResponse(
          statusCode: code,
          headers: {},
          bodyBytes: Uint8List(0),
        );
        expect(response.statusCode, code);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // IoEnvoyTransport
  // ═══════════════════════════════════════════════════════════════════

  group('IoEnvoyTransport', () {
    late HttpServer server;
    late IoEnvoyTransport transport;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      transport = IoEnvoyTransport();
    });

    tearDown(() async {
      transport.close();
      await server.close(force: true);
    });

    test('sends GET request and receives response', () async {
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"status":"ok"}');
        await request.response.close();
      });

      final response = await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/test'),
        headers: {'accept': 'application/json'},
      );

      expect(response.statusCode, 200);
      final body = utf8.decode(response.bodyBytes);
      expect(body, contains('ok'));
    });

    test('sends POST request with body', () async {
      String? receivedBody;
      server.listen((request) async {
        receivedBody = await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = 201
          ..write('created');
        await request.response.close();
      });

      final bodyBytes = Uint8List.fromList(utf8.encode('{"name":"Kael"}'));
      final response = await transport.send(
        method: 'POST',
        uri: Uri.parse('http://localhost:${server.port}/users'),
        headers: {'content-type': 'application/json'},
        body: bodyBytes,
      );

      expect(response.statusCode, 201);
      expect(receivedBody, '{"name":"Kael"}');
    });

    test('sends PUT request', () async {
      String? receivedMethod;
      server.listen((request) async {
        receivedMethod = request.method;
        request.response.statusCode = 200;
        await request.response.close();
      });

      await transport.send(
        method: 'PUT',
        uri: Uri.parse('http://localhost:${server.port}/users/1'),
        headers: {},
        body: Uint8List.fromList(utf8.encode('{"name":"Updated"}')),
      );

      expect(receivedMethod, 'PUT');
    });

    test('sends DELETE request', () async {
      String? receivedMethod;
      server.listen((request) async {
        receivedMethod = request.method;
        request.response.statusCode = 204;
        await request.response.close();
      });

      await transport.send(
        method: 'DELETE',
        uri: Uri.parse('http://localhost:${server.port}/users/1'),
        headers: {},
      );

      expect(receivedMethod, 'DELETE');
    });

    test('sends PATCH request', () async {
      String? receivedMethod;
      server.listen((request) async {
        receivedMethod = request.method;
        request.response.statusCode = 200;
        await request.response.close();
      });

      await transport.send(
        method: 'PATCH',
        uri: Uri.parse('http://localhost:${server.port}/users/1'),
        headers: {},
        body: Uint8List.fromList(utf8.encode('{"name":"Patched"}')),
      );

      expect(receivedMethod, 'PATCH');
    });

    test('sends HEAD request', () async {
      String? receivedMethod;
      server.listen((request) async {
        receivedMethod = request.method;
        request.response
          ..statusCode = 200
          ..headers.add('x-total', '42');
        await request.response.close();
      });

      final response = await transport.send(
        method: 'HEAD',
        uri: Uri.parse('http://localhost:${server.port}/users'),
        headers: {},
      );

      expect(receivedMethod, 'HEAD');
      expect(response.statusCode, 200);
    });

    test('sends custom HTTP method via openUrl', () async {
      String? receivedMethod;
      server.listen((request) async {
        receivedMethod = request.method;
        request.response.statusCode = 200;
        await request.response.close();
      });

      final response = await transport.send(
        method: 'OPTIONS',
        uri: Uri.parse('http://localhost:${server.port}/cors'),
        headers: {},
      );

      expect(receivedMethod, 'OPTIONS');
      expect(response.statusCode, 200);
    });

    test('passes headers to server', () async {
      Map<String, String>? receivedHeaders;
      server.listen((request) async {
        receivedHeaders = {
          'x-custom': request.headers.value('x-custom') ?? '',
          'authorization': request.headers.value('authorization') ?? '',
        };
        request.response.statusCode = 200;
        await request.response.close();
      });

      await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/test'),
        headers: {'x-custom': 'test-value', 'authorization': 'Bearer token123'},
      );

      expect(receivedHeaders?['x-custom'], 'test-value');
      expect(receivedHeaders?['authorization'], 'Bearer token123');
    });

    test('collects response headers', () async {
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..headers.add('x-request-id', 'abc-123')
          ..headers.add('x-rate-limit', '100');
        await request.response.close();
      });

      final response = await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/test'),
        headers: {},
      );

      expect(response.headers['x-request-id'], 'abc-123');
      expect(response.headers['x-rate-limit'], '100');
    });

    test('handles empty response body', () async {
      server.listen((request) async {
        request.response.statusCode = 204;
        await request.response.close();
      });

      final response = await transport.send(
        method: 'DELETE',
        uri: Uri.parse('http://localhost:${server.port}/items/1'),
        headers: {},
      );

      expect(response.statusCode, 204);
      expect(response.bodyBytes.isEmpty, isTrue);
    });

    test('handles large response bodies', () async {
      final largePayload = 'x' * 100000;
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write(largePayload);
        await request.response.close();
      });

      final response = await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/large'),
        headers: {},
      );

      expect(utf8.decode(response.bodyBytes), largePayload);
    });

    test('handles chunked response', () async {
      server.listen((request) async {
        request.response.statusCode = 200;
        for (var i = 0; i < 10; i++) {
          request.response.write('chunk$i-');
          await Future<void>.delayed(Duration(milliseconds: 5));
        }
        await request.response.close();
      });

      final response = await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/chunked'),
        headers: {},
      );

      final body = utf8.decode(response.bodyBytes);
      expect(body, contains('chunk0-'));
      expect(body, contains('chunk9-'));
    });

    test('returns error status codes without throwing', () async {
      server.listen((request) async {
        request.response
          ..statusCode = 500
          ..write('Internal Server Error');
        await request.response.close();
      });

      final response = await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/error'),
        headers: {},
      );

      // Transport returns the error status — Envoy decides what to do
      expect(response.statusCode, 500);
      expect(utf8.decode(response.bodyBytes), 'Internal Server Error');
    });

    test('handles binary response body', () async {
      final binaryData = Uint8List.fromList(List.generate(256, (i) => i));
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.binary
          ..add(binaryData);
        await request.response.close();
      });

      final response = await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/binary'),
        headers: {},
      );

      expect(response.bodyBytes, binaryData);
    });

    test('sends request with null body', () async {
      bool bodyWasEmpty = false;
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        bodyWasEmpty = body.isEmpty;
        request.response.statusCode = 200;
        await request.response.close();
      });

      await transport.send(
        method: 'GET',
        uri: Uri.parse('http://localhost:${server.port}/test'),
        headers: {},
        body: null,
      );

      expect(bodyWasEmpty, isTrue);
    });

    test('throws StateError after close', () async {
      transport.close();

      expect(
        () => transport.send(
          method: 'GET',
          uri: Uri.parse('http://localhost:${server.port}/test'),
          headers: {},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('close with force=true terminates immediately', () {
      // Should not throw
      transport.close(force: true);

      expect(
        () => transport.send(
          method: 'GET',
          uri: Uri.parse('http://localhost:${server.port}/test'),
          headers: {},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('concurrent requests through same transport', () async {
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        request.response
          ..statusCode = 200
          ..write('response-$requestCount');
        await request.response.close();
      });

      final futures = List.generate(
        10,
        (i) => transport.send(
          method: 'GET',
          uri: Uri.parse('http://localhost:${server.port}/concurrent/$i'),
          headers: {},
        ),
      );

      final responses = await Future.wait(futures);
      expect(responses.length, 10);
      expect(responses.every((r) => r.statusCode == 200), isTrue);
    });

    test('handles connection refused gracefully', () async {
      // Use a port that's not listening
      expect(
        () => transport.send(
          method: 'GET',
          uri: Uri.parse('http://localhost:1/not-listening'),
          headers: {},
        ),
        throwsA(anything),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // IoEnvoyTransport with SSL Pinning
  // ═══════════════════════════════════════════════════════════════════

  group('IoEnvoyTransport — SSL Pinning', () {
    test('creates transport with self-signed pin', () {
      final transport = IoEnvoyTransport(pin: EnvoyPin(allowSelfSigned: true));
      // Should create without error
      transport.close();
    });

    test('creates transport with fingerprint pin', () {
      final transport = IoEnvoyTransport(
        pin: EnvoyPin(
          fingerprints: ['abcdef1234567890abcdef1234567890abcdef12'],
        ),
      );
      transport.close();
    });

    test('creates transport with empty fingerprints', () {
      final transport = IoEnvoyTransport(pin: EnvoyPin(fingerprints: []));
      transport.close();
    });

    test('creates transport with host override', () {
      final transport = IoEnvoyTransport(
        pin: EnvoyPin(
          fingerprints: ['abcdef1234567890abcdef1234567890abcdef12'],
          hostOverride: 'api.example.com',
        ),
      );
      transport.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // IoEnvoyTransport with Proxy
  // ═══════════════════════════════════════════════════════════════════

  group('IoEnvoyTransport — Proxy', () {
    test('creates transport with proxy config', () {
      final transport = IoEnvoyTransport(
        proxy: EnvoyProxy(host: 'proxy.example.com', port: 8080),
      );
      transport.close();
    });

    test('creates transport with authenticated proxy', () {
      final transport = IoEnvoyTransport(
        proxy: EnvoyProxy(
          host: 'proxy.example.com',
          port: 8080,
          username: 'user',
          password: 'pass',
        ),
      );
      transport.close();
    });

    test('creates transport with bypass list', () {
      final transport = IoEnvoyTransport(
        proxy: EnvoyProxy(
          host: 'proxy.example.com',
          port: 8080,
          bypass: ['localhost', '127.0.0.1'],
        ),
      );
      transport.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // IoEnvoyTransport with connect timeout
  // ═══════════════════════════════════════════════════════════════════

  group('IoEnvoyTransport — Timeout', () {
    test('creates transport with connect timeout', () {
      final transport = IoEnvoyTransport(connectTimeout: Duration(seconds: 5));
      transport.close();
    });

    test('creates transport with all options', () {
      final transport = IoEnvoyTransport(
        connectTimeout: Duration(seconds: 5),
        pin: EnvoyPin(allowSelfSigned: true),
        proxy: EnvoyProxy(host: 'proxy.test', port: 9090),
      );
      transport.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // createTransport factory
  // ═══════════════════════════════════════════════════════════════════

  group('createTransport factory', () {
    test('creates IoEnvoyTransport on IO platform', () {
      final transport = createTransport();
      expect(transport, isA<IoEnvoyTransport>());
      transport.close();
    });

    test('passes connect timeout', () {
      final transport = createTransport(connectTimeout: Duration(seconds: 10));
      expect(transport, isA<IoEnvoyTransport>());
      expect(
        (transport as IoEnvoyTransport).connectTimeout,
        Duration(seconds: 10),
      );
      transport.close();
    });

    test('passes pin and proxy as Object?', () {
      final transport = createTransport(
        pin: EnvoyPin(allowSelfSigned: true),
        proxy: EnvoyProxy(host: 'proxy.test', port: 8080),
      );
      expect(transport, isA<IoEnvoyTransport>());
      transport.close();
    });
  });
}
