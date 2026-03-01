import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _EditorPillar extends Pillar {
  late final text = epoch('');
  late final count = epoch(0);

  void type(String s) => strike(() => text.value = s);
}

void main() {
  group('Epoch', () {
    // -----------------------------------------------------------------------
    // Basic undo/redo
    // -----------------------------------------------------------------------

    test('initial state has no undo/redo', () {
      final e = Epoch<int>(0);
      expect(e.canUndo, isFalse);
      expect(e.canRedo, isFalse);
      expect(e.undoCount, 0);
      expect(e.redoCount, 0);
      expect(e.history, isEmpty);
    });

    test('setting value records undo history', () {
      final e = Epoch<int>(0);
      e.value = 1;
      e.value = 2;
      e.value = 3;

      expect(e.value, 3);
      expect(e.canUndo, isTrue);
      expect(e.undoCount, 3);
      expect(e.history, [0, 1, 2]);
    });

    test('undo reverts to previous value', () {
      final e = Epoch<String>('a');
      e.value = 'b';
      e.value = 'c';

      e.undo();
      expect(e.value, 'b');

      e.undo();
      expect(e.value, 'a');
    });

    test('redo replays undone value', () {
      final e = Epoch<int>(0);
      e.value = 1;
      e.value = 2;

      e.undo();
      expect(e.value, 1);
      expect(e.canRedo, isTrue);

      e.redo();
      expect(e.value, 2);
      expect(e.canRedo, isFalse);
    });

    test('undo when empty does nothing', () {
      final e = Epoch<int>(0);
      e.undo();
      expect(e.value, 0);
    });

    test('redo when empty does nothing', () {
      final e = Epoch<int>(0);
      e.redo();
      expect(e.value, 0);
    });

    test('setting value clears redo stack', () {
      final e = Epoch<int>(0);
      e.value = 1;
      e.value = 2;

      e.undo(); // back to 1
      expect(e.canRedo, isTrue);

      e.value = 3; // branch — redo is lost
      expect(e.canRedo, isFalse);
      expect(e.value, 3);
      expect(e.history, [0, 1]);
    });

    test('full undo/redo cycle', () {
      final e = Epoch<int>(0);
      e.value = 1;
      e.value = 2;
      e.value = 3;

      // Undo all
      e.undo(); // 2
      e.undo(); // 1
      e.undo(); // 0
      expect(e.value, 0);
      expect(e.canUndo, isFalse);
      expect(e.redoCount, 3);

      // Redo all
      e.redo(); // 1
      e.redo(); // 2
      e.redo(); // 3
      expect(e.value, 3);
      expect(e.canRedo, isFalse);
      expect(e.undoCount, 3);
    });

    // -----------------------------------------------------------------------
    // maxHistory
    // -----------------------------------------------------------------------

    test('respects maxHistory limit', () {
      final e = Epoch<int>(0, maxHistory: 3);

      e.value = 1;
      e.value = 2;
      e.value = 3;
      e.value = 4;

      expect(e.undoCount, 3);
      // initial 0, then 1, 2, 3, 4
      // After value=1: stack = [0]
      // After value=2: stack = [0, 1]
      // After value=3: stack = [0, 1, 2]
      // After value=4: stack = [0, 1, 2, 3] → trim oldest → [1, 2, 3]
      expect(e.history, [1, 2, 3]);
    });

    test('maxHistory of 1 keeps only last change', () {
      final e = Epoch<int>(0, maxHistory: 1);
      e.value = 1;
      e.value = 2;
      e.value = 3;

      expect(e.undoCount, 1);
      e.undo();
      expect(e.value, 2);
      expect(e.canUndo, isFalse);
    });

    // -----------------------------------------------------------------------
    // clearHistory
    // -----------------------------------------------------------------------

    test('clearHistory clears both stacks', () {
      final e = Epoch<int>(0);
      e.value = 1;
      e.value = 2;
      e.undo();

      expect(e.canUndo, isTrue);
      expect(e.canRedo, isTrue);

      e.clearHistory();

      expect(e.canUndo, isFalse);
      expect(e.canRedo, isFalse);
      expect(e.value, 1); // current value unchanged
    });

    // -----------------------------------------------------------------------
    // Equality
    // -----------------------------------------------------------------------

    test('equal values do not create new history entries', () {
      final e = Epoch<int>(0);
      e.value = 0; // same value
      e.value = 0; // same value

      expect(e.undoCount, 0);
    });

    test('custom equals is respected', () {
      // Case-insensitive string comparison
      final e = Epoch<String>(
        'hello',
        equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
      );

      e.value = 'HELLO'; // considered equal
      expect(e.undoCount, 0);

      e.value = 'world'; // different
      expect(e.undoCount, 1);
    });

    // -----------------------------------------------------------------------
    // Reactivity
    // -----------------------------------------------------------------------

    test('undo triggers reactive notifications', () {
      final e = Epoch<int>(0);
      e.value = 1;
      e.value = 2;

      final values = <int>[];
      e.listen((v) => values.add(v));

      e.undo();
      expect(values, [1]);
    });

    test('redo triggers reactive notifications', () {
      final e = Epoch<int>(0);
      e.value = 1;
      e.undo();

      final values = <int>[];
      e.listen((v) => values.add(v));

      e.redo();
      expect(values, [1]);
    });

    test('works with derived values', () {
      final e = Epoch<int>(5);
      final doubled = TitanComputed<int>(() => e.value * 2);

      expect(doubled.value, 10);

      e.value = 10;
      expect(doubled.value, 20);

      e.undo();
      expect(doubled.value, 10);

      e.redo();
      expect(doubled.value, 20);

      doubled.dispose();
      e.dispose();
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------

    test('toString shows value and stack sizes', () {
      final e = Epoch<int>(0, name: 'counter');
      e.value = 1;
      e.undo();

      expect(e.toString(), contains('Epoch'));
      expect(e.toString(), contains('counter'));
      expect(e.toString(), contains('undo:'));
      expect(e.toString(), contains('redo:'));
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    test('Pillar.epoch() creates managed Epoch', () {
      final pillar = _EditorPillar();
      pillar.initialize();

      pillar.type('Hello');
      pillar.type('Hello World');

      expect(pillar.text.value, 'Hello World');
      expect(pillar.text.canUndo, isTrue);

      pillar.text.undo();
      expect(pillar.text.value, 'Hello');

      pillar.text.redo();
      expect(pillar.text.value, 'Hello World');

      pillar.dispose();
    });

    test('Epoch is disposed with Pillar', () {
      final pillar = _EditorPillar();
      pillar.initialize();

      pillar.type('test');

      pillar.dispose();

      // Epoch is managed — should be disposed along with Pillar
      expect(pillar.isDisposed, isTrue);
    });

    test('multiple Epochs in one Pillar', () {
      final pillar = _EditorPillar();
      pillar.initialize();

      pillar.type('abc');
      pillar.count.value = 42;

      expect(pillar.text.undoCount, 1);
      expect(pillar.count.undoCount, 1);

      pillar.text.undo();
      expect(pillar.text.value, '');
      expect(pillar.count.value, 42); // independent history

      pillar.dispose();
    });

    // -----------------------------------------------------------------------
    // peek and update
    // -----------------------------------------------------------------------

    test('peek does not track dependencies', () {
      final e = Epoch<int>(5);
      expect(e.peek(), 5);
    });

    test('update records history', () {
      final e = Epoch<int>(0);
      e.update((v) => v + 10);
      expect(e.value, 10);
      expect(e.undoCount, 1);

      e.undo();
      expect(e.value, 0);
    });
  });
}
