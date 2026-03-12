import 'dart:convert';

import 'package:test/test.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Annals', () {
    setUp(() {
      Annals.dispose();
    });

    tearDown(() {
      Annals.dispose();
    });

    test('starts disabled', () {
      expect(Annals.isEnabled, isFalse);
      expect(Annals.length, 0);
    });

    test('enable and disable', () {
      Annals.enable();
      expect(Annals.isEnabled, isTrue);

      Annals.disable();
      expect(Annals.isEnabled, isFalse);
    });

    test('does not record when disabled', () {
      final entry = AnnalEntry(
        coreName: 'count',
        pillarType: 'TestPillar',
        oldValue: 0,
        newValue: 1,
        action: 'set',
      );

      Annals.record(entry);
      expect(Annals.length, 0);
    });

    test('records entries when enabled', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'TestPillar',
          oldValue: 0,
          newValue: 1,
          action: 'increment',
        ),
      );

      Annals.record(
        AnnalEntry(
          coreName: 'name',
          pillarType: 'TestPillar',
          oldValue: 'Alice',
          newValue: 'Bob',
          action: 'rename',
        ),
      );

      expect(Annals.length, 2);
      expect(Annals.entries.first.coreName, 'count');
      expect(Annals.entries.last.coreName, 'name');
    });

    test('entries list is unmodifiable', () {
      Annals.enable();
      Annals.record(
        AnnalEntry(
          coreName: 'test',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );

      expect(
        () => Annals.entries.add(
          AnnalEntry(
            coreName: 'hack',
            pillarType: 'P',
            oldValue: 0,
            newValue: 1,
            action: 'set',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('evicts oldest entries when maxEntries reached', () {
      Annals.enable(maxEntries: 3);

      for (var i = 0; i < 5; i++) {
        Annals.record(
          AnnalEntry(
            coreName: 'item$i',
            pillarType: 'P',
            oldValue: null,
            newValue: i,
            action: 'set',
          ),
        );
      }

      expect(Annals.length, 3);
      expect(Annals.entries[0].coreName, 'item2');
      expect(Annals.entries[1].coreName, 'item3');
      expect(Annals.entries[2].coreName, 'item4');
    });

    test('query filters by coreName', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'name',
          pillarType: 'P',
          oldValue: '',
          newValue: 'test',
          action: 'set',
        ),
      );

      final results = Annals.query(coreName: 'count');
      expect(results.length, 1);
      expect(results.first.coreName, 'count');
    });

    test('query filters by pillarType', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'a',
          pillarType: 'AuthPillar',
          oldValue: null,
          newValue: 1,
          action: 'set',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'b',
          pillarType: 'CartPillar',
          oldValue: null,
          newValue: 2,
          action: 'set',
        ),
      );

      final results = Annals.query(pillarType: 'AuthPillar');
      expect(results.length, 1);
      expect(results.first.pillarType, 'AuthPillar');
    });

    test('query filters by action', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'increment',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'P',
          oldValue: 1,
          newValue: 0,
          action: 'reset',
        ),
      );

      final results = Annals.query(action: 'reset');
      expect(results.length, 1);
      expect(results.first.newValue, 0);
    });

    test('query filters by userId', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'a',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
          userId: 'user1',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'b',
          pillarType: 'P',
          oldValue: 0,
          newValue: 2,
          action: 'set',
          userId: 'user2',
        ),
      );

      final results = Annals.query(userId: 'user1');
      expect(results.length, 1);
      expect(results.first.coreName, 'a');
    });

    test('query filters by time range', () {
      Annals.enable();

      final before = DateTime.now().subtract(const Duration(seconds: 1));
      Annals.record(
        AnnalEntry(
          coreName: 'early',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'late',
          pillarType: 'P',
          oldValue: 0,
          newValue: 2,
          action: 'set',
        ),
      );
      final after = DateTime.now().add(const Duration(seconds: 1));

      // All entries should be between before and after
      final all = Annals.query(after: before, before: after);
      expect(all.length, 2);

      // Only entries before far past should return none
      final farPast = DateTime(2000);
      final noneBeforeFarPast = Annals.query(before: farPast);
      expect(noneBeforeFarPast.length, 0);
    });

    test('query with limit', () {
      Annals.enable();

      for (var i = 0; i < 10; i++) {
        Annals.record(
          AnnalEntry(
            coreName: 'item$i',
            pillarType: 'P',
            oldValue: null,
            newValue: i,
            action: 'set',
          ),
        );
      }

      final results = Annals.query(limit: 3);
      expect(results.length, 3);
    });

    test('stream emits entries', () async {
      Annals.enable();

      final entries = <AnnalEntry>[];
      final sub = Annals.stream.listen(entries.add);

      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(entries.length, 1);
      expect(entries.first.coreName, 'count');

      await sub.cancel();
    });

    test('export converts entries to maps', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'TestPillar',
          oldValue: 0,
          newValue: 1,
          action: 'increment',
          userId: 'admin',
        ),
      );

      final exported = Annals.export();
      expect(exported.length, 1);
      expect(exported.first['coreName'], 'count');
      expect(exported.first['pillarType'], 'TestPillar');
      expect(exported.first['oldValue'], '0');
      expect(exported.first['newValue'], '1');
      expect(exported.first['action'], 'increment');
      expect(exported.first['userId'], 'admin');
    });

    test('clear removes all entries', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'test',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );

      expect(Annals.length, 1);
      Annals.clear();
      expect(Annals.length, 0);
      expect(Annals.isEnabled, isTrue); // Still enabled
    });

    test('reset clears entries and disables', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'test',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );

      Annals.reset();
      expect(Annals.length, 0);
      expect(Annals.isEnabled, isFalse);
    });

    test('AnnalEntry toMap includes all fields', () {
      final entry = AnnalEntry(
        coreName: 'count',
        pillarType: 'TestPillar',
        oldValue: 0,
        newValue: 1,
        action: 'increment',
        userId: 'admin',
        metadata: {'source': 'button'},
      );

      final map = entry.toMap();
      expect(map['coreName'], 'count');
      expect(map['pillarType'], 'TestPillar');
      expect(map['oldValue'], '0');
      expect(map['newValue'], '1');
      expect(map['action'], 'increment');
      expect(map['userId'], 'admin');
      expect(map['metadata'], {'source': 'button'});
      expect(map.containsKey('timestamp'), isTrue);
    });

    test('combined query filters', () {
      Annals.enable();

      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'AuthPillar',
          oldValue: 0,
          newValue: 1,
          action: 'login',
          userId: 'user1',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'CartPillar',
          oldValue: 0,
          newValue: 1,
          action: 'add',
          userId: 'user1',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'session',
          pillarType: 'AuthPillar',
          oldValue: null,
          newValue: 'token',
          action: 'login',
          userId: 'user2',
        ),
      );

      final results = Annals.query(pillarType: 'AuthPillar', action: 'login');
      expect(results.length, 2);

      final results2 = Annals.query(pillarType: 'AuthPillar', userId: 'user1');
      expect(results2.length, 1);
      expect(results2.first.coreName, 'count');
    });

    test('dispose closes stream and clears entries', () {
      Annals.enable();
      Annals.record(
        AnnalEntry(
          coreName: 'test',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );

      Annals.dispose();
      expect(Annals.length, 0);
      expect(Annals.isEnabled, isFalse);
    });

    test('stream works after dispose and re-enable', () async {
      Annals.enable();
      Annals.dispose();

      // Re-enable after dispose
      Annals.enable();
      final entries = <AnnalEntry>[];
      final sub = Annals.stream.listen(entries.add);

      Annals.record(
        AnnalEntry(
          coreName: 'after',
          pillarType: 'P',
          oldValue: 0,
          newValue: 1,
          action: 'set',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(entries.length, 1);
      expect(entries.first.coreName, 'after');

      await sub.cancel();
    });

    test('export with pillarType filter', () {
      Annals.enable();
      Annals.record(
        AnnalEntry(
          coreName: 'a',
          pillarType: 'AuthPillar',
          oldValue: 0,
          newValue: 1,
          action: 'login',
        ),
      );
      Annals.record(
        AnnalEntry(
          coreName: 'b',
          pillarType: 'CartPillar',
          oldValue: 0,
          newValue: 2,
          action: 'add',
        ),
      );

      final exported = Annals.export(pillarType: 'CartPillar');
      expect(exported.length, 1);
      expect(exported.first['coreName'], 'b');
    });

    test('AnnalEntry toString format', () {
      final entry = AnnalEntry(
        coreName: 'count',
        pillarType: 'P',
        oldValue: 0,
        newValue: 1,
        action: 'set',
      );
      expect(entry.toString(), contains('count'));
      expect(entry.toString(), contains('[set]'));
    });

    test('AnnalEntry without optional fields', () {
      final entry = AnnalEntry(coreName: 'count', oldValue: 0, newValue: 1);
      expect(entry.pillarType, isNull);
      expect(entry.action, isNull);
      expect(entry.userId, isNull);
      expect(entry.metadata, isNull);

      final map = entry.toMap();
      expect(map.containsKey('pillarType'), isFalse);
      expect(map.containsKey('action'), isFalse);
      expect(map.containsKey('userId'), isFalse);
      expect(map.containsKey('metadata'), isFalse);
    });

    test('query with limit returns most recent matches', () {
      Annals.enable();
      for (var i = 0; i < 10; i++) {
        Annals.record(
          AnnalEntry(
            coreName: 'item$i',
            pillarType: 'P',
            oldValue: null,
            newValue: i,
            action: 'set',
          ),
        );
      }

      final results = Annals.query(limit: 3);
      expect(results.length, 3);
      // Should be the last 3 entries
      expect(results[0].coreName, 'item7');
      expect(results[1].coreName, 'item8');
      expect(results[2].coreName, 'item9');
    });

    test('maxEntries getter returns configured value', () {
      Annals.enable(maxEntries: 500);
      expect(Annals.maxEntries, 500);
    });

    group('indexed mode', () {
      test('isIndexed defaults to false', () {
        Annals.enable();
        expect(Annals.isIndexed, isFalse);
      });

      test('enable with indexed: true sets isIndexed', () {
        Annals.enable(indexed: true);
        expect(Annals.isIndexed, isTrue);
      });

      test('indexed query by pillarType returns correct entries', () {
        Annals.enable(indexed: true);

        for (var i = 0; i < 10; i++) {
          Annals.record(
            AnnalEntry(
              coreName: 'item$i',
              pillarType: i.isEven ? 'EvenPillar' : 'OddPillar',
              oldValue: i,
              newValue: i + 1,
            ),
          );
        }

        final evens = Annals.query(pillarType: 'EvenPillar');
        expect(evens, hasLength(5));
        expect(evens.every((e) => e.pillarType == 'EvenPillar'), isTrue);

        final odds = Annals.query(pillarType: 'OddPillar');
        expect(odds, hasLength(5));
      });

      test('indexed query with limit returns most recent', () {
        Annals.enable(indexed: true);

        for (var i = 0; i < 20; i++) {
          Annals.record(
            AnnalEntry(
              coreName: 'item$i',
              pillarType: 'TestPillar',
              oldValue: i,
              newValue: i + 1,
            ),
          );
        }

        final result = Annals.query(pillarType: 'TestPillar', limit: 3);
        expect(result, hasLength(3));
        expect(result[0].coreName, 'item17');
        expect(result[2].coreName, 'item19');
      });

      test(
        'indexed query with additional filters uses index-assisted path',
        () {
          Annals.enable(indexed: true);

          for (var i = 0; i < 10; i++) {
            Annals.record(
              AnnalEntry(
                coreName: 'item$i',
                pillarType: 'TestPillar',
                oldValue: i,
                newValue: i + 1,
                action: i.isEven ? 'update' : 'delete',
              ),
            );
          }

          final result = Annals.query(
            pillarType: 'TestPillar',
            action: 'update',
          );
          expect(result, hasLength(5));
          expect(result.every((e) => e.action == 'update'), isTrue);
        },
      );

      test('indexed query returns empty for unknown pillarType', () {
        Annals.enable(indexed: true);

        Annals.record(
          AnnalEntry(
            coreName: 'x',
            pillarType: 'Known',
            oldValue: 0,
            newValue: 1,
          ),
        );

        final result = Annals.query(pillarType: 'Unknown');
        expect(result, isEmpty);
      });

      test('index handles eviction correctly', () {
        Annals.enable(maxEntries: 5, indexed: true);

        for (var i = 0; i < 10; i++) {
          Annals.record(
            AnnalEntry(
              coreName: 'item$i',
              pillarType: 'TestPillar',
              oldValue: i,
              newValue: i + 1,
            ),
          );
        }

        // Only last 5 should remain
        expect(Annals.length, 5);
        final result = Annals.query(pillarType: 'TestPillar');
        expect(result, hasLength(5));
        expect(result.first.coreName, 'item5');
      });

      test('reset clears index and disables indexed mode', () {
        Annals.enable(indexed: true);
        Annals.record(
          AnnalEntry(
            coreName: 'x',
            pillarType: 'Pillar',
            oldValue: 0,
            newValue: 1,
          ),
        );

        Annals.reset();

        expect(Annals.isIndexed, isFalse);
        Annals.enable(indexed: true);
        final result = Annals.query(pillarType: 'Pillar');
        expect(result, isEmpty);
      });
    });

    group('exportToBuffer', () {
      test('writes valid JSON array', () {
        Annals.enable();
        Annals.record(
          AnnalEntry(
            coreName: 'balance',
            oldValue: 100,
            newValue: 200,
            action: 'deposit',
          ),
        );
        Annals.record(
          AnnalEntry(coreName: 'name', oldValue: 'Alice', newValue: 'Bob'),
        );

        final buffer = StringBuffer();
        Annals.exportToBuffer(buffer);
        final json = buffer.toString();

        // Must be valid JSON
        final parsed = jsonDecode(json) as List;
        expect(parsed, hasLength(2));
        expect(parsed[0]['coreName'], 'balance');
        expect(parsed[1]['coreName'], 'name');
      });

      test('writes empty array when no entries', () {
        Annals.enable();
        final buffer = StringBuffer();
        Annals.exportToBuffer(buffer);
        expect(buffer.toString(), '[]');
      });

      test('exportToBuffer with pillarType filter', () {
        Annals.enable();
        for (var i = 0; i < 5; i++) {
          Annals.record(
            AnnalEntry(
              coreName: 'item$i',
              pillarType: i.isEven ? 'Alpha' : 'Beta',
              oldValue: i,
              newValue: i + 1,
            ),
          );
        }

        final buffer = StringBuffer();
        Annals.exportToBuffer(buffer, pillarType: 'Alpha');
        final parsed = jsonDecode(buffer.toString()) as List;
        expect(parsed, hasLength(3));
        expect(
          parsed.every(
            (e) => (e as Map<String, dynamic>)['pillarType'] == 'Alpha',
          ),
          isTrue,
        );
      });

      test('handles special characters in values', () {
        Annals.enable();
        Annals.record(
          AnnalEntry(
            coreName: 'test',
            oldValue: 'line1\nline2',
            newValue: 'has "quotes"',
          ),
        );

        final buffer = StringBuffer();
        Annals.exportToBuffer(buffer);
        final json = buffer.toString();

        // Must be valid JSON
        final parsed = jsonDecode(json) as List;
        expect(parsed, hasLength(1));

        // jsonDecode unescapes the content — verify round-trip integrity
        expect(parsed[0]['oldValue'], contains('line1'));
        expect(parsed[0]['oldValue'], contains('line2'));
        expect(parsed[0]['newValue'], contains('quotes'));
      });
    });
  });
}
