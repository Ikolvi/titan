import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

void main() {
  group('EnvoySocket', () {
    late HttpServer server;
    late Uri wsUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      wsUrl = Uri.parse('ws://127.0.0.1:${server.port}/ws');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    group('construction', () {
      test('creates with defaults', () {
        final socket = EnvoySocket(wsUrl);
        expect(socket.url, wsUrl);
        expect(socket.status, SocketStatus.disconnected);
        expect(socket.isConnected, isFalse);
        expect(socket.reconnect, isFalse);
        expect(socket.headers, isEmpty);
        expect(socket.protocols, isEmpty);
        expect(socket.maxReconnectAttempts, 0);
        socket.dispose();
      });

      test('creates with custom options', () {
        final socket = EnvoySocket(
          wsUrl,
          reconnect: true,
          reconnectDelay: Duration(seconds: 2),
          maxReconnectDelay: Duration(seconds: 60),
          maxReconnectAttempts: 5,
          pingInterval: Duration(seconds: 10),
        );
        expect(socket.reconnect, isTrue);
        expect(socket.reconnectDelay, Duration(seconds: 2));
        expect(socket.maxReconnectDelay, Duration(seconds: 60));
        expect(socket.maxReconnectAttempts, 5);
        expect(socket.pingInterval, Duration(seconds: 10));
        socket.dispose();
      });
    });

    group('connection lifecycle', () {
      test('connects to a WebSocket server', () async {
        // Set up server to accept WebSocket
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.close();
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        expect(socket.status, SocketStatus.disconnected);
        await socket.connect();
        expect(socket.status, SocketStatus.connected);
        expect(socket.isConnected, isTrue);

        await socket.close();
        expect(socket.status, SocketStatus.disconnected);
      });

      test('emits status changes', () async {
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.close();
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        final statuses = <SocketStatus>[];
        socket.statusChanges.listen(statuses.add);

        await socket.connect();
        await socket.close();

        // Give status events time to propagate
        await Future<void>.delayed(Duration(milliseconds: 50));

        expect(statuses, contains(SocketStatus.connecting));
        expect(statuses, contains(SocketStatus.connected));
        expect(statuses, contains(SocketStatus.disconnected));
      });

      test('connect is idempotent when already connected', () async {
        server.transform(WebSocketTransformer()).listen((ws) {
          // Keep connection alive
          ws.listen((_) {});
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        await socket.connect();
        // Should not throw
        await socket.connect();
        expect(socket.isConnected, isTrue);

        await socket.close();
      });
    });

    group('messaging', () {
      test('sends and receives string messages', () async {
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.listen((data) {
            ws.add('echo: $data');
          });
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        await socket.connect();

        final received = Completer<dynamic>();
        socket.messages.listen(received.complete);

        socket.send('hello');
        final message = await received.future.timeout(Duration(seconds: 2));
        expect(message, 'echo: hello');

        await socket.close();
      });

      test('auto-encodes maps as JSON', () async {
        final receivedOnServer = Completer<String>();
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.listen((data) {
            receivedOnServer.complete(data as String);
            ws.close();
          });
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        await socket.connect();
        socket.send({'key': 'value', 'number': 42});

        final raw = await receivedOnServer.future.timeout(Duration(seconds: 2));
        final decoded = jsonDecode(raw);
        expect(decoded['key'], 'value');
        expect(decoded['number'], 42);

        await socket.close();
      });

      test('auto-decodes incoming JSON', () async {
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.add(jsonEncode({'status': 'ok', 'count': 7}));
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        await socket.connect();

        final received = Completer<dynamic>();
        socket.messages.listen(received.complete);

        final message = await received.future.timeout(Duration(seconds: 2));
        expect(message, isA<Map>());
        expect(message['status'], 'ok');
        expect(message['count'], 7);

        await socket.close();
      });

      test('auto-encodes lists as JSON', () async {
        final receivedOnServer = Completer<String>();
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.listen((data) {
            receivedOnServer.complete(data as String);
            ws.close();
          });
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        await socket.connect();
        socket.send([1, 2, 3]);

        final raw = await receivedOnServer.future.timeout(Duration(seconds: 2));
        expect(jsonDecode(raw), [1, 2, 3]);

        await socket.close();
      });

      test('throws when sending while disconnected', () {
        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        expect(() => socket.send('data'), throwsA(isA<StateError>()));
      });

      test('throws when sending bytes while disconnected', () {
        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        expect(() => socket.sendBytes([1, 2, 3]), throwsA(isA<StateError>()));
      });

      test('sends raw bytes', () async {
        final receivedOnServer = Completer<dynamic>();
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.listen((data) {
            receivedOnServer.complete(data);
            ws.close();
          });
        });

        final socket = EnvoySocket(wsUrl);
        addTearDown(socket.dispose);

        await socket.connect();
        socket.sendBytes([0x48, 0x65, 0x6c, 0x6c, 0x6f]);

        final data = await receivedOnServer.future.timeout(
          Duration(seconds: 2),
        );
        expect(data, isA<List<int>>());

        await socket.close();
      });
    });

    group('reconnection', () {
      test('reconnects after server disconnect', () async {
        var connectionCount = 0;
        server.transform(WebSocketTransformer()).listen((ws) {
          connectionCount++;
          if (connectionCount == 1) {
            // Close first connection to trigger reconnect
            ws.close();
          }
          // Leave second connection open
        });

        final socket = EnvoySocket(
          wsUrl,
          reconnect: true,
          reconnectDelay: Duration(milliseconds: 50),
        );
        addTearDown(socket.dispose);

        await socket.connect();

        // Wait for reconnect cycle
        await Future<void>.delayed(Duration(milliseconds: 500));

        expect(connectionCount, greaterThanOrEqualTo(2));

        await socket.close();
      });

      test('stops reconnecting after maxReconnectAttempts', () async {
        // Use a port that won't accept connections
        final badUrl = Uri.parse('ws://127.0.0.1:1/never');

        final socket = EnvoySocket(
          badUrl,
          reconnect: true,
          reconnectDelay: Duration(milliseconds: 20),
          maxReconnectAttempts: 2,
        );
        addTearDown(socket.dispose);

        final statuses = <SocketStatus>[];
        socket.statusChanges.listen(statuses.add);

        // Should fail to connect but not throw (reconect handles it)
        try {
          await socket.connect();
        } catch (_) {
          // Expected — initial connection fails
        }

        // Wait for reconnect attempts to exhaust
        await Future<void>.delayed(Duration(milliseconds: 500));

        expect(socket.status, SocketStatus.disconnected);
      });

      test('does not reconnect on intentional close', () async {
        var connectionCount = 0;
        server.transform(WebSocketTransformer()).listen((ws) {
          connectionCount++;
          ws.listen((_) {});
        });

        final socket = EnvoySocket(
          wsUrl,
          reconnect: true,
          reconnectDelay: Duration(milliseconds: 50),
        );
        addTearDown(socket.dispose);

        await socket.connect();
        expect(connectionCount, 1);

        await socket.close();
        await Future<void>.delayed(Duration(milliseconds: 200));

        // Should not have reconnected
        expect(connectionCount, 1);
        expect(socket.status, SocketStatus.disconnected);
      });
    });

    group('dispose', () {
      test('releases all resources', () async {
        server.transform(WebSocketTransformer()).listen((ws) {
          ws.listen((_) {});
        });

        final socket = EnvoySocket(wsUrl);
        await socket.connect();
        socket.dispose();

        // Streams should be closed
        expect(socket.status, SocketStatus.disconnected);
      });
    });
  });

  group('SocketStatus', () {
    test('has all expected values', () {
      expect(SocketStatus.values, hasLength(4));
      expect(SocketStatus.values, contains(SocketStatus.disconnected));
      expect(SocketStatus.values, contains(SocketStatus.connecting));
      expect(SocketStatus.values, contains(SocketStatus.connected));
      expect(SocketStatus.values, contains(SocketStatus.reconnecting));
    });
  });
}
