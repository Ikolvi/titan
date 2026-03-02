import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _SnapshotPillar extends Pillar {
  late final count = core(0, name: 'count');
  late final label = core('hello', name: 'label');
  late final unnamed = core(42);
  late final doubled = derived(() => count.value * 2);
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

  group('Snapshot', () {
    test('captures named Core values', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      pillar.count.value = 10;
      pillar.label.value = 'world';

      final snap = pillar.snapshot();
      expect(snap.values['count'], 10);
      expect(snap.values['label'], 'world');
      expect(snap.length, 2);
      pillar.dispose();
    });

    test('ignores unnamed Cores', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      // Access lazy fields to initialize them
      pillar.count;
      pillar.label;
      pillar.unnamed;

      final snap = pillar.snapshot();
      expect(snap.length, 2); // only count and label (unnamed excluded)
      pillar.dispose();
    });

    test('ignores Derived values', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      final snap = pillar.snapshot();
      expect(snap.values.keys, isNot(contains('doubled')));
      pillar.dispose();
    });

    test('restores Core values silently', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      pillar.count.value = 10;
      pillar.label.value = 'world';

      final snap = pillar.snapshot();

      pillar.count.value = 99;
      pillar.label.value = 'changed';

      pillar.restore(snap);

      expect(pillar.count.peek(), 10);
      expect(pillar.label.peek(), 'world');
      pillar.dispose();
    });

    test('restores with notify when requested', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      pillar.count.value = 10;
      final snap = pillar.snapshot();
      pillar.count.value = 99;

      final values = <int>[];
      TitanEffect(() {
        values.add(pillar.count.value);
      });
      expect(values, [99]);

      pillar.restore(snap, notify: true);
      expect(values, [99, 10]);
      pillar.dispose();
    });

    test('snapshot has timestamp', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      final before = DateTime.now();
      final snap = pillar.snapshot();
      final after = DateTime.now();

      expect(
        snap.timestamp.isAfter(before.subtract(Duration(seconds: 1))),
        isTrue,
      );
      expect(snap.timestamp.isBefore(after.add(Duration(seconds: 1))), isTrue);
      pillar.dispose();
    });

    test('snapshot can have a label', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      final snap = pillar.snapshot(label: 'before-mutation');
      expect(snap.label, 'before-mutation');
      pillar.dispose();
    });

    test('has() checks for key presence', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();
      // Access lazy fields
      pillar.count;
      pillar.label;

      final snap = pillar.snapshot();
      expect(snap.has('count'), isTrue);
      expect(snap.has('nonexistent'), isFalse);
      pillar.dispose();
    });

    test('get<T>() returns typed value', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();
      pillar.count.value = 42;
      pillar.label; // access lazy field

      final snap = pillar.snapshot();
      expect(snap.get<int>('count'), 42);
      expect(snap.get<String>('label'), 'hello');
      expect(snap.get<int>('nonexistent'), isNull);
      pillar.dispose();
    });

    test('snapshot values are immutable', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      final snap = pillar.snapshot();
      expect(() => (snap.values)['count'] = 999, throwsUnsupportedError);
      pillar.dispose();
    });

    test('diff detects changes between snapshots', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      pillar.count.value = 10;
      final snap1 = pillar.snapshot();

      pillar.count.value = 20;
      final snap2 = pillar.snapshot();

      final changes = Snapshot.diff(snap1, snap2);
      expect(changes['count'], (10, 20));
      expect(changes.containsKey('label'), isFalse);
      pillar.dispose();
    });

    test('diff shows additions and removals', () {
      final snap1 = PillarSnapshot.fromMap({'a': 1, 'b': 2});
      final snap2 = PillarSnapshot.fromMap({'b': 2, 'c': 3});

      final changes = Snapshot.diff(snap1, snap2);
      expect(changes['a'], (1, null));
      expect(changes['c'], (null, 3));
      expect(changes.containsKey('b'), isFalse);
    });

    test('toString includes info', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();
      // Access lazy fields
      pillar.count;
      pillar.label;

      final snap = pillar.snapshot(label: 'test-snap');
      expect(snap.toString(), contains('PillarSnapshot'));
      expect(snap.toString(), contains('test-snap'));
      expect(snap.toString(), contains('2 cores'));
      pillar.dispose();
    });

    test('multiple snapshots are independent', () {
      final pillar = _SnapshotPillar();
      pillar.initialize();

      pillar.count.value = 1;
      final snap1 = pillar.snapshot();

      pillar.count.value = 2;
      final snap2 = pillar.snapshot();

      expect(snap1.get<int>('count'), 1);
      expect(snap2.get<int>('count'), 2);
      pillar.dispose();
    });

    test('PillarSnapshot.fromMap creates snapshot directly', () {
      final snap = PillarSnapshot.fromMap({
        'x': 1,
        'y': 'hello',
      }, label: 'direct');
      expect(snap.get<int>('x'), 1);
      expect(snap.get<String>('y'), 'hello');
      expect(snap.label, 'direct');
      expect(snap.length, 2);
    });
  });
}
