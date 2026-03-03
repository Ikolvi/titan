import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Tapestry', () {
    group('append', () {
      test('appends event and assigns sequence number', () {
        final t = Tapestry<String>(name: 'test');
        final seq = t.append('hello');
        expect(seq, 1);
        expect(t.eventCount.value, 1);
        expect(t.lastSequence.value, 1);
        t.dispose();
      });

      test('appendAll assigns sequential numbers', () {
        final t = Tapestry<String>(name: 'test');
        final seqs = t.appendAll(['a', 'b', 'c']);
        expect(seqs, [1, 2, 3]);
        expect(t.eventCount.value, 3);
        expect(t.lastSequence.value, 3);
        t.dispose();
      });

      test('tracks lastEventTime', () {
        final t = Tapestry<String>(name: 'test');
        expect(t.lastEventTime.value, isNull);
        t.append('hello');
        expect(t.lastEventTime.value, isNotNull);
        t.dispose();
      });

      test('correlationId is stored on strand', () {
        final t = Tapestry<String>(name: 'test');
        t.append('event', correlationId: 'tx-123');
        final strand = t.at(1);
        expect(strand?.correlationId, 'tx-123');
        t.dispose();
      });

      test('metadata is stored on strand', () {
        final t = Tapestry<String>(name: 'test');
        t.append('event', metadata: {'key': 'value'});
        final strand = t.at(1);
        expect(strand?.metadata, {'key': 'value'});
        t.dispose();
      });
    });

    group('weave', () {
      test('folds events into projected state', () {
        final t = Tapestry<int>(name: 'test');
        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        t.append(10);
        t.append(20);
        t.append(5);
        expect(sum.state.value, 35);
        expect(sum.version.value, 3);
        t.dispose();
      });

      test('replays existing events on creation', () {
        final t = Tapestry<int>(name: 'test');
        t.appendAll([1, 2, 3]);

        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        expect(sum.state.value, 6);
        expect(sum.version.value, 3);
        t.dispose();
      });

      test('where filter limits which events are folded', () {
        final t = Tapestry<int>(name: 'test');
        final evenSum = t.weave<int>(
          name: 'even',
          initial: 0,
          fold: (s, e) => s + e,
          where: (e) => e.isEven,
        );
        t.appendAll([1, 2, 3, 4, 5, 6]);
        expect(evenSum.state.value, 12); // 2 + 4 + 6
        expect(evenSum.version.value, 3);
        t.dispose();
      });

      test('multiple weaves receive same events', () {
        final t = Tapestry<int>(name: 'test');
        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        final count = t.weave<int>(
          name: 'count',
          initial: 0,
          fold: (s, _) => s + 1,
        );

        t.appendAll([10, 20, 30]);
        expect(sum.state.value, 60);
        expect(count.state.value, 3);
        expect(t.weaveCount.value, 2);
        t.dispose();
      });

      test('lastUpdated is set after fold', () {
        final t = Tapestry<int>(name: 'test');
        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        expect(sum.lastUpdated.value, isNull);
        t.append(1);
        expect(sum.lastUpdated.value, isNotNull);
        t.dispose();
      });
    });

    group('getWeave and removeWeave', () {
      test('getWeave returns existing weave', () {
        final t = Tapestry<int>(name: 'test');
        t.weave<int>(name: 'sum', initial: 0, fold: (s, e) => s + e);
        final w = t.getWeave<int>('sum');
        expect(w, isNotNull);
        expect(w!.name, 'sum');
        t.dispose();
      });

      test('getWeave returns null for unknown', () {
        final t = Tapestry<int>(name: 'test');
        expect(t.getWeave<int>('nope'), isNull);
        t.dispose();
      });

      test('removeWeave decrements weaveCount', () {
        final t = Tapestry<int>(name: 'test');
        t.weave<int>(name: 'sum', initial: 0, fold: (s, e) => s + e);
        expect(t.weaveCount.value, 1);
        t.removeWeave('sum');
        expect(t.weaveCount.value, 0);
        t.dispose();
      });

      test('weaveNames lists all weave names', () {
        final t = Tapestry<int>(name: 'test');
        t.weave<int>(name: 'a', initial: 0, fold: (s, e) => s + e);
        t.weave<int>(name: 'b', initial: 0, fold: (s, e) => s + e);
        expect(t.weaveNames, containsAll(['a', 'b']));
        t.dispose();
      });
    });

    group('query', () {
      test('returns all events without filters', () {
        final t = Tapestry<String>(name: 'test');
        t.appendAll(['a', 'b', 'c']);
        final results = t.query();
        expect(results.length, 3);
        expect(results.map((s) => s.event), ['a', 'b', 'c']);
        t.dispose();
      });

      test('filters by sequence range', () {
        final t = Tapestry<String>(name: 'test');
        t.appendAll(['a', 'b', 'c', 'd', 'e']);
        final results = t.query(fromSequence: 2, toSequence: 4);
        expect(results.map((s) => s.event), ['b', 'c', 'd']);
        t.dispose();
      });

      test('filters by correlationId', () {
        final t = Tapestry<String>(name: 'test');
        t.append('a', correlationId: 'tx-1');
        t.append('b', correlationId: 'tx-2');
        t.append('c', correlationId: 'tx-1');
        final results = t.query(correlationId: 'tx-1');
        expect(results.map((s) => s.event), ['a', 'c']);
        t.dispose();
      });

      test('filters with where predicate', () {
        final t = Tapestry<int>(name: 'test');
        t.appendAll([1, 2, 3, 4, 5]);
        final results = t.query(where: (e) => e > 3);
        expect(results.map((s) => s.event), [4, 5]);
        t.dispose();
      });

      test('respects limit', () {
        final t = Tapestry<int>(name: 'test');
        t.appendAll([1, 2, 3, 4, 5]);
        final results = t.query(limit: 2);
        expect(results.length, 2);
        expect(results.map((s) => s.event), [1, 2]);
        t.dispose();
      });
    });

    group('at', () {
      test('returns strand by sequence', () {
        final t = Tapestry<String>(name: 'test');
        t.appendAll(['a', 'b', 'c']);
        final strand = t.at(2);
        expect(strand?.event, 'b');
        expect(strand?.sequence, 2);
        t.dispose();
      });

      test('returns null for missing sequence', () {
        final t = Tapestry<String>(name: 'test');
        expect(t.at(999), isNull);
        t.dispose();
      });
    });

    group('maxEvents', () {
      test('drops oldest events when exceeded', () {
        final t = Tapestry<int>(name: 'test', maxEvents: 3);
        t.appendAll([1, 2, 3, 4, 5]);
        expect(t.eventCount.value, 3);
        expect(t.events.map((s) => s.event), [3, 4, 5]);
        expect(t.lastSequence.value, 5);
        t.dispose();
      });

      test('projections retain state despite dropped events', () {
        final t = Tapestry<int>(name: 'test', maxEvents: 2);
        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        t.appendAll([10, 20, 30]);
        expect(sum.state.value, 60); // all 3 folded
        expect(t.eventCount.value, 2); // but only 2 stored
        t.dispose();
      });
    });

    group('frame (snapshot)', () {
      test('captures weave state at current sequence', () {
        final t = Tapestry<int>(name: 'test');
        t.weave<int>(name: 'sum', initial: 0, fold: (s, e) => s + e);
        t.appendAll([10, 20]);
        final f = t.frame<int>('sum');
        expect(f.state, 30);
        expect(f.sequence, 2);
        expect(f.weaveName, 'sum');
        t.dispose();
      });

      test('throws for unknown weave', () {
        final t = Tapestry<int>(name: 'test');
        expect(() => t.frame<int>('nope'), throwsArgumentError);
        t.dispose();
      });
    });

    group('replay', () {
      test('replays all events through all weaves', () {
        final t = Tapestry<int>(name: 'test');
        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        t.appendAll([1, 2, 3]);
        expect(sum.state.value, 6);
        expect(sum.version.value, 3);

        t.replay();
        expect(sum.state.value, 6); // same result after replay
        expect(sum.version.value, 3);
        t.dispose();
      });

      test('replay with fromSequence skips early events', () {
        final t = Tapestry<int>(name: 'test');
        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        t.appendAll([10, 20, 30]);

        t.replay(fromSequence: 2);
        expect(sum.state.value, 50); // only 20+30
        expect(sum.version.value, 2);
        t.dispose();
      });
    });

    group('compact', () {
      test('removes events up to sequence', () {
        final t = Tapestry<int>(name: 'test');
        t.appendAll([1, 2, 3, 4, 5]);
        final removed = t.compact(3);
        expect(removed, 3);
        expect(t.eventCount.value, 2);
        expect(t.events.map((s) => s.event), [4, 5]);
        t.dispose();
      });
    });

    group('reset', () {
      test('clears events and resets weaves', () {
        final t = Tapestry<int>(name: 'test');
        final sum = t.weave<int>(
          name: 'sum',
          initial: 0,
          fold: (s, e) => s + e,
        );
        t.appendAll([10, 20]);
        expect(sum.state.value, 30);

        t.reset();
        expect(t.eventCount.value, 0);
        expect(t.lastSequence.value, 0);
        expect(sum.state.value, 0);
        expect(sum.version.value, 0);
        t.dispose();
      });
    });

    group('dispose', () {
      test('sets status to disposed', () {
        final t = Tapestry<int>(name: 'test');
        t.dispose();
        expect(t.status.value, TapestryStatus.disposed);
      });

      test('append after dispose returns -1', () {
        final t = Tapestry<int>(name: 'test');
        t.dispose();
        expect(t.append(42), -1);
      });

      test('managedNodes contains all reactive nodes', () {
        final t = Tapestry<int>(name: 'test');
        t.weave<int>(name: 'w', initial: 0, fold: (s, e) => s + e);
        // 5 store nodes + 3 weave nodes = 8
        expect(t.managedNodes.length, 8);
        t.dispose();
      });
    });

    group('status', () {
      test('initial status is idle', () {
        final t = Tapestry<int>(name: 'test');
        expect(t.status.value, TapestryStatus.idle);
        t.dispose();
      });

      test('status returns to idle after append', () {
        final t = Tapestry<int>(name: 'test');
        t.append(1);
        expect(t.status.value, TapestryStatus.idle);
        t.dispose();
      });
    });

    group('Pillar integration', () {
      test('tapestry() factory registers managed nodes', () {
        final pillar = _TestPillar();
        pillar.initialize();
        expect(pillar.events.eventCount.value, 0);
        pillar.events.append('test');
        expect(pillar.events.eventCount.value, 1);
        pillar.dispose();
      });
    });
  });
}

class _TestPillar extends Pillar {
  late final events = tapestry<String>(name: 'test');
}
