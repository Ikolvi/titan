import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Tether', () {
    setUp(() {
      Tether.reset();
    });

    tearDown(() {
      Tether.reset();
    });

    test('register and call a handler', () async {
      Tether.register<int, String>('format', (value) async => 'Value: $value');

      final result = await Tether.call<int, String>('format', 42);
      expect(result, 'Value: 42');
    });

    test('has checks registration', () {
      expect(Tether.has('test'), isFalse);

      Tether.register<String, String>('test', (req) async => req);
      expect(Tether.has('test'), isTrue);
    });

    test('names returns registered channel names', () {
      Tether.register<int, int>('double', (n) async => n * 2);
      Tether.register<String, int>('length', (s) async => s.length);

      expect(Tether.names, containsAll(['double', 'length']));
    });

    test('unregister removes handler', () async {
      Tether.register<int, int>('test', (n) async => n);
      expect(Tether.has('test'), isTrue);

      Tether.unregister('test');
      expect(Tether.has('test'), isFalse);
    });

    test('call throws on unregistered channel', () {
      expect(
        () => Tether.call<int, int>('missing', 1),
        throwsA(isA<StateError>()),
      );
    });

    test('tryCall returns null on unregistered channel', () async {
      final result = await Tether.tryCall<int, int>('missing', 1);
      expect(result, isNull);
    });

    test('tryCall returns value on registered channel', () async {
      Tether.register<int, int>('identity', (n) async => n);

      final result = await Tether.tryCall<int, int>('identity', 42);
      expect(result, 42);
    });

    test('timeout causes TimeoutException', () {
      Tether.register<int, int>('slow', (n) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return n;
      });

      expect(
        () => Tether.call<int, int>(
          'slow',
          1,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('register with default timeout', () {
      Tether.register<int, int>('slow-default', (n) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return n;
      }, timeout: const Duration(milliseconds: 50));

      expect(
        () => Tether.call<int, int>('slow-default', 1),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('reset clears all registrations', () {
      Tether.register<int, int>('a', (n) async => n);
      Tether.register<int, int>('b', (n) async => n);

      Tether.reset();

      expect(Tether.has('a'), isFalse);
      expect(Tether.has('b'), isFalse);
      expect(Tether.names, isEmpty);
    });

    test('multiple channels work independently', () async {
      Tether.register<int, int>('double', (n) async => n * 2);
      Tether.register<int, int>('triple', (n) async => n * 3);
      Tether.register<String, int>('length', (s) async => s.length);

      expect(await Tether.call<int, int>('double', 5), 10);
      expect(await Tether.call<int, int>('triple', 5), 15);
      expect(await Tether.call<String, int>('length', 'hello'), 5);
    });

    test('handler can transform types', () async {
      Tether.register<Map<String, dynamic>, String>(
        'greet',
        (data) async => 'Hello, ${data['name']}!',
      );

      final result = await Tether.call<Map<String, dynamic>, String>('greet', {
        'name': 'Titan',
      });
      expect(result, 'Hello, Titan!');
    });

    test('handler errors propagate', () async {
      Tether.register<int, int>(
        'error',
        (n) async => throw Exception('Handler error'),
      );

      expect(
        () => Tether.call<int, int>('error', 1),
        throwsA(isA<Exception>()),
      );
    });
  });
}
