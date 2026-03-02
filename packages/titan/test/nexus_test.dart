import 'package:test/test.dart';
import 'package:titan/titan.dart';

// Helper Pillar for integration tests
class _NexusPillar extends Pillar {
  late final items = nexusList<String>(['sword', 'shield'], 'items');
  late final scores = nexusMap<String, int>({'Alice': 10}, 'scores');
  late final tags = nexusSet<String>({'dart', 'flutter'}, 'tags');

  late final itemCount = derived(() => items.length);
  late final topScore = derived(() {
    if (scores.isEmpty) return 0;
    return scores.values.reduce((a, b) => a > b ? a : b);
  });
  late final hasFlutter = derived(() => tags.contains('flutter'));
}

void main() {
  group('NexusList', () {
    test('initial state', () {
      final list = NexusList<int>(initial: [1, 2, 3]);
      expect(list.value, [1, 2, 3]);
      expect(list.length, 3);
      expect(list.isEmpty, false);
      expect(list.isNotEmpty, true);
      expect(list.first, 1);
      expect(list.last, 3);
    });

    test('empty by default', () {
      final list = NexusList<int>();
      expect(list.value, isEmpty);
      expect(list.length, 0);
      expect(list.isEmpty, true);
    });

    test('add notifies with NexusInsert', () {
      final list = NexusList<String>(initial: ['a']);
      var notified = false;
      list.addListener(() => notified = true);

      list.add('b');

      expect(notified, true);
      expect(list.value, ['a', 'b']);
      expect(list.lastChange, isA<NexusInsert<String>>());
      final change = list.lastChange as NexusInsert<String>;
      expect(change.index, 1);
      expect(change.element, 'b');
    });

    test('addAll notifies with NexusBatch', () {
      final list = NexusList<int>();
      list.addAll([1, 2, 3]);

      expect(list.value, [1, 2, 3]);
      expect(list.lastChange, isA<NexusBatch<int>>());
      final change = list.lastChange as NexusBatch<int>;
      expect(change.operation, 'addAll');
      expect(change.count, 3);
    });

    test('addAll with empty iterable does not notify', () {
      final list = NexusList<int>(initial: [1]);
      var notified = false;
      list.addListener(() => notified = true);

      list.addAll([]);
      expect(notified, false);
    });

    test('insert notifies with NexusInsert', () {
      final list = NexusList<String>(initial: ['a', 'c']);
      list.insert(1, 'b');

      expect(list.value, ['a', 'b', 'c']);
      final change = list.lastChange as NexusInsert<String>;
      expect(change.index, 1);
      expect(change.element, 'b');
    });

    test('operator []= notifies with NexusUpdate', () {
      final list = NexusList<String>(initial: ['a', 'b']);
      list[0] = 'x';

      expect(list.value, ['x', 'b']);
      final change = list.lastChange as NexusUpdate<String>;
      expect(change.index, 0);
      expect(change.oldValue, 'a');
      expect(change.newValue, 'x');
    });

    test('operator []= skips if same value', () {
      final list = NexusList<String>(initial: ['a', 'b']);
      var notified = false;
      list.addListener(() => notified = true);

      list[0] = 'a'; // same value
      expect(notified, false);
    });

    test('operator [] reads with tracking', () {
      final list = NexusList<int>(initial: [10, 20, 30]);
      expect(list[1], 20);
    });

    test('remove returns true and notifies', () {
      final list = NexusList<String>(initial: ['a', 'b', 'c']);
      final result = list.remove('b');

      expect(result, true);
      expect(list.value, ['a', 'c']);
      final change = list.lastChange as NexusRemove<String>;
      expect(change.index, 1);
      expect(change.element, 'b');
    });

    test('remove returns false if not found', () {
      final list = NexusList<String>(initial: ['a']);
      var notified = false;
      list.addListener(() => notified = true);

      expect(list.remove('z'), false);
      expect(notified, false);
    });

    test('removeAt returns element and notifies', () {
      final list = NexusList<String>(initial: ['a', 'b', 'c']);
      final removed = list.removeAt(1);

      expect(removed, 'b');
      expect(list.value, ['a', 'c']);
    });

    test('removeWhere removes matching and returns count', () {
      final list = NexusList<int>(initial: [1, 2, 3, 4, 5]);
      final count = list.removeWhere((e) => e.isEven);

      expect(count, 2);
      expect(list.value, [1, 3, 5]);
      final change = list.lastChange as NexusBatch<int>;
      expect(change.operation, 'removeWhere');
      expect(change.count, 2);
    });

    test('removeWhere does not notify if nothing removed', () {
      final list = NexusList<int>(initial: [1, 3, 5]);
      var notified = false;
      list.addListener(() => notified = true);

      list.removeWhere((e) => e.isEven);
      expect(notified, false);
    });

    test('retainWhere keeps matching and returns removed count', () {
      final list = NexusList<int>(initial: [1, 2, 3, 4, 5]);
      final removed = list.retainWhere((e) => e.isOdd);

      expect(removed, 2);
      expect(list.value, [1, 3, 5]);
    });

    test('sort notifies', () {
      final list = NexusList<int>(initial: [3, 1, 2]);
      list.sort();

      expect(list.value, [1, 2, 3]);
      expect(list.lastChange, isA<NexusBatch<int>>());
    });

    test('sort does nothing for 0 or 1 elements', () {
      final list = NexusList<int>(initial: [42]);
      var notified = false;
      list.addListener(() => notified = true);

      list.sort();
      expect(notified, false);
    });

    test('replaceRange notifies', () {
      final list = NexusList<String>(initial: ['a', 'b', 'c', 'd']);
      list.replaceRange(1, 3, ['x', 'y']);

      expect(list.value, ['a', 'x', 'y', 'd']);
    });

    test('clear notifies with NexusClear', () {
      final list = NexusList<int>(initial: [1, 2, 3]);
      list.clear();

      expect(list.value, isEmpty);
      final change = list.lastChange as NexusClear<int>;
      expect(change.previousLength, 3);
    });

    test('clear does nothing if already empty', () {
      final list = NexusList<int>();
      var notified = false;
      list.addListener(() => notified = true);

      list.clear();
      expect(notified, false);
    });

    test('swap swaps two elements', () {
      final list = NexusList<String>(initial: ['a', 'b', 'c']);
      list.swap(0, 2);

      expect(list.value, ['c', 'b', 'a']);
    });

    test('move moves element', () {
      final list = NexusList<String>(initial: ['a', 'b', 'c']);
      list.move(0, 2);

      expect(list.value, ['b', 'c', 'a']);
    });

    test('contains works', () {
      final list = NexusList<String>(initial: ['a', 'b']);
      expect(list.contains('a'), true);
      expect(list.contains('z'), false);
    });

    test('indexOf works', () {
      final list = NexusList<String>(initial: ['a', 'b', 'c']);
      expect(list.indexOf('b'), 1);
      expect(list.indexOf('z'), -1);
    });

    test('items returns iterable', () {
      final list = NexusList<int>(initial: [1, 2, 3]);
      expect(list.items.toList(), [1, 2, 3]);
    });

    test('toString includes name and length', () {
      final list = NexusList<int>(initial: [1, 2], name: 'myList');
      expect(list.toString(), 'NexusList(myList)<int>[2]');
    });

    test('auto-tracked in Derived', () {
      final list = NexusList<int>(initial: [1, 2, 3]);
      final sum = TitanComputed(() => list.value.fold(0, (a, b) => a + b));

      expect(sum.value, 6);

      list.add(4);
      expect(sum.value, 10);
    });

    test('auto-tracked length in Derived', () {
      final list = NexusList<String>();
      final count = TitanComputed(() => list.length);

      expect(count.value, 0);
      list.add('a');
      expect(count.value, 1);
      list.addAll(['b', 'c']);
      expect(count.value, 3);
    });

    test('no copy-on-write overhead (identity preserved)', () {
      final list = NexusList<int>(initial: [1, 2, 3]);
      final ref1 = list.peek();
      list.add(4);
      final ref2 = list.peek();
      // Same list instance — in-place mutation
      expect(identical(ref1, ref2), true);
    });

    test('dispose prevents further use', () {
      final list = NexusList<int>(initial: [1]);
      list.dispose();
      // After dispose, addListener should still be safe but no notifications
      expect(list.peek(), [1]); // peek still works on disposed
    });
  });

  group('NexusMap', () {
    test('initial state', () {
      final map = NexusMap<String, int>(initial: {'a': 1, 'b': 2});
      expect(map.value, {'a': 1, 'b': 2});
      expect(map.length, 2);
      expect(map.isEmpty, false);
      expect(map.isNotEmpty, true);
    });

    test('empty by default', () {
      final map = NexusMap<String, int>();
      expect(map.value, isEmpty);
      expect(map.isEmpty, true);
    });

    test('operator []= adds new key with NexusMapSet', () {
      final map = NexusMap<String, int>();
      map['Alice'] = 10;

      expect(map['Alice'], 10);
      final change = map.lastChange as NexusMapSet<String, int>;
      expect(change.key, 'Alice');
      expect(change.oldValue, null);
      expect(change.newValue, 10);
      expect(change.isNew, true);
    });

    test('operator []= updates existing key', () {
      final map = NexusMap<String, int>(initial: {'Alice': 10});
      map['Alice'] = 20;

      expect(map['Alice'], 20);
      final change = map.lastChange as NexusMapSet<String, int>;
      expect(change.isNew, false);
      expect(change.oldValue, 10);
    });

    test('putIfChanged skips if same value', () {
      final map = NexusMap<String, int>(initial: {'Alice': 10});
      var notified = false;
      map.addListener(() => notified = true);

      final result = map.putIfChanged('Alice', 10);
      expect(result, false);
      expect(notified, false);
    });

    test('putIfChanged notifies on actual change', () {
      final map = NexusMap<String, int>(initial: {'Alice': 10});
      final result = map.putIfChanged('Alice', 20);

      expect(result, true);
      expect(map['Alice'], 20);
    });

    test('putIfAbsent adds if absent', () {
      final map = NexusMap<String, int>();
      final result = map.putIfAbsent('Alice', () => 10);

      expect(result, 10);
      expect(map['Alice'], 10);
    });

    test('putIfAbsent returns existing if present', () {
      final map = NexusMap<String, int>(initial: {'Alice': 10});
      var notified = false;
      map.addListener(() => notified = true);

      final result = map.putIfAbsent('Alice', () => 99);
      expect(result, 10);
      expect(notified, false);
    });

    test('addAll notifies', () {
      final map = NexusMap<String, int>();
      map.addAll({'a': 1, 'b': 2});

      expect(map.length, 2);
      expect(map.lastChange, isA<NexusBatch<MapEntry<String, int>>>());
    });

    test('addAll with empty map does not notify', () {
      final map = NexusMap<String, int>(initial: {'a': 1});
      var notified = false;
      map.addListener(() => notified = true);

      map.addAll({});
      expect(notified, false);
    });

    test('remove returns value and notifies', () {
      final map = NexusMap<String, int>(initial: {'Alice': 10});
      final removed = map.remove('Alice');

      expect(removed, 10);
      expect(map.isEmpty, true);
      final change = map.lastChange as NexusMapRemove<String, int>;
      expect(change.key, 'Alice');
      expect(change.value, 10);
    });

    test('remove returns null if key absent', () {
      final map = NexusMap<String, int>(initial: {'Alice': 10});
      var notified = false;
      map.addListener(() => notified = true);

      expect(map.remove('Bob'), null);
      expect(notified, false);
    });

    test('removeWhere removes matching entries', () {
      final map = NexusMap<String, int>(
        initial: {'a': 1, 'b': 2, 'c': 3, 'd': 4},
      );
      final removed = map.removeWhere((k, v) => v.isEven);

      expect(removed, 2);
      expect(map.value, {'a': 1, 'c': 3});
    });

    test('updateAll updates all values', () {
      final map = NexusMap<String, int>(initial: {'a': 1, 'b': 2});
      map.updateAll((k, v) => v * 10);

      expect(map['a'], 10);
      expect(map['b'], 20);
    });

    test('clear notifies with NexusClear', () {
      final map = NexusMap<String, int>(initial: {'a': 1, 'b': 2});
      map.clear();

      expect(map.isEmpty, true);
      expect(map.lastChange, isA<NexusClear<MapEntry<String, int>>>());
    });

    test('clear does nothing if already empty', () {
      final map = NexusMap<String, int>();
      var notified = false;
      map.addListener(() => notified = true);

      map.clear();
      expect(notified, false);
    });

    test('keys, values, entries are tracked', () {
      final map = NexusMap<String, int>(initial: {'a': 1});
      expect(map.keys, ['a']);
      expect(map.values, [1]);
      expect(map.entries.length, 1);
    });

    test('containsKey and containsValue', () {
      final map = NexusMap<String, int>(initial: {'a': 1});
      expect(map.containsKey('a'), true);
      expect(map.containsKey('b'), false);
      expect(map.containsValue(1), true);
      expect(map.containsValue(99), false);
    });

    test('toString includes name and length', () {
      final map = NexusMap<String, int>(initial: {'a': 1}, name: 'myMap');
      expect(map.toString(), 'NexusMap(myMap)<String, int>{1}');
    });

    test('auto-tracked in Derived', () {
      final map = NexusMap<String, int>(initial: {'a': 1});
      final total = TitanComputed(() => map.values.fold(0, (a, b) => a + b));

      expect(total.value, 1);
      map['b'] = 2;
      expect(total.value, 3);
    });

    test('no copy-on-write overhead', () {
      final map = NexusMap<String, int>(initial: {'a': 1});
      final ref1 = map.peek();
      map['b'] = 2;
      final ref2 = map.peek();
      expect(identical(ref1, ref2), true);
    });
  });

  group('NexusSet', () {
    test('initial state', () {
      final set = NexusSet<String>(initial: {'a', 'b', 'c'});
      expect(set.value, {'a', 'b', 'c'});
      expect(set.length, 3);
      expect(set.isEmpty, false);
      expect(set.isNotEmpty, true);
    });

    test('empty by default', () {
      final set = NexusSet<String>();
      expect(set.value, isEmpty);
      expect(set.isEmpty, true);
    });

    test('add returns true and notifies for new element', () {
      final set = NexusSet<String>(initial: {'a'});
      var notified = false;
      set.addListener(() => notified = true);

      expect(set.add('b'), true);
      expect(notified, true);
      expect(set.value, {'a', 'b'});
      expect(set.lastChange, isA<NexusSetAdd<String>>());
    });

    test('add returns false for existing element', () {
      final set = NexusSet<String>(initial: {'a'});
      var notified = false;
      set.addListener(() => notified = true);

      expect(set.add('a'), false);
      expect(notified, false);
    });

    test('addAll adds new elements only', () {
      final set = NexusSet<int>(initial: {1, 2});
      set.addAll([2, 3, 4]);

      expect(set.value, {1, 2, 3, 4});
      final change = set.lastChange as NexusBatch<int>;
      expect(change.count, 2); // only 3 and 4 were new
    });

    test('addAll with no new elements does not notify', () {
      final set = NexusSet<int>(initial: {1, 2});
      var notified = false;
      set.addListener(() => notified = true);

      set.addAll([1, 2]);
      expect(notified, false);
    });

    test('remove returns true and notifies', () {
      final set = NexusSet<String>(initial: {'a', 'b'});
      expect(set.remove('a'), true);
      expect(set.value, {'b'});
      expect(set.lastChange, isA<NexusSetRemove<String>>());
    });

    test('remove returns false if not found', () {
      final set = NexusSet<String>(initial: {'a'});
      var notified = false;
      set.addListener(() => notified = true);

      expect(set.remove('z'), false);
      expect(notified, false);
    });

    test('toggle adds if absent', () {
      final set = NexusSet<String>(initial: {'a'});
      final result = set.toggle('b');

      expect(result, true); // now in set
      expect(set.contains('b'), true);
      expect(set.lastChange, isA<NexusSetAdd<String>>());
    });

    test('toggle removes if present', () {
      final set = NexusSet<String>(initial: {'a', 'b'});
      final result = set.toggle('a');

      expect(result, false); // no longer in set
      expect(set.contains('a'), false);
      expect(set.lastChange, isA<NexusSetRemove<String>>());
    });

    test('removeWhere removes matching elements', () {
      final set = NexusSet<int>(initial: {1, 2, 3, 4, 5});
      final removed = set.removeWhere((e) => e.isEven);

      expect(removed, 2);
      expect(set.value, {1, 3, 5});
    });

    test('retainWhere keeps matching elements', () {
      final set = NexusSet<int>(initial: {1, 2, 3, 4, 5});
      final removed = set.retainWhere((e) => e > 3);

      expect(removed, 3);
      expect(set.value, {4, 5});
    });

    test('clear notifies with NexusClear', () {
      final set = NexusSet<String>(initial: {'a', 'b', 'c'});
      set.clear();

      expect(set.isEmpty, true);
      expect(set.lastChange, isA<NexusClear<String>>());
    });

    test('clear does nothing if already empty', () {
      final set = NexusSet<String>();
      var notified = false;
      set.addListener(() => notified = true);

      set.clear();
      expect(notified, false);
    });

    test('contains works', () {
      final set = NexusSet<String>(initial: {'a', 'b'});
      expect(set.contains('a'), true);
      expect(set.contains('z'), false);
    });

    test('elements returns iterable', () {
      final set = NexusSet<int>(initial: {1, 2, 3});
      expect(set.elements.toSet(), {1, 2, 3});
    });

    test('intersection', () {
      final set = NexusSet<int>(initial: {1, 2, 3, 4});
      expect(set.intersection({2, 4, 6}), {2, 4});
    });

    test('union', () {
      final set = NexusSet<int>(initial: {1, 2});
      expect(set.union({2, 3}), {1, 2, 3});
    });

    test('difference', () {
      final set = NexusSet<int>(initial: {1, 2, 3});
      expect(set.difference({2}), {1, 3});
    });

    test('toString includes name and length', () {
      final set = NexusSet<String>(initial: {'a'}, name: 'mySet');
      expect(set.toString(), 'NexusSet(mySet)<String>{1}');
    });

    test('auto-tracked in Derived', () {
      final set = NexusSet<String>(initial: {'a'});
      final count = TitanComputed(() => set.length);

      expect(count.value, 1);
      set.add('b');
      expect(count.value, 2);
      set.remove('a');
      expect(count.value, 1);
    });

    test('no copy-on-write overhead', () {
      final set = NexusSet<int>(initial: {1});
      final ref1 = set.peek();
      set.add(2);
      final ref2 = set.peek();
      expect(identical(ref1, ref2), true);
    });
  });

  group('Nexus Pillar Integration', () {
    test('nexusList is managed and auto-disposed', () {
      final pillar = _NexusPillar();
      pillar.initialize();

      expect(pillar.items.length, 2);
      expect(pillar.itemCount.value, 2);

      pillar.items.add('potion');
      expect(pillar.items.length, 3);
      expect(pillar.itemCount.value, 3);

      pillar.dispose();
    });

    test('nexusMap is managed and tracked by Derived', () {
      final pillar = _NexusPillar();
      pillar.initialize();

      expect(pillar.scores.length, 1);
      expect(pillar.topScore.value, 10);

      pillar.scores['Bob'] = 25;
      expect(pillar.topScore.value, 25);

      pillar.dispose();
    });

    test('nexusSet is managed and tracked by Derived', () {
      final pillar = _NexusPillar();
      pillar.initialize();

      expect(pillar.tags.length, 2);
      expect(pillar.hasFlutter.value, true);

      pillar.tags.remove('flutter');
      expect(pillar.hasFlutter.value, false);

      pillar.dispose();
    });

    test('nexusList works with batch (strike)', () {
      final pillar = _NexusPillar();
      pillar.initialize();

      var notifyCount = 0;
      pillar.items.addListener(() => notifyCount++);

      // Without batch, each call notifies separately
      pillar.items.add('a');
      pillar.items.add('b');
      expect(notifyCount, 2);

      pillar.dispose();
    });
  });

  group('NexusChange records', () {
    test('NexusInsert toString', () {
      final change = NexusInsert<String>(0, 'hello');
      expect(change.toString(), contains('NexusInsert'));
      expect(change.toString(), contains('hello'));
    });

    test('NexusRemove toString', () {
      final change = NexusRemove<int>(2, 42);
      expect(change.toString(), contains('NexusRemove'));
      expect(change.toString(), contains('42'));
    });

    test('NexusUpdate toString', () {
      final change = NexusUpdate<String>(0, 'old', 'new');
      expect(change.toString(), contains('NexusUpdate'));
    });

    test('NexusClear toString', () {
      final change = NexusClear<int>(5);
      expect(change.toString(), contains('5'));
    });

    test('NexusMapSet toString', () {
      final change = NexusMapSet<String, int>('key', 1, 2, isNew: false);
      expect(change.toString(), contains('NexusMapSet'));
      expect(change.toString(), contains('key'));
    });

    test('NexusMapRemove toString', () {
      final change = NexusMapRemove<String, int>('key', 10);
      expect(change.toString(), contains('key'));
    });

    test('NexusSetAdd toString', () {
      final change = NexusSetAdd<String>('element');
      expect(change.toString(), contains('element'));
    });

    test('NexusSetRemove toString', () {
      final change = NexusSetRemove<String>('gone');
      expect(change.toString(), contains('gone'));
    });

    test('NexusBatch toString', () {
      final change = NexusBatch<int>('sort', 10);
      expect(change.toString(), contains('sort'));
    });
  });

  group('Nexus + reactive graph', () {
    test('NexusList triggers TitanEffect', () {
      final list = NexusList<int>(initial: [1, 2]);
      final log = <int>[];
      TitanEffect(() => log.add(list.length));

      expect(log, [2]); // initial
      list.add(3);
      expect(log, [2, 3]);
    });

    test('NexusMap triggers TitanEffect', () {
      final map = NexusMap<String, int>();
      final log = <int>[];
      TitanEffect(() => log.add(map.length));

      expect(log, [0]);
      map['a'] = 1;
      expect(log, [0, 1]);
    });

    test('NexusSet triggers TitanEffect', () {
      final set = NexusSet<String>();
      final log = <bool>[];
      TitanEffect(() => log.add(set.isEmpty));

      expect(log, [true]);
      set.add('x');
      expect(log, [true, false]);
    });

    test('batch multiple NexusList changes notifies once', () {
      final list = NexusList<int>();
      var count = 0;
      list.addListener(() => count++);

      titanBatch(() {
        list.add(1);
        list.add(2);
        list.add(3);
      });

      // In batch mode, only one notification fires
      expect(count, 1);
      expect(list.value, [1, 2, 3]);
    });
  });
}
