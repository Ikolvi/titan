import 'package:test/test.dart';
import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

class _CounterPillar extends Pillar {
  late final _count = core(0, name: 'count');

  /// Public read-only view — consumers cannot mutate.
  ReadCore<int> get count => _count;

  late final doubled = derived(() => _count.value * 2);

  void increment() => strike(() => _count.value++);
  void decrement() => strike(() => _count.value--);
  void reset() => strike(() => _count.value = 0);
  void setTo(int v) => strike(() => _count.value = v);
}

class _ClampedPillar extends Pillar {
  late final _health = core<int>(
    100,
    name: 'health',
    conduits: [ClampConduit(min: 0, max: 100)],
  );

  ReadCore<int> get health => _health;

  void damage(int amount) => strike(() => _health.value -= amount);
  void heal(int amount) => strike(() => _health.value += amount);
}

class _MixedPillar extends Pillar {
  // Some Cores are public (for backward compat), some are ReadCore
  late final _privateScore = core(0, name: 'score');
  late final publicName = core('Kael', name: 'name');

  ReadCore<int> get score => _privateScore;

  void addScore(int points) => strike(() => _privateScore.value += points);
}

void main() {
  group('ReadCore', () {
    test('ReadCore type hides the value setter', () {
      final state = TitanState<int>(42);
      final ReadCore<int> readOnly = state;

      // Can read
      expect(readOnly.value, 42);

      // The compiler would reject: readOnly.value = 99;
      // At runtime, verify the interface only exposes the getter:
      expect(readOnly, isA<ReadCore<int>>());
    });

    test('value getter auto-tracks in Derived', () {
      final pillar = _CounterPillar();
      pillar.initialize();

      expect(pillar.doubled.value, 0);

      pillar.increment();
      expect(pillar.count.value, 1);
      expect(pillar.doubled.value, 2);

      pillar.dispose();
    });

    test('peek() returns value without tracking', () {
      final state = TitanState<String>('hello');
      final ReadCore<String> readOnly = state;

      expect(readOnly.peek(), 'hello');
    });

    test('previousValue reflects mutations', () {
      final pillar = _CounterPillar();
      pillar.initialize();

      expect(pillar.count.previousValue, isNull);

      pillar.increment();
      expect(pillar.count.previousValue, 0);
      expect(pillar.count.value, 1);

      pillar.increment();
      expect(pillar.count.previousValue, 1);
      expect(pillar.count.value, 2);

      pillar.dispose();
    });

    test('name is accessible through ReadCore', () {
      final pillar = _CounterPillar();

      expect(pillar.count.name, 'count');

      pillar.dispose();
    });

    test('isDisposed reflects Pillar lifecycle', () {
      final pillar = _CounterPillar();
      pillar.initialize();

      expect(pillar.count.isDisposed, false);

      pillar.dispose();

      expect(pillar.count.isDisposed, true);
    });

    test('listen() works through ReadCore', () {
      final pillar = _CounterPillar();
      pillar.initialize();

      final values = <int>[];
      final unsub = pillar.count.listen((v) => values.add(v));

      pillar.increment();
      pillar.increment();
      pillar.setTo(10);

      expect(values, [1, 2, 10]);

      unsub();

      pillar.increment();
      expect(values, [1, 2, 10]); // No new values after unsub

      pillar.dispose();
    });

    test('select() creates derived projection from ReadCore', () {
      final state = TitanState<Map<String, int>>({'a': 1, 'b': 2});
      final ReadCore<Map<String, int>> readOnly = state;

      final keyA = readOnly.select((m) => m['a']!);
      expect(keyA.value, 1);

      state.value = {'a': 99, 'b': 2};
      expect(keyA.value, 99);

      state.dispose();
      keyA.dispose();
    });

    test(
      'Pillar with ReadCore prevents external mutation at compile level',
      () {
        final pillar = _CounterPillar();
        pillar.initialize();

        // pillar.count is ReadCore<int> — no .value setter
        // This is the compile-time guarantee.
        expect(pillar.count, isA<ReadCore<int>>());

        // Verify the underlying Core is accessible via cast (escape hatch)
        final mutable = pillar.count as Core<int>;
        mutable.value = 42;
        expect(pillar.count.value, 42);

        pillar.dispose();
      },
    );

    test('Conduits still work through ReadCore pattern', () {
      final pillar = _ClampedPillar();
      pillar.initialize();

      expect(pillar.health.value, 100);

      pillar.damage(30);
      expect(pillar.health.value, 70);

      pillar.heal(50); // Would be 120, clamped to 100
      expect(pillar.health.value, 100);

      pillar.damage(200); // Would be -100, clamped to 0
      expect(pillar.health.value, 0);

      pillar.dispose();
    });

    test('mixed public and ReadCore Cores in same Pillar', () {
      final pillar = _MixedPillar();
      pillar.initialize();

      // ReadCore — read only
      expect(pillar.score.value, 0);
      expect(pillar.score, isA<ReadCore<int>>());

      // Public Core — full access (backward compat)
      expect(pillar.publicName.value, 'Kael');
      pillar.publicName.value = 'Aric'; // Direct mutation allowed
      expect(pillar.publicName.value, 'Aric');

      // Score only via method
      pillar.addScore(10);
      expect(pillar.score.value, 10);

      pillar.dispose();
    });

    test('ReadCore standalone (without Pillar)', () {
      final state = TitanState<String>('hello', name: 'greeting');
      final ReadCore<String> readOnly = state;

      expect(readOnly.value, 'hello');
      expect(readOnly.peek(), 'hello');
      expect(readOnly.name, 'greeting');
      expect(readOnly.isDisposed, false);

      state.value = 'world';
      expect(readOnly.value, 'world');
      expect(readOnly.previousValue, 'hello');

      state.dispose();
      expect(readOnly.isDisposed, true);
    });

    test('ReadCore preserves auto-tracking in TitanComputed', () {
      final source = TitanState<int>(5);
      final ReadCore<int> readOnly = source;

      // Derived that reads through ReadCore interface
      final doubled = TitanComputed<int>(() => readOnly.value * 2);

      expect(doubled.value, 10);

      source.value = 7;
      expect(doubled.value, 14);

      source.dispose();
      doubled.dispose();
    });

    test('ReadCore preserves auto-tracking in TitanEffect', () {
      final source = TitanState<int>(0);
      final ReadCore<int> readOnly = source;

      final log = <int>[];
      final effect = TitanEffect(() {
        log.add(readOnly.value);
      });
      // fireImmediately defaults to true, so it already ran once

      expect(log, [0]);

      source.value = 1;
      expect(log, [0, 1]);

      source.value = 2;
      expect(log, [0, 1, 2]);

      effect.dispose();
      source.dispose();
    });

    test('multiple listeners via ReadCore', () {
      final pillar = _CounterPillar();
      pillar.initialize();

      final log1 = <int>[];
      final log2 = <int>[];

      final unsub1 = pillar.count.listen((v) => log1.add(v));
      final unsub2 = pillar.count.listen((v) => log2.add(v));

      pillar.increment();
      expect(log1, [1]);
      expect(log2, [1]);

      unsub1();

      pillar.increment();
      expect(log1, [1]); // Stopped
      expect(log2, [1, 2]); // Still active

      unsub2();
      pillar.dispose();
    });

    test('ReadCore toString delegates to TitanState', () {
      final state = TitanState<int>(42, name: 'answer');
      final ReadCore<int> readOnly = state;

      // toString is on the underlying object, not the interface
      expect(readOnly.toString(), contains('42'));

      state.dispose();
    });
  });
}
