import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Relic — Persistence & Hydration', () {
    late InMemoryRelicAdapter adapter;

    setUp(() {
      adapter = InMemoryRelicAdapter();
    });

    // -----------------------------------------------------------------------
    // Hydrate
    // -----------------------------------------------------------------------

    test('hydrate restores values from storage', () async {
      final count = TitanState<int>(0);
      adapter.store['titan:count'] = '42';

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      await relic.hydrate();
      expect(count.peek(), 42);

      relic.dispose();
      count.dispose();
    });

    test('hydrate skips missing keys', () async {
      final name = TitanState<String>('default');

      final relic = Relic(
        adapter: adapter,
        entries: {
          'name': RelicEntry(
            core: name,
            toJson: (v) => v,
            fromJson: (v) => v as String,
          ),
        },
      );

      await relic.hydrate();
      expect(name.peek(), 'default'); // unchanged

      relic.dispose();
      name.dispose();
    });

    test('hydrate skips invalid JSON gracefully', () async {
      final count = TitanState<int>(0);
      adapter.store['titan:count'] = 'not-valid-json!!!';

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      await relic.hydrate();
      expect(count.peek(), 0); // unchanged

      relic.dispose();
      count.dispose();
    });

    test('hydrateKey restores a single key', () async {
      final a = TitanState<int>(0);
      final b = TitanState<int>(0);
      adapter.store['titan:a'] = '10';
      adapter.store['titan:b'] = '20';

      final relic = Relic(
        adapter: adapter,
        entries: {
          'a': RelicEntry(core: a, toJson: (v) => v, fromJson: (v) => v as int),
          'b': RelicEntry(core: b, toJson: (v) => v, fromJson: (v) => v as int),
        },
      );

      final result = await relic.hydrateKey('a');
      expect(result, isTrue);
      expect(a.peek(), 10);
      expect(b.peek(), 0); // not hydrated

      relic.dispose();
      a.dispose();
      b.dispose();
    });

    test('hydrateKey returns false for unknown key', () async {
      final relic = Relic(adapter: adapter, entries: {});
      final result = await relic.hydrateKey('unknown');
      expect(result, isFalse);
      relic.dispose();
    });

    // -----------------------------------------------------------------------
    // Persist
    // -----------------------------------------------------------------------

    test('persist saves all values to storage', () async {
      final count = TitanState<int>(42);
      final name = TitanState<String>('Alice');

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
          'name': RelicEntry(
            core: name,
            toJson: (v) => v,
            fromJson: (v) => v as String,
          ),
        },
      );

      await relic.persist();

      expect(adapter.store['titan:count'], '42');
      expect(adapter.store['titan:name'], '"Alice"');

      relic.dispose();
      count.dispose();
      name.dispose();
    });

    test('persistKey saves a single key', () async {
      final count = TitanState<int>(7);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      final result = await relic.persistKey('count');
      expect(result, isTrue);
      expect(adapter.store['titan:count'], '7');

      relic.dispose();
      count.dispose();
    });

    test('persistKey returns false for unknown key', () async {
      final relic = Relic(adapter: adapter, entries: {});
      final result = await relic.persistKey('unknown');
      expect(result, isFalse);
      relic.dispose();
    });

    // -----------------------------------------------------------------------
    // Round-trip
    // -----------------------------------------------------------------------

    test('persist then hydrate round-trips correctly', () async {
      final count = TitanState<int>(99);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      await relic.persist();

      // Reset the core
      count.silent(0);
      expect(count.peek(), 0);

      // Hydrate from storage
      await relic.hydrate();
      expect(count.peek(), 99);

      relic.dispose();
      count.dispose();
    });

    test('complex types round-trip with custom serialization', () async {
      final items = TitanState<List<String>>(['a', 'b']);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'items': RelicEntry<List<String>>(
            core: items,
            toJson: (v) => v,
            fromJson: (v) => (v as List).cast<String>(),
          ),
        },
      );

      await relic.persist();
      items.silent([]);
      await relic.hydrate();

      expect(items.peek(), ['a', 'b']);

      relic.dispose();
      items.dispose();
    });

    // -----------------------------------------------------------------------
    // Auto-save
    // -----------------------------------------------------------------------

    test('enableAutoSave persists on Core change', () async {
      final count = TitanState<int>(0);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      relic.enableAutoSave();
      count.value = 42;

      // Auto-save is async — give it a tick
      await Future.delayed(const Duration(milliseconds: 10));
      expect(adapter.store['titan:count'], '42');

      relic.dispose();
      count.dispose();
    });

    test('disableAutoSave stops persisting', () async {
      final count = TitanState<int>(0);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      relic.enableAutoSave();
      count.value = 1;
      await Future.delayed(const Duration(milliseconds: 10));

      relic.disableAutoSave();
      count.value = 2;
      await Future.delayed(const Duration(milliseconds: 10));

      expect(adapter.store['titan:count'], '1'); // Old value persisted

      relic.dispose();
      count.dispose();
    });

    // -----------------------------------------------------------------------
    // Clear
    // -----------------------------------------------------------------------

    test('clear removes all persisted data', () async {
      final count = TitanState<int>(42);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      await relic.persist();
      expect(adapter.store.containsKey('titan:count'), isTrue);

      await relic.clear();
      expect(adapter.store.containsKey('titan:count'), isFalse);

      relic.dispose();
      count.dispose();
    });

    test('clearKey removes a single key', () async {
      final a = TitanState<int>(1);
      final b = TitanState<int>(2);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'a': RelicEntry(core: a, toJson: (v) => v, fromJson: (v) => v as int),
          'b': RelicEntry(core: b, toJson: (v) => v, fromJson: (v) => v as int),
        },
      );

      await relic.persist();
      await relic.clearKey('a');

      expect(adapter.store.containsKey('titan:a'), isFalse);
      expect(adapter.store.containsKey('titan:b'), isTrue);

      relic.dispose();
      a.dispose();
      b.dispose();
    });

    test('clearKey returns false for unknown key', () async {
      final relic = Relic(adapter: adapter, entries: {});
      final result = await relic.clearKey('unknown');
      expect(result, isFalse);
      relic.dispose();
    });

    // -----------------------------------------------------------------------
    // Prefix
    // -----------------------------------------------------------------------

    test('custom prefix is applied', () async {
      final count = TitanState<int>(5);

      final relic = Relic(
        adapter: adapter,
        prefix: 'app:',
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      await relic.persist();
      expect(adapter.store.containsKey('app:count'), isTrue);
      expect(adapter.store['app:count'], '5');

      relic.dispose();
      count.dispose();
    });

    // -----------------------------------------------------------------------
    // Keys
    // -----------------------------------------------------------------------

    test('keys returns registered key names', () {
      final relic = Relic(
        adapter: adapter,
        entries: {
          'a': RelicEntry(
            core: TitanState(0),
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
          'b': RelicEntry(
            core: TitanState(''),
            toJson: (v) => v,
            fromJson: (v) => v as String,
          ),
        },
      );

      expect(relic.keys, containsAll(['a', 'b']));
      relic.dispose();
    });

    // -----------------------------------------------------------------------
    // Dispose
    // -----------------------------------------------------------------------

    test('dispose stops auto-save', () async {
      final count = TitanState<int>(0);

      final relic = Relic(
        adapter: adapter,
        entries: {
          'count': RelicEntry(
            core: count,
            toJson: (v) => v,
            fromJson: (v) => v as int,
          ),
        },
      );

      relic.enableAutoSave();
      relic.dispose();

      count.value = 99;
      await Future.delayed(const Duration(milliseconds: 10));

      expect(adapter.store.containsKey('titan:count'), isFalse);

      count.dispose();
    });
  });
}
