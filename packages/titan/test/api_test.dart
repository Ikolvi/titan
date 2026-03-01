import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  tearDown(() => Titan.reset());

  group('Core<T> (standalone)', () {
    test('creates a reactive value', () {
      final c = Core(42);
      expect(c.value, 42);

      c.value = 100;
      expect(c.value, 100);

      c.dispose();
    });

    test('notifies dependents', () {
      final c = Core(0);
      final values = <int>[];
      c.listen((v) => values.add(v));

      c.value = 1;
      c.value = 2;
      c.value = 3;

      expect(values, [1, 2, 3]);
      c.dispose();
    });

    test('Core<T> is a type alias for TitanState<T>', () {
      final c = Core(0);
      expect(c, isA<TitanState<int>>());
      expect(c, isA<Core<int>>());
      c.dispose();
    });
  });

  group('Derived<T> (standalone)', () {
    test('derives value from Core', () {
      final count = Core(5);
      final doubled = Derived(() => count.value * 2);

      expect(doubled.value, 10);

      count.value = 20;
      expect(doubled.value, 40);

      count.dispose();
      doubled.dispose();
    });

    test('Derived<T> is a type alias for TitanComputed<T>', () {
      final d = Derived(() => 42);
      expect(d, isA<TitanComputed<int>>());
      expect(d, isA<Derived<int>>());
      d.dispose();
    });

    test('chains derived values', () {
      final a = Core(2);
      final b = Core(3);
      final sum = Derived(() => a.value + b.value);
      final doubled = Derived(() => sum.value * 2);

      expect(doubled.value, 10);

      a.value = 10;
      expect(doubled.value, 26);

      a.dispose();
      b.dispose();
      sum.dispose();
      doubled.dispose();
    });
  });

  group('titanBatch()', () {
    test('groups updates into single notification', () {
      final a = Core(0);
      final b = Core(0);
      int listenerCalls = 0;

      a.addListener(() => listenerCalls++);

      titanBatch(() {
        a.value = 1;
        a.value = 2;
        a.value = 3;
      });

      expect(listenerCalls, 1);
      expect(a.value, 3);
      expect(b.value, 0);

      a.dispose();
      b.dispose();
    });
  });

  group('Pillar', () {
    test('core() creates managed state', () {
      final pillar = _TestCounterPillar();

      expect(pillar.count.value, 0);
      pillar.count.value = 5;
      expect(pillar.count.value, 5);

      pillar.dispose();
    });

    test('derived() creates computed values', () {
      final pillar = _TestCounterPillar();

      expect(pillar.doubled.value, 0);
      pillar.count.value = 5;
      expect(pillar.doubled.value, 10);

      pillar.dispose();
    });

    test('strike() batches mutations', () {
      final pillar = _TestCounterPillar();
      int notifications = 0;
      pillar.count.addListener(() => notifications++);

      pillar.incrementBy(5);

      expect(pillar.count.value, 5);
      expect(notifications, 1);

      pillar.dispose();
    });

    test('watch() creates managed effects', () {
      final pillar = _TestWatchPillar();
      pillar.initialize();

      expect(pillar.sideEffectLog, ['value: 0']);

      pillar.data.value = 42;
      expect(pillar.sideEffectLog, ['value: 0', 'value: 42']);

      pillar.dispose();
    });

    test('onInit() called on initialize()', () {
      final pillar = _TestLifecyclePillar();
      expect(pillar.initCalled, false);

      pillar.initialize();
      expect(pillar.initCalled, true);

      pillar.dispose();
    });

    test('onDispose() called on dispose()', () {
      final pillar = _TestLifecyclePillar();
      pillar.initialize();
      expect(pillar.disposeCalled, false);

      pillar.dispose();
      expect(pillar.disposeCalled, true);
    });

    test('dispose cleans up all managed nodes', () {
      final pillar = _TestCounterPillar();
      final count = pillar.count;
      final doubled = pillar.doubled;

      pillar.dispose();

      expect(count.isDisposed, true);
      expect(doubled.isDisposed, true);
    });

    test('multiple Pillars have independent state', () {
      final a = _TestCounterPillar();
      final b = _TestCounterPillar();

      a.increment();
      expect(a.count.value, 1);
      expect(b.count.value, 0);

      a.dispose();
      b.dispose();
    });
  });

  group('Titan global registry', () {
    test('put and get', () {
      Titan.put('hello');
      expect(Titan.get<String>(), 'hello');
    });

    test('lazy registration', () {
      int createCount = 0;
      Titan.lazy(() {
        createCount++;
        return 42;
      });

      expect(createCount, 0);
      expect(Titan.get<int>(), 42);
      expect(createCount, 1);
      expect(Titan.get<int>(), 42);
      expect(createCount, 1);
    });

    test('has checks availability', () {
      expect(Titan.has<String>(), false);
      Titan.put('test');
      expect(Titan.has<String>(), true);
    });

    test('find returns null if not found', () {
      expect(Titan.find<double>(), isNull);
      Titan.put(3.14);
      expect(Titan.find<double>(), 3.14);
    });

    test('remove unregisters', () {
      Titan.put('hello');
      final removed = Titan.remove<String>();
      expect(removed, 'hello');
      expect(Titan.has<String>(), false);
    });

    test('reset clears all', () {
      Titan.put('a');
      Titan.put(1);
      Titan.put(true);

      Titan.reset();
      expect(Titan.has<String>(), false);
      expect(Titan.has<int>(), false);
      expect(Titan.has<bool>(), false);
    });

    test('throws on missing registration', () {
      expect(() => Titan.get<double>(), throwsStateError);
    });

    test('auto-initializes Pillars on put', () {
      final pillar = _TestLifecyclePillar();
      expect(pillar.isInitialized, false);

      Titan.put(pillar);
      expect(pillar.isInitialized, true);
    });

    test('auto-disposes Pillars on remove', () {
      final pillar = _TestLifecyclePillar();
      Titan.put(pillar);
      expect(pillar.isDisposed, false);

      Titan.remove<_TestLifecyclePillar>();
      expect(pillar.isDisposed, true);
    });

    test('auto-disposes Pillars on reset', () {
      final pillar = _TestLifecyclePillar();
      Titan.put(pillar);

      Titan.reset();
      expect(pillar.isDisposed, true);
    });

    test('forge registers Pillar by runtimeType', () {
      final pillar = _TestCounterPillar();
      Titan.forge(pillar);

      expect(Titan.has<_TestCounterPillar>(), isTrue);
      expect(Titan.get<_TestCounterPillar>(), same(pillar));
      // Should be auto-initialized
      expect(pillar.isInitialized, isTrue);
    });

    test('removeByType removes and disposes Pillar', () {
      final pillar = _TestLifecyclePillar();
      Titan.forge(pillar);

      final removed = Titan.removeByType(_TestLifecyclePillar);
      expect(removed, same(pillar));
      expect(pillar.isDisposed, isTrue);
      expect(Titan.has<_TestLifecyclePillar>(), isFalse);
    });

    test('lazy factory auto-initializes Pillar on first get', () {
      Titan.lazy<_TestLifecyclePillar>(() => _TestLifecyclePillar());

      final pillar = Titan.get<_TestLifecyclePillar>();
      expect(pillar.isInitialized, isTrue);
    });
  });

  group('Pillar — strikeAsync', () {
    test('strikeAsync() performs async mutation', () async {
      final pillar = _TestAsyncPillar();
      pillar.initialize();

      await pillar.asyncIncrement();
      expect(pillar.count.value, 1);
      pillar.dispose();
    });

    test('strikeAsync() captures error via Vigil and rethrows', () async {
      final pillar = _TestAsyncPillar();
      pillar.initialize();

      expect(() => pillar.asyncFail(), throwsStateError);

      pillar.dispose();
    });
  });

  group('Pillar — watch with immediate', () {
    test('watch(immediate: false) does not run at creation time', () {
      final pillar = _TestDeferredWatchPillar();
      pillar.initialize();

      // With immediate: false the effect does NOT run at creation time
      expect(pillar.watchLog, isEmpty);

      // Since the effect never ran, it has no tracked dependencies,
      // so changing data does not trigger it either.
      pillar.data.value = 1;
      expect(pillar.watchLog, isEmpty);

      pillar.dispose();
    });

    test('watch(immediate: true) runs at creation time (default)', () {
      final pillar = _TestWatchPillar();
      pillar.initialize();

      // Default immediate: true — effect runs immediately
      expect(pillar.sideEffectLog, ['value: 0']);

      pillar.data.value = 1;
      expect(pillar.sideEffectLog, ['value: 0', 'value: 1']);

      pillar.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

class _TestCounterPillar extends Pillar {
  late final count = core(0, name: 'count');
  late final doubled = derived(() => count.value * 2);

  void increment() => strike(() => count.value++);

  void incrementBy(int amount) => strike(() {
    for (int i = 0; i < amount; i++) {
      count.value++;
    }
  });
}

class _TestWatchPillar extends Pillar {
  late final data = core(0);
  final List<String> sideEffectLog = [];

  @override
  void onInit() {
    watch(() {
      sideEffectLog.add('value: ${data.value}');
    });
  }
}

class _TestLifecyclePillar extends Pillar {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  void onInit() {
    initCalled = true;
  }

  @override
  void onDispose() {
    disposeCalled = true;
  }
}

class _TestDeferredWatchPillar extends Pillar {
  late final data = core(0);
  final List<String> watchLog = [];

  @override
  void onInit() {
    watch(() {
      watchLog.add('value: ${data.value}');
    }, immediate: false);
  }
}

class _TestAsyncPillar extends Pillar {
  late final count = core(0);

  Future<void> asyncIncrement() => strikeAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    count.value++;
  });

  Future<void> asyncFail() => strikeAsync(() async {
    throw StateError('async failure');
  });
}
