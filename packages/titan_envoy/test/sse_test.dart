import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

void main() {
  group('EnvoySse', () {
    late HttpServer server;
    late Uri sseUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      sseUrl = Uri.parse('http://127.0.0.1:${server.port}/events');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    group('construction', () {
      test('creates with defaults', () {
        final sse = EnvoySse(sseUrl);
        expect(sse.url, sseUrl);
        expect(sse.reconnect, isTrue);
        expect(sse.headers, isEmpty);
        expect(sse.maxReconnectAttempts, 0);
        expect(sse.lastEventId, isNull);
        expect(sse.isConnected, isFalse);
        sse.dispose();
      });

      test('creates with custom options', () {
        final sse = EnvoySse(
          sseUrl,
          headers: {'Authorization': 'Bearer token'},
          reconnect: false,
          reconnectDelay: Duration(seconds: 5),
          maxReconnectAttempts: 3,
          lastEventId: 'evt-42',
        );
        expect(sse.headers['Authorization'], 'Bearer token');
        expect(sse.reconnect, isFalse);
        expect(sse.reconnectDelay, Duration(seconds: 5));
        expect(sse.maxReconnectAttempts, 3);
        expect(sse.lastEventId, 'evt-42');
        sse.dispose();
      });
    });

    group('connection', () {
      test('connects to SSE endpoint', () async {
        server.listen((request) {
          request.response.headers
            ..set('Content-Type', 'text/event-stream')
            ..set('Cache-Control', 'no-cache');
          request.response.statusCode = 200;
          request.response.write('data: hello\n\n');
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        await sse.connect();
        expect(sse.isConnected, isTrue);

        // Wait for stream to finish
        await Future<void>.delayed(Duration(milliseconds: 100));
      });

      test('receives simple data event', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          request.response.write('data: hello world\n\n');
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        final received = Completer<SseEvent>();
        sse.events.listen(received.complete);

        await sse.connect();
        final event = await received.future.timeout(Duration(seconds: 2));

        expect(event.event, 'message');
        expect(event.data, 'hello world');
        expect(event.id, isNull);
      });

      test('receives named event', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          request.response.write('event: quest_update\ndata: {"id":1}\n\n');
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        final received = Completer<SseEvent>();
        sse.events.listen(received.complete);

        await sse.connect();
        final event = await received.future.timeout(Duration(seconds: 2));

        expect(event.event, 'quest_update');
        expect(event.data, '{"id":1}');
        expect(event.jsonData, {'id': 1});
      });

      test('receives event with ID', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          request.response.write('id: evt-7\ndata: payload\n\n');
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        final received = Completer<SseEvent>();
        sse.events.listen(received.complete);

        await sse.connect();
        final event = await received.future.timeout(Duration(seconds: 2));

        expect(event.id, 'evt-7');
        expect(event.data, 'payload');
        // Last event ID should be updated
        expect(sse.lastEventId, 'evt-7');
      });

      test('receives multiple events', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          request.response.write(
            'data: first\n\n'
            'data: second\n\n'
            'data: third\n\n',
          );
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        final events = <SseEvent>[];
        sse.events.listen(events.add);

        await sse.connect();
        await Future<void>.delayed(Duration(milliseconds: 200));

        expect(events, hasLength(3));
        expect(events[0].data, 'first');
        expect(events[1].data, 'second');
        expect(events[2].data, 'third');
      });

      test('handles multi-line data', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          request.response.write(
            'data: line1\n'
            'data: line2\n'
            'data: line3\n\n',
          );
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        final received = Completer<SseEvent>();
        sse.events.listen(received.complete);

        await sse.connect();
        final event = await received.future.timeout(Duration(seconds: 2));

        expect(event.data, 'line1\nline2\nline3');
      });

      test('ignores comment lines', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          request.response.write(
            ': this is a comment\n'
            'data: actual data\n\n',
          );
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        final received = Completer<SseEvent>();
        sse.events.listen(received.complete);

        await sse.connect();
        final event = await received.future.timeout(Duration(seconds: 2));

        expect(event.data, 'actual data');
      });

      test('handles field without value', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          // 'data' without colon = empty data line
          request.response.write('data\n\n');
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        final received = Completer<SseEvent>();
        sse.events.listen(received.complete);

        await sse.connect();
        final event = await received.future.timeout(Duration(seconds: 2));

        expect(event.data, '');
      });
    });

    group('reconnection', () {
      test('sends Last-Event-ID on reconnect', () async {
        var requestCount = 0;
        String? receivedLastEventId;

        server.listen((request) {
          requestCount++;
          if (requestCount == 1) {
            request.response.headers.set('Content-Type', 'text/event-stream');
            request.response.statusCode = 200;
            request.response.write('id: evt-99\ndata: initial\n\n');
            request.response.close();
          } else {
            receivedLastEventId = request.headers.value('Last-Event-ID');
            request.response.headers.set('Content-Type', 'text/event-stream');
            request.response.statusCode = 200;
            request.response.write('data: resumed\n\n');
            request.response.close();
          }
        });

        final sse = EnvoySse(
          sseUrl,
          reconnect: true,
          reconnectDelay: Duration(milliseconds: 50),
        );
        addTearDown(sse.dispose);

        await sse.connect();
        await Future<void>.delayed(Duration(milliseconds: 500));

        expect(receivedLastEventId, 'evt-99');
      });

      test('stops after maxReconnectAttempts', () async {
        var requestCount = 0;

        server.listen((request) {
          requestCount++;
          request.response.statusCode = 500;
          request.response.close();
        });

        final sse = EnvoySse(
          sseUrl,
          reconnect: true,
          reconnectDelay: Duration(milliseconds: 30),
          maxReconnectAttempts: 2,
        );
        addTearDown(sse.dispose);

        try {
          await sse.connect();
        } catch (_) {
          // Expected — server returns 500
        }

        await Future<void>.delayed(Duration(milliseconds: 500));

        // Should have stopped reconnecting
        expect(requestCount, lessThanOrEqualTo(4));
      });

      test('does not reconnect when reconnect is false', () async {
        var requestCount = 0;

        server.listen((request) {
          requestCount++;
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          request.response.write('data: bye\n\n');
          request.response.close();
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        await sse.connect();
        await Future<void>.delayed(Duration(milliseconds: 200));

        expect(requestCount, 1);
      });
    });

    group('close and dispose', () {
      test('close stops the connection', () async {
        server.listen((request) {
          request.response.headers.set('Content-Type', 'text/event-stream');
          request.response.statusCode = 200;
          // Keep connection open
          Timer.periodic(Duration(milliseconds: 50), (timer) {
            try {
              request.response.write(': keep-alive\n\n');
            } catch (_) {
              timer.cancel();
            }
          });
        });

        final sse = EnvoySse(sseUrl, reconnect: false);
        addTearDown(sse.dispose);

        await sse.connect();
        expect(sse.isConnected, isTrue);

        await sse.close();
        expect(sse.isConnected, isFalse);
      });

      test('throws StateError on connect after close', () async {
        final sse = EnvoySse(sseUrl);
        await sse.close();

        expect(() => sse.connect(), throwsA(isA<StateError>()));
        sse.dispose();
      });
    });
  });

  group('SseEvent', () {
    test('creates with required data', () {
      final event = SseEvent(data: 'hello');
      expect(event.event, 'message');
      expect(event.data, 'hello');
      expect(event.id, isNull);
    });

    test('creates with all fields', () {
      final event = SseEvent(
        event: 'update',
        data: '{"key":"value"}',
        id: 'evt-1',
      );
      expect(event.event, 'update');
      expect(event.data, '{"key":"value"}');
      expect(event.id, 'evt-1');
    });

    test('jsonData parses JSON', () {
      final event = SseEvent(data: '{"count": 42}');
      expect(event.jsonData, {'count': 42});
    });

    test('jsonData throws on invalid JSON', () {
      final event = SseEvent(data: 'not json');
      expect(() => event.jsonData, throwsA(isA<FormatException>()));
    });

    test('toString includes event type and data', () {
      final event = SseEvent(data: 'hello', event: 'greet');
      expect(event.toString(), contains('greet'));
      expect(event.toString(), contains('hello'));
    });

    test('toString includes id when present', () {
      final event = SseEvent(data: 'hello', id: 'x');
      expect(event.toString(), contains('id=x'));
    });

    test('toString omits id when null', () {
      final event = SseEvent(data: 'hello');
      expect(event.toString(), isNot(contains('id=')));
    });
  });
}
