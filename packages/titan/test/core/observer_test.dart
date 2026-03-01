import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  tearDown(() {
    TitanObserver.instance = null;
  });

  group('TitanObserver', () {
    test('instance receives all state changes', () {
      final records = <(String, dynamic, dynamic)>[];
      TitanObserver.instance = _TestObserver(
        onChanged: (state, old, nw) {
          records.add((state.name ?? 'unnamed', old, nw));
        },
      );

      final counter = TitanState(0, name: 'counter');
      counter.value = 1;
      counter.value = 2;

      expect(records, [
        ('counter', 0, 1),
        ('counter', 1, 2),
      ]);

      counter.dispose();
    });

    test('null instance means no observation overhead', () {
      TitanObserver.instance = null;
      final state = TitanState(0);
      // Should not throw
      state.value = 1;
      state.value = 2;
      expect(state.value, 2);
      state.dispose();
    });
  });

  group('TitanLoggingObserver', () {
    test('logs state changes with default format', () {
      final logs = <String>[];
      TitanObserver.instance = TitanLoggingObserver(logger: logs.add);

      final state = TitanState(10, name: 'score');
      state.value = 20;

      expect(logs.length, 1);
      expect(logs[0], contains('score'));
      expect(logs[0], contains('10'));
      expect(logs[0], contains('20'));

      state.dispose();
    });

    test('uses runtimeType when name is null', () {
      final logs = <String>[];
      TitanObserver.instance = TitanLoggingObserver(logger: logs.add);

      final state = TitanState(0);
      state.value = 1;

      expect(logs.length, 1);
      expect(logs[0], contains('TitanState'));

      state.dispose();
    });
  });

  group('TitanHistoryObserver', () {
    test('records state changes in order', () {
      final observer = TitanHistoryObserver();
      TitanObserver.instance = observer;

      final state = TitanState(0, name: 'x');
      state.value = 1;
      state.value = 2;
      state.value = 3;

      expect(observer.length, 3);
      final history = observer.history;
      expect(history[0].oldValue, 0);
      expect(history[0].newValue, 1);
      expect(history[1].oldValue, 1);
      expect(history[1].newValue, 2);
      expect(history[2].oldValue, 2);
      expect(history[2].newValue, 3);

      state.dispose();
    });

    test('ring buffer wraps at capacity', () {
      final observer = TitanHistoryObserver(maxHistory: 3);
      TitanObserver.instance = observer;

      final state = TitanState(0, name: 'x');
      state.value = 1; // entry 0
      state.value = 2; // entry 1
      state.value = 3; // entry 2 — buffer full
      state.value = 4; // entry 3 — overwrites entry 0
      state.value = 5; // entry 4 — overwrites entry 1

      expect(observer.length, 3);
      final history = observer.history;
      // Should contain the 3 most recent, oldest first
      expect(history[0].newValue, 3);
      expect(history[1].newValue, 4);
      expect(history[2].newValue, 5);

      state.dispose();
    });

    test('ring buffer with maxHistory=1 keeps only last', () {
      final observer = TitanHistoryObserver(maxHistory: 1);
      TitanObserver.instance = observer;

      final state = TitanState(0, name: 'x');
      state.value = 1;
      state.value = 2;
      state.value = 3;

      expect(observer.length, 1);
      expect(observer.history[0].newValue, 3);

      state.dispose();
    });

    test('history at exact capacity boundary', () {
      final observer = TitanHistoryObserver(maxHistory: 5);
      TitanObserver.instance = observer;

      final state = TitanState(0, name: 'x');
      // Fill exactly to capacity
      for (var i = 1; i <= 5; i++) {
        state.value = i;
      }

      expect(observer.length, 5);
      final history = observer.history;
      for (var i = 0; i < 5; i++) {
        expect(history[i].newValue, i + 1);
      }

      state.dispose();
    });

    test('history ordering after multiple wrap-arounds', () {
      final observer = TitanHistoryObserver(maxHistory: 3);
      TitanObserver.instance = observer;

      final state = TitanState(0, name: 'x');
      // 10 changes, wraps around ~3 times
      for (var i = 1; i <= 10; i++) {
        state.value = i;
      }

      expect(observer.length, 3);
      final history = observer.history;
      expect(history[0].newValue, 8);
      expect(history[1].newValue, 9);
      expect(history[2].newValue, 10);

      state.dispose();
    });

    test('clear resets buffer and count', () {
      final observer = TitanHistoryObserver(maxHistory: 5);
      TitanObserver.instance = observer;

      final state = TitanState(0, name: 'x');
      state.value = 1;
      state.value = 2;
      state.value = 3;

      expect(observer.length, 3);
      observer.clear();
      expect(observer.length, 0);
      expect(observer.history, isEmpty);

      // Can record again after clear
      state.value = 4;
      expect(observer.length, 1);
      expect(observer.history[0].newValue, 4);

      state.dispose();
    });

    test('records stateName from name or runtimeType', () {
      final observer = TitanHistoryObserver();
      TitanObserver.instance = observer;

      final named = TitanState(0, name: 'myState');
      named.value = 1;
      expect(observer.history[0].stateName, 'myState');

      final unnamed = TitanState(0);
      unnamed.value = 1;
      expect(observer.history[1].stateName, 'TitanState<int>');

      named.dispose();
      unnamed.dispose();
    });

    test('records timestamps', () {
      final observer = TitanHistoryObserver();
      TitanObserver.instance = observer;

      final before = DateTime.now();
      final state = TitanState(0);
      state.value = 1;
      final after = DateTime.now();

      final ts = observer.history[0].timestamp;
      expect(ts.isAfter(before) || ts.isAtSameMomentAs(before), isTrue);
      expect(ts.isBefore(after) || ts.isAtSameMomentAs(after), isTrue);

      state.dispose();
    });
  });

  group('StateChangeRecord', () {
    test('toString includes all fields', () {
      final record = StateChangeRecord(
        stateName: 'counter',
        oldValue: 0,
        newValue: 1,
        timestamp: DateTime(2024, 1, 1),
      );
      final s = record.toString();
      expect(s, contains('counter'));
      expect(s, contains('0'));
      expect(s, contains('1'));
    });
  });
}

class _TestObserver extends TitanObserver {
  final void Function(TitanState state, dynamic oldValue, dynamic newValue)
      onChanged;

  _TestObserver({required this.onChanged});

  @override
  void onStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    onChanged(state, oldValue, newValue);
  }
}
