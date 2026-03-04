import 'dart:async';

import 'package:test/test.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Tether', () {
    setUp(() {
      Tether.resetGlobal();
    });

    tearDown(() {
      Tether.resetGlobal();
    });

    // ---- Instance-based tests ----

    test('instance: register and call a handler', () async {
      final t = Tether(name: 'test');
      t.register<int, String>('format', (value) async => 'Value: $value');

      final result = await t.call<int, String>('format', 42);
      expect(result, 'Value: 42');
      t.dispose();
    });

    test('instance: has checks registration', () {
      final t = Tether();
      expect(t.has('test'), isFalse);

      t.register<String, String>('test', (req) async => req);
      expect(t.has('test'), isTrue);
      t.dispose();
    });

    test('instance: names returns registered channel names', () {
      final t = Tether();
      t.register<int, int>('double', (n) async => n * 2);
      t.register<String, int>('length', (s) async => s.length);

      expect(t.names, containsAll(['double', 'length']));
      t.dispose();
    });

    test('instance: unregister removes handler', () {
      final t = Tether();
      t.register<int, int>('test', (n) async => n);
      expect(t.has('test'), isTrue);

      t.unregister('test');
      expect(t.has('test'), isFalse);
      t.dispose();
    });

    test('instance: call throws on unregistered channel', () {
      final t = Tether();
      expect(() => t.call<int, int>('missing', 1), throwsA(isA<StateError>()));
      t.dispose();
    });

    test('instance: tryCall returns null on unregistered channel', () async {
      final t = Tether();
      final result = await t.tryCall<int, int>('missing', 1);
      expect(result, isNull);
      t.dispose();
    });

    test('instance: tryCall returns value on registered channel', () async {
      final t = Tether();
      t.register<int, int>('identity', (n) async => n);

      final result = await t.tryCall<int, int>('identity', 42);
      expect(result, 42);
      t.dispose();
    });

    test('instance: timeout causes TimeoutException', () {
      final t = Tether();
      t.register<int, int>('slow', (n) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return n;
      });

      expect(
        () => t.call<int, int>(
          'slow',
          1,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
      t.dispose();
    });

    test('instance: register with default timeout', () {
      final t = Tether();
      t.register<int, int>('slow-default', (n) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return n;
      }, timeout: const Duration(milliseconds: 50));

      expect(
        () => t.call<int, int>('slow-default', 1),
        throwsA(isA<TimeoutException>()),
      );
      t.dispose();
    });

    test('instance: reset clears all registrations and state', () {
      final t = Tether();
      t.register<int, int>('a', (n) async => n);
      t.register<int, int>('b', (n) async => n);

      t.reset();

      expect(t.has('a'), isFalse);
      expect(t.has('b'), isFalse);
      expect(t.names, isEmpty);
      expect(t.registeredCount, 0);
      expect(t.callCount, 0);
      t.dispose();
    });

    test('instance: multiple channels work independently', () async {
      final t = Tether();
      t.register<int, int>('double', (n) async => n * 2);
      t.register<int, int>('triple', (n) async => n * 3);
      t.register<String, int>('length', (s) async => s.length);

      expect(await t.call<int, int>('double', 5), 10);
      expect(await t.call<int, int>('triple', 5), 15);
      expect(await t.call<String, int>('length', 'hello'), 5);
      t.dispose();
    });

    test('instance: handler errors propagate and track errorCount', () async {
      final t = Tether();
      t.register<int, int>(
        'error',
        (n) async => throw Exception('Handler error'),
      );

      expect(() => t.call<int, int>('error', 1), throwsA(isA<Exception>()));

      // Let microtask settle
      await Future<void>.delayed(Duration.zero);
      expect(t.errorCount, 1);
      t.dispose();
    });

    // ---- Reactive state tests ----

    test('tracks registeredCount reactively', () {
      final t = Tether();
      expect(t.registeredCount, 0);

      t.register<int, int>('a', (n) async => n);
      expect(t.registeredCount, 1);

      t.register<int, int>('b', (n) async => n);
      expect(t.registeredCount, 2);

      t.unregister('a');
      expect(t.registeredCount, 1);
      t.dispose();
    });

    test('tracks callCount and lastCallTime', () async {
      final t = Tether();
      t.register<int, int>('echo', (n) async => n);

      expect(t.callCount, 0);
      expect(t.lastCallTime, isNull);

      await t.call<int, int>('echo', 1);
      expect(t.callCount, 1);
      expect(t.lastCallTime, isNotNull);

      await t.call<int, int>('echo', 2);
      expect(t.callCount, 2);
      t.dispose();
    });

    test('managedNodes returns reactive cores', () {
      final t = Tether();
      expect(t.managedNodes, hasLength(2));
      t.dispose();
    });

    test('dispose makes Tether unusable', () {
      final t = Tether();
      t.dispose();
      expect(t.isDisposed, isTrue);

      expect(
        () => t.register<int, int>('a', (n) async => n),
        throwsA(isA<StateError>()),
      );
      expect(() => t.call<int, int>('a', 1), throwsA(isA<StateError>()));
    });

    test('dispose is idempotent', () {
      final t = Tether();
      t.dispose();
      t.dispose(); // no throw
    });

    test('toString reflects state', () async {
      final t = Tether(name: 'myRpc');
      t.register<int, int>('x', (n) async => n);
      await t.call<int, int>('x', 1);

      final s = t.toString();
      expect(s, contains('myRpc'));
      expect(s, contains('handlers: 1'));
      expect(s, contains('calls: 1'));
      t.dispose();
    });

    // ---- Static convenience API tests ----

    test('static: registerGlobal and callGlobal', () async {
      Tether.registerGlobal<int, String>(
        'format',
        (value) async => 'V: $value',
      );

      final result = await Tether.callGlobal<int, String>('format', 42);
      expect(result, 'V: 42');
    });

    test('static: hasGlobal and globalNames', () {
      Tether.registerGlobal<int, int>('double', (n) async => n * 2);
      expect(Tether.hasGlobal('double'), isTrue);
      expect(Tether.globalNames, contains('double'));
    });

    test('static: unregisterGlobal', () {
      Tether.registerGlobal<int, int>('test', (n) async => n);
      expect(Tether.unregisterGlobal('test'), isTrue);
      expect(Tether.hasGlobal('test'), isFalse);
    });

    test('static: tryCallGlobal returns null on unregistered', () async {
      final result = await Tether.tryCallGlobal<int, int>('missing', 1);
      expect(result, isNull);
    });

    test('static: resetGlobal clears all', () {
      Tether.registerGlobal<int, int>('a', (n) async => n);
      Tether.resetGlobal();
      expect(Tether.hasGlobal('a'), isFalse);
    });

    test('handler transforms types', () async {
      final t = Tether();
      t.register<Map<String, dynamic>, String>(
        'greet',
        (data) async => 'Hello, ${data['name']}!',
      );

      final result = await t.call<Map<String, dynamic>, String>('greet', {
        'name': 'Titan',
      });
      expect(result, 'Hello, Titan!');
      t.dispose();
    });

    test('re-registering replaces handler', () async {
      final t = Tether();
      t.register<int, int>('op', (n) async => n * 2);
      expect(await t.call<int, int>('op', 3), 6);

      t.register<int, int>('op', (n) async => n * 10);
      expect(await t.call<int, int>('op', 3), 30);
      // registeredCount should not increase on replace
      expect(t.registeredCount, 1);
      t.dispose();
    });
  });
}
