import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _ApiPillar extends Pillar {
  late final apiBreaker = bulwark<String>(
    failureThreshold: 2,
    resetTimeout: Duration(milliseconds: 100),
    name: 'api',
  );
}

void main() {
  setUp(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  tearDown(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  group('Bulwark', () {
    test('starts in closed state', () {
      final breaker = Bulwark<String>(failureThreshold: 3);

      expect(breaker.state, BulwarkState.closed);
      expect(breaker.isClosed, isTrue);
      expect(breaker.isOpen, isFalse);
      expect(breaker.isHalfOpen, isFalse);
      expect(breaker.failureCount, 0);
      expect(breaker.lastError, isNull);

      breaker.dispose();
    });

    test('successful call keeps circuit closed', () async {
      final breaker = Bulwark<String>(failureThreshold: 3);

      final result = await breaker.call(() async => 'data');

      expect(result, 'data');
      expect(breaker.state, BulwarkState.closed);
      expect(breaker.failureCount, 0);

      breaker.dispose();
    });

    test('failures increment failure count', () async {
      final breaker = Bulwark<String>(failureThreshold: 3);

      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}

      expect(breaker.failureCount, 1);
      expect(breaker.state, BulwarkState.closed);

      breaker.dispose();
    });

    test('opens after reaching failure threshold', () async {
      final breaker = Bulwark<String>(failureThreshold: 2);

      for (var i = 0; i < 2; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }

      expect(breaker.state, BulwarkState.open);
      expect(breaker.failureCount, 2);
      expect(breaker.lastError, isA<Exception>());

      breaker.dispose();
    });

    test('throws BulwarkOpenException when circuit is open', () async {
      final breaker = Bulwark<String>(failureThreshold: 1);

      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}

      expect(breaker.isOpen, isTrue);

      expect(
        () => breaker.call(() async => 'data'),
        throwsA(isA<BulwarkOpenException>()),
      );

      breaker.dispose();
    });

    test('BulwarkOpenException has descriptive toString', () {
      const exception = BulwarkOpenException(
        failureCount: 3,
        lastError: 'network error',
      );

      expect(exception.toString(), contains('3'));
      expect(exception.toString(), contains('network error'));
    });

    test('transitions to half-open after resetTimeout', () async {
      final breaker = Bulwark<String>(
        failureThreshold: 1,
        resetTimeout: Duration(milliseconds: 50),
      );

      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}

      expect(breaker.isOpen, isTrue);

      // Wait for reset timeout
      await Future<void>.delayed(Duration(milliseconds: 80));

      expect(breaker.state, BulwarkState.halfOpen);

      breaker.dispose();
    });

    test('closes on successful half-open probe', () async {
      final breaker = Bulwark<String>(
        failureThreshold: 1,
        resetTimeout: Duration(milliseconds: 50),
      );

      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}

      // Wait for half-open
      await Future<void>.delayed(Duration(milliseconds: 80));
      expect(breaker.isHalfOpen, isTrue);

      // Successful probe
      final result = await breaker.call(() async => 'recovered');

      expect(result, 'recovered');
      expect(breaker.state, BulwarkState.closed);
      expect(breaker.failureCount, 0);

      breaker.dispose();
    });

    test('reopens on failed half-open probe', () async {
      final breaker = Bulwark<String>(
        failureThreshold: 1,
        resetTimeout: Duration(milliseconds: 50),
      );

      try {
        await breaker.call(() async => throw Exception('fail 1'));
      } catch (_) {}

      await Future<void>.delayed(Duration(milliseconds: 80));
      expect(breaker.isHalfOpen, isTrue);

      // Failed probe
      try {
        await breaker.call(() async => throw Exception('fail 2'));
      } catch (_) {}

      expect(breaker.isOpen, isTrue);

      breaker.dispose();
    });

    test('success resets failure count', () async {
      final breaker = Bulwark<String>(failureThreshold: 3);

      // 2 failures
      for (var i = 0; i < 2; i++) {
        try {
          await breaker.call(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.failureCount, 2);

      // 1 success resets
      await breaker.call(() async => 'ok');
      expect(breaker.failureCount, 0);

      breaker.dispose();
    });

    test('onOpen/onClose/onHalfOpen callbacks fire', () async {
      final events = <String>[];

      final breaker = Bulwark<String>(
        failureThreshold: 1,
        resetTimeout: Duration(milliseconds: 50),
        onOpen: (e) => events.add('open'),
        onClose: () => events.add('close'),
        onHalfOpen: () => events.add('halfOpen'),
      );

      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}
      expect(events, ['open']);

      await Future<void>.delayed(Duration(milliseconds: 80));
      expect(events, ['open', 'halfOpen']);

      await breaker.call(() async => 'ok');
      expect(events, ['open', 'halfOpen', 'close']);

      breaker.dispose();
    });

    test('reset() restores to closed state', () async {
      final breaker = Bulwark<String>(failureThreshold: 1);

      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}

      expect(breaker.isOpen, isTrue);

      breaker.reset();

      expect(breaker.state, BulwarkState.closed);
      expect(breaker.failureCount, 0);
      expect(breaker.lastError, isNull);

      breaker.dispose();
    });

    test('trip() manually opens the circuit', () {
      final breaker = Bulwark<String>(failureThreshold: 99);

      breaker.trip();

      expect(breaker.isOpen, isTrue);

      breaker.dispose();
    });

    test('state Core is reactive', () async {
      final breaker = Bulwark<String>(failureThreshold: 1);

      final states = <BulwarkState>[];
      breaker.stateCore.listen((s) => states.add(s));

      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}

      expect(states, [BulwarkState.open]);

      breaker.dispose();
    });

    test('toString() includes state info', () {
      final breaker = Bulwark<String>(failureThreshold: 3);

      expect(breaker.toString(), contains('Bulwark'));
      expect(breaker.toString(), contains('closed'));

      breaker.dispose();
    });
  });

  group('Bulwark in Pillar', () {
    test('Pillar.bulwark() creates managed circuit breaker', () async {
      final pillar = _ApiPillar();
      pillar.initialize();

      expect(pillar.apiBreaker.isClosed, isTrue);

      final result = await pillar.apiBreaker.call(() async => 'data');
      expect(result, 'data');

      pillar.dispose();
    });

    test('Bulwark is disposed with Pillar', () {
      final pillar = _ApiPillar();
      pillar.initialize();

      final stateCore = pillar.apiBreaker.stateCore;
      pillar.dispose();

      expect(stateCore.isDisposed, isTrue);
    });
  });
}
