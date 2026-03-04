import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Arbiter', () {
    late Arbiter<String> arbiter;

    setUp(() {
      arbiter = Arbiter<String>(strategy: ArbiterStrategy.lastWriteWins);
    });

    tearDown(() => arbiter.dispose());

    // ─── Construction ─────────────────────────────────────────

    test('initial state is empty', () {
      expect(arbiter.conflictCount.value, 0);
      expect(arbiter.lastResolution.value, isNull);
      expect(arbiter.hasConflicts.value, isFalse);
      expect(arbiter.totalResolved.value, 0);
      expect(arbiter.pending, isEmpty);
      expect(arbiter.sources, isEmpty);
      expect(arbiter.history, isEmpty);
    });

    // ─── Submit ───────────────────────────────────────────────

    test('single submit does not create conflict', () {
      arbiter.submit('local', 'hello');
      expect(arbiter.conflictCount.value, 1);
      expect(arbiter.hasConflicts.value, isFalse);
      expect(arbiter.pending, hasLength(1));
      expect(arbiter.sources, ['local']);
    });

    test('two submits create a conflict', () {
      arbiter.submit('local', 'hello');
      arbiter.submit('server', 'world');
      expect(arbiter.conflictCount.value, 2);
      expect(arbiter.hasConflicts.value, isTrue);
    });

    test('same source replaces previous submission', () {
      arbiter.submit('local', 'first');
      arbiter.submit('local', 'second');
      expect(arbiter.conflictCount.value, 1);
      expect(arbiter.pending.first.value, 'second');
    });

    test('submit with custom timestamp', () {
      final ts = DateTime(2024, 1, 1);
      arbiter.submit('local', 'hello', timestamp: ts);
      expect(arbiter.pending.first.timestamp, ts);
    });

    // ─── Last Write Wins ──────────────────────────────────────

    test('lastWriteWins resolves to most recent', () {
      arbiter.submit('local', 'old', timestamp: DateTime(2024, 1, 1));
      arbiter.submit('server', 'new', timestamp: DateTime(2024, 1, 2));

      final result = arbiter.resolve();

      expect(result, isNotNull);
      expect(result!.resolved, 'new');
      expect(result.strategy, ArbiterStrategy.lastWriteWins);
      expect(result.candidates, hasLength(2));
      expect(arbiter.conflictCount.value, 0);
      expect(arbiter.hasConflicts.value, isFalse);
      expect(arbiter.totalResolved.value, 1);
      expect(arbiter.lastResolution.value, result);
    });

    // ─── First Write Wins ─────────────────────────────────────

    test('firstWriteWins resolves to earliest', () {
      final a = Arbiter<String>(strategy: ArbiterStrategy.firstWriteWins);
      addTearDown(a.dispose);

      a.submit('local', 'old', timestamp: DateTime(2024, 1, 1));
      a.submit('server', 'new', timestamp: DateTime(2024, 1, 2));

      final result = a.resolve();
      expect(result!.resolved, 'old');
      expect(result.strategy, ArbiterStrategy.firstWriteWins);
    });

    // ─── Merge ────────────────────────────────────────────────

    test('merge strategy uses callback', () {
      final a = Arbiter<String>(
        strategy: ArbiterStrategy.merge,
        merge: (candidates) => candidates.map((c) => c.value).join('+'),
      );
      addTearDown(a.dispose);

      a.submit('a', 'hello');
      a.submit('b', 'world');

      final result = a.resolve();
      expect(result!.resolved, 'hello+world');
      expect(result.strategy, ArbiterStrategy.merge);
    });

    test('merge with no callback throws assertion', () {
      expect(
        () => Arbiter<String>(strategy: ArbiterStrategy.merge),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ─── Manual ───────────────────────────────────────────────

    test('manual strategy returns null on resolve', () {
      final a = Arbiter<String>(strategy: ArbiterStrategy.manual);
      addTearDown(a.dispose);

      a.submit('local', 'hello');
      a.submit('server', 'world');

      expect(a.resolve(), isNull);
      expect(a.hasConflicts.value, isTrue); // Still unresolved
    });

    test('accept picks specific source', () {
      final a = Arbiter<String>(strategy: ArbiterStrategy.manual);
      addTearDown(a.dispose);

      a.submit('local', 'hello');
      a.submit('server', 'world');

      final result = a.accept('local');
      expect(result, isNotNull);
      expect(result!.resolved, 'hello');
      expect(result.candidates, hasLength(2));
      expect(a.conflictCount.value, 0);
      expect(a.totalResolved.value, 1);
    });

    test('accept with unknown source returns null', () {
      final a = Arbiter<String>(strategy: ArbiterStrategy.manual);
      addTearDown(a.dispose);

      a.submit('local', 'hello');
      expect(a.accept('unknown'), isNull);
    });

    // ─── Auto Resolve ─────────────────────────────────────────

    test('autoResolve resolves on second submit', () {
      final a = Arbiter<String>(
        strategy: ArbiterStrategy.lastWriteWins,
        autoResolve: true,
      );
      addTearDown(a.dispose);

      a.submit('local', 'old', timestamp: DateTime(2024, 1, 1));
      final result = a.submit('server', 'new', timestamp: DateTime(2024, 1, 2));

      expect(result, isNotNull);
      expect(result!.resolved, 'new');
      expect(a.conflictCount.value, 0);
      expect(a.totalResolved.value, 1);
    });

    test('autoResolve does not trigger on first submit', () {
      final a = Arbiter<String>(
        strategy: ArbiterStrategy.lastWriteWins,
        autoResolve: true,
      );
      addTearDown(a.dispose);

      final result = a.submit('local', 'only');
      expect(result, isNull);
      expect(a.conflictCount.value, 1);
    });

    // ─── History ──────────────────────────────────────────────

    test('history accumulates resolutions', () {
      arbiter.submit('a', 'v1');
      arbiter.submit('b', 'v2');
      arbiter.resolve();

      arbiter.submit('c', 'v3');
      arbiter.submit('d', 'v4');
      arbiter.resolve();

      expect(arbiter.history, hasLength(2));
      expect(arbiter.totalResolved.value, 2);
    });

    // ─── Resolve with no submissions ──────────────────────────

    test('resolve with no submissions returns null', () {
      expect(arbiter.resolve(), isNull);
    });

    test('resolve with single submission still resolves', () {
      arbiter.submit('local', 'only');
      final result = arbiter.resolve();
      expect(result, isNotNull);
      expect(result!.resolved, 'only');
    });

    // ─── Reset ────────────────────────────────────────────────

    test('reset clears all state', () {
      arbiter.submit('a', 'v1');
      arbiter.submit('b', 'v2');
      arbiter.resolve();
      arbiter.submit('c', 'v3');

      arbiter.reset();

      expect(arbiter.conflictCount.value, 0);
      expect(arbiter.lastResolution.value, isNull);
      expect(arbiter.hasConflicts.value, isFalse);
      expect(arbiter.totalResolved.value, 0);
      expect(arbiter.pending, isEmpty);
      expect(arbiter.history, isEmpty);
    });

    // ─── Three-way conflict ───────────────────────────────────

    test('resolves three-way conflict with lastWriteWins', () {
      arbiter.submit('a', 'v1', timestamp: DateTime(2024, 1, 1));
      arbiter.submit('b', 'v2', timestamp: DateTime(2024, 1, 3));
      arbiter.submit('c', 'v3', timestamp: DateTime(2024, 1, 2));

      final result = arbiter.resolve();
      expect(result!.resolved, 'v2'); // Jan 3 is latest
      expect(result.candidates, hasLength(3));
    });

    // ─── Dispose ──────────────────────────────────────────────

    test('dispose prevents further use', () {
      arbiter.dispose();
      expect(() => arbiter.submit('a', 'v'), throwsA(isA<StateError>()));
    });

    test('double dispose is safe', () {
      arbiter.dispose();
      arbiter.dispose(); // No throw
    });

    // ─── Pillar Integration ───────────────────────────────────

    test('managedNodes exposes all reactive nodes', () {
      expect(arbiter.managedNodes, hasLength(4));
    });

    // ─── Pillar extension creates lifecycle-managed Arbiter ───

    test('Pillar extension creates lifecycle-managed Arbiter', () {
      final pillar = _TestPillar();
      pillar.initialize();

      pillar.sync.submit('local', 'hello');
      pillar.sync.submit('server', 'world');
      expect(pillar.sync.hasConflicts.value, isTrue);

      final result = pillar.sync.resolve();
      expect(result!.resolved, 'world');

      pillar.dispose();
    });

    // ─── ArbiterConflict toString ─────────────────────────────

    test('ArbiterConflict toString', () {
      final c = ArbiterConflict<String>(
        source: 'local',
        value: 'hello',
        timestamp: DateTime.now(),
      );
      expect(c.toString(), contains('local'));
      expect(c.toString(), contains('hello'));
    });

    // ─── ArbiterResolution toString ───────────────────────────

    test('ArbiterResolution toString', () {
      arbiter.submit('a', 'v1');
      arbiter.submit('b', 'v2');
      final result = arbiter.resolve()!;
      expect(result.toString(), contains('lastWriteWins'));
      expect(result.toString(), contains('2 candidates'));
    });
  });
}

class _TestPillar extends Pillar {
  late final sync = arbiter<String>(strategy: ArbiterStrategy.lastWriteWins);
}
