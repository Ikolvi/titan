import 'package:test/test.dart';
import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _UpperCaseConduit extends Conduit<String> {
  @override
  String pipe(String oldValue, String newValue) => newValue.toUpperCase();
}

class _TrimConduit extends Conduit<String> {
  @override
  String pipe(String oldValue, String newValue) => newValue.trim();
}

class _TrackingConduit<T> extends Conduit<T> {
  final List<(T, T)> pipeCalls = [];
  final List<(T, T)> onPipedCalls = [];

  @override
  T pipe(T oldValue, T newValue) {
    pipeCalls.add((oldValue, newValue));
    return newValue;
  }

  @override
  void onPiped(T oldValue, T newValue) {
    onPipedCalls.add((oldValue, newValue));
  }
}

class _RejectAboveConduit extends Conduit<int> {
  final int limit;
  _RejectAboveConduit(this.limit);

  @override
  int pipe(int oldValue, int newValue) {
    if (newValue > limit) {
      throw ConduitRejectedException(
        message: 'Value $newValue exceeds limit $limit',
        rejectedValue: newValue,
      );
    }
    return newValue;
  }
}

class _ConduitPillar extends Pillar {
  late final count = core(0, conduits: [ClampConduit(min: 0, max: 100)]);
  late final name = core('', conduits: [_TrimConduit(), _UpperCaseConduit()]);

  void setCount(int v) => strike(() => count.value = v);
  void setName(String v) => strike(() => name.value = v);
}

void main() {
  group('Conduit', () {
    // -----------------------------------------------------------------------
    // 1. Basic pipe passthrough
    // -----------------------------------------------------------------------
    test('pipe is called on value change', () {
      final tracker = _TrackingConduit<int>();
      final state = TitanState<int>(0, conduits: [tracker]);

      state.value = 5;

      expect(tracker.pipeCalls, hasLength(1));
      expect(tracker.pipeCalls.first, (0, 5));
      expect(state.value, 5);
    });

    // -----------------------------------------------------------------------
    // 2. onPiped callback fires after change
    // -----------------------------------------------------------------------
    test('onPiped fires after successful change', () {
      final tracker = _TrackingConduit<int>();
      final state = TitanState<int>(0, conduits: [tracker]);

      state.value = 10;

      expect(tracker.onPipedCalls, hasLength(1));
      expect(tracker.onPipedCalls.first, (0, 10));
    });

    // -----------------------------------------------------------------------
    // 3. onPiped does NOT fire when equality suppresses change
    // -----------------------------------------------------------------------
    test('onPiped does not fire when value unchanged', () {
      final tracker = _TrackingConduit<int>();
      final state = TitanState<int>(5, conduits: [tracker]);

      state.value = 5; // Same value — suppressed

      expect(tracker.pipeCalls, hasLength(1)); // pipe IS called
      expect(tracker.onPipedCalls, isEmpty); // onPiped is NOT
    });

    // -----------------------------------------------------------------------
    // 4. Multiple conduits chain in order
    // -----------------------------------------------------------------------
    test('multiple conduits execute in FIFO order', () {
      final state = TitanState<String>(
        '',
        conduits: [_TrimConduit(), _UpperCaseConduit()],
      );

      state.value = '  hello  ';

      expect(state.value, 'HELLO'); // trim first, then uppercase
    });

    // -----------------------------------------------------------------------
    // 5. ClampConduit clamps to range
    // -----------------------------------------------------------------------
    test('ClampConduit clamps values to min-max range', () {
      final state = TitanState<int>(
        50,
        conduits: [ClampConduit(min: 0, max: 100)],
      );

      state.value = 150;
      expect(state.value, 100);

      state.value = -20;
      expect(state.value, 0);

      state.value = 50;
      expect(state.value, 50);
    });

    // -----------------------------------------------------------------------
    // 6. ClampConduit with double
    // -----------------------------------------------------------------------
    test('ClampConduit works with double', () {
      final state = TitanState<double>(
        0.5,
        conduits: [ClampConduit(min: 0.0, max: 1.0)],
      );

      state.value = 1.5;
      expect(state.value, 1.0);

      state.value = -0.5;
      expect(state.value, 0.0);
    });

    // -----------------------------------------------------------------------
    // 7. TransformConduit applies transformation
    // -----------------------------------------------------------------------
    test('TransformConduit applies transformation function', () {
      final state = TitanState<String>(
        '',
        conduits: [TransformConduit((old, value) => value.toLowerCase())],
      );

      state.value = 'HELLO WORLD';
      expect(state.value, 'hello world');
    });

    // -----------------------------------------------------------------------
    // 8. ValidateConduit rejects invalid values
    // -----------------------------------------------------------------------
    test('ValidateConduit rejects invalid values', () {
      final state = TitanState<String>(
        '',
        conduits: [
          ValidateConduit(
            (old, value) => value.isEmpty ? 'Cannot be empty' : null,
          ),
        ],
      );

      state.value = 'valid';
      expect(state.value, 'valid');

      expect(() => state.value = '', throwsA(isA<ConduitRejectedException>()));
      expect(state.value, 'valid'); // unchanged
    });

    // -----------------------------------------------------------------------
    // 9. ConduitRejectedException preserves message
    // -----------------------------------------------------------------------
    test('ConduitRejectedException contains message and rejected value', () {
      final state = TitanState<int>(0, conduits: [_RejectAboveConduit(10)]);

      try {
        state.value = 20;
        fail('Should have thrown');
      } on ConduitRejectedException catch (e) {
        expect(e.message, contains('exceeds limit'));
        expect(e.rejectedValue, 20);
        expect(e.toString(), contains('ConduitRejectedException'));
      }
      expect(state.value, 0); // unchanged
    });

    // -----------------------------------------------------------------------
    // 10. FreezeConduit prevents changes after condition
    // -----------------------------------------------------------------------
    test('FreezeConduit blocks changes once condition is met', () {
      final state = TitanState<int>(
        0,
        conduits: [FreezeConduit((old, _) => old >= 100)],
      );

      state.value = 50;
      expect(state.value, 50);

      state.value = 100;
      expect(state.value, 100);

      expect(() => state.value = 50, throwsA(isA<ConduitRejectedException>()));
      expect(state.value, 100); // frozen
    });

    // -----------------------------------------------------------------------
    // 11. ThrottleConduit rejects rapid changes
    // -----------------------------------------------------------------------
    test('ThrottleConduit rejects rapid changes', () async {
      final state = TitanState<int>(
        0,
        conduits: [ThrottleConduit(const Duration(milliseconds: 50))],
      );

      state.value = 1; // First change — allowed
      expect(state.value, 1);

      // Immediate second change — rejected
      expect(() => state.value = 2, throwsA(isA<ConduitRejectedException>()));
      expect(state.value, 1);

      // Wait past throttle interval
      await Future<void>.delayed(const Duration(milliseconds: 60));

      state.value = 3; // Allowed again
      expect(state.value, 3);
    });

    // -----------------------------------------------------------------------
    // 12. addConduit / removeConduit
    // -----------------------------------------------------------------------
    test('addConduit and removeConduit work dynamically', () {
      final state = TitanState<int>(0);
      final clamp = ClampConduit<int>(min: 0, max: 10);

      state.value = 20;
      expect(state.value, 20); // No conduit — no clamping

      state.addConduit(clamp);
      state.value = 30;
      expect(state.value, 10); // Clamped

      final removed = state.removeConduit(clamp);
      expect(removed, true);
      state.value = 50;
      expect(state.value, 50); // Unclamped
    });

    // -----------------------------------------------------------------------
    // 13. clearConduits removes all
    // -----------------------------------------------------------------------
    test('clearConduits removes all conduits', () {
      final state = TitanState<int>(
        0,
        conduits: [ClampConduit(min: 0, max: 10), _RejectAboveConduit(5)],
      );

      expect(state.conduits, hasLength(2));

      state.clearConduits();
      expect(state.conduits, isEmpty);

      state.value = 100;
      expect(state.value, 100); // No conduits — passes through
    });

    // -----------------------------------------------------------------------
    // 14. conduits list is unmodifiable
    // -----------------------------------------------------------------------
    test('conduits getter returns unmodifiable list', () {
      final state = TitanState<int>(
        0,
        conduits: [ClampConduit(min: 0, max: 10)],
      );

      expect(
        () => state.conduits.add(ClampConduit(min: 0, max: 5)),
        throwsA(isA<UnsupportedError>()),
      );
    });

    // -----------------------------------------------------------------------
    // 15. Rejection does not notify dependents
    // -----------------------------------------------------------------------
    test('rejected change does not notify dependents', () {
      final state = TitanState<int>(0, conduits: [_RejectAboveConduit(10)]);
      int rebuildCount = 0;
      final computed = TitanComputed(() {
        rebuildCount++;
        return state.value * 2;
      });

      // Initial read
      expect(computed.value, 0);
      expect(rebuildCount, 1);

      // Valid change
      state.value = 5;
      expect(computed.value, 10);
      expect(rebuildCount, 2);

      // Rejected change — no rebuild
      expect(() => state.value = 20, throwsA(isA<ConduitRejectedException>()));
      expect(state.value, 5);
      expect(computed.value, 10);
      expect(rebuildCount, 2); // unchanged
    });

    // -----------------------------------------------------------------------
    // 16. Conduit transforms before equality check
    // -----------------------------------------------------------------------
    test('conduit transforms value before equality check', () {
      // Clamp to 0-10, current is 10. Set to 15 → clamped to 10 → equal → no notify
      final state = TitanState<int>(
        10,
        conduits: [ClampConduit(min: 0, max: 10)],
      );
      int notifyCount = 0;
      state.listen((_) => notifyCount++);

      state.value = 15; // Clamped to 10 — same as current, no notification
      expect(state.value, 10);
      expect(notifyCount, 0);
    });

    // -----------------------------------------------------------------------
    // 17. update() also goes through conduits
    // -----------------------------------------------------------------------
    test('update() pipes through conduits', () {
      final state = TitanState<int>(
        5,
        conduits: [ClampConduit(min: 0, max: 10)],
      );

      state.update((v) => v + 20); // 5 + 20 = 25, clamped to 10
      expect(state.value, 10);
    });

    // -----------------------------------------------------------------------
    // 18. previousValue preserved correctly with conduits
    // -----------------------------------------------------------------------
    test('previousValue reflects pre-change value', () {
      final state = TitanState<int>(
        0,
        conduits: [ClampConduit(min: 0, max: 100)],
      );

      state.value = 50;
      expect(state.previousValue, 0);

      state.value = 200; // Clamped to 100
      expect(state.value, 100);
      expect(state.previousValue, 50);
    });

    // -----------------------------------------------------------------------
    // 19. Conduit chain — early rejection stops chain
    // -----------------------------------------------------------------------
    test('rejection in early conduit stops chain', () {
      final tracker = _TrackingConduit<int>();
      final state = TitanState<int>(
        0,
        conduits: [
          _RejectAboveConduit(10), // First — rejects > 10
          tracker, // Second — should NOT be called
        ],
      );

      expect(() => state.value = 20, throwsA(isA<ConduitRejectedException>()));
      expect(tracker.pipeCalls, isEmpty); // Never reached
      expect(tracker.onPipedCalls, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 20. Pillar integration — core() with conduits
    // -----------------------------------------------------------------------
    test('Pillar core() accepts conduits parameter', () {
      final pillar = _ConduitPillar();
      pillar.initialize();

      pillar.setCount(150);
      expect(pillar.count.value, 100); // Clamped

      pillar.setCount(-5);
      expect(pillar.count.value, 0); // Clamped

      pillar.setName('  hello  ');
      expect(pillar.name.value, 'HELLO'); // Trimmed + uppercased

      pillar.dispose();
    });

    // -----------------------------------------------------------------------
    // 21. Multiple conduits with onPiped
    // -----------------------------------------------------------------------
    test('all conduit onPiped callbacks fire after change', () {
      final tracker1 = _TrackingConduit<int>();
      final tracker2 = _TrackingConduit<int>();
      final state = TitanState<int>(0, conduits: [tracker1, tracker2]);

      state.value = 5;

      expect(tracker1.onPipedCalls, hasLength(1));
      expect(tracker2.onPipedCalls, hasLength(1));
      // Both see the same final old/new
      expect(tracker1.onPipedCalls.first, (0, 5));
      expect(tracker2.onPipedCalls.first, (0, 5));
    });

    // -----------------------------------------------------------------------
    // 22. silent() bypasses conduits
    // -----------------------------------------------------------------------
    test('silent() bypasses conduits', () {
      final tracker = _TrackingConduit<int>();
      final state = TitanState<int>(0, conduits: [tracker]);

      state.silent(99);

      expect(state.peek(), 99);
      expect(tracker.pipeCalls, isEmpty);
      expect(tracker.onPipedCalls, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 23. ConduitRejectedException toString formats correctly
    // -----------------------------------------------------------------------
    test('ConduitRejectedException.toString formats correctly', () {
      expect(
        const ConduitRejectedException().toString(),
        'ConduitRejectedException',
      );
      expect(
        const ConduitRejectedException(message: 'bad value').toString(),
        contains('bad value'),
      );
      expect(
        const ConduitRejectedException(rejectedValue: 42).toString(),
        contains('42'),
      );
    });

    // -----------------------------------------------------------------------
    // 24. ClampConduit assertion on invalid range
    // -----------------------------------------------------------------------
    test('ClampConduit asserts min <= max', () {
      expect(
        () => ClampConduit<int>(min: 10, max: 5),
        throwsA(isA<ArgumentError>()),
      );
    });

    // -----------------------------------------------------------------------
    // 25. Conduit with listen callback
    // -----------------------------------------------------------------------
    test('listen callback receives conduit-transformed value', () {
      final state = TitanState<String>('', conduits: [_UpperCaseConduit()]);
      final received = <String>[];
      state.listen((v) => received.add(v));

      state.value = 'hello';
      state.value = 'world';

      expect(received, ['HELLO', 'WORLD']);
    });
  });
}
