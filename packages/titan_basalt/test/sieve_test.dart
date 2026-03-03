import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

// Test data model
class _Quest {
  const _Quest(this.title, this.description, this.difficulty, this.status);
  final String title;
  final String description;
  final int difficulty;
  final String status;

  @override
  String toString() => '_Quest($title)';
}

const _quests = [
  _Quest('Dragon Hunt', 'Slay the fire dragon', 5, 'active'),
  _Quest('Herb Gathering', 'Collect healing herbs', 1, 'active'),
  _Quest('Escort Mission', 'Escort the merchant', 2, 'completed'),
  _Quest('Dragon Egg', 'Find the dragon egg', 4, 'active'),
  _Quest('Village Defense', 'Defend the village', 3, 'completed'),
  _Quest('Cave Exploration', 'Explore the dark cave', 3, 'active'),
  _Quest('Royal Delivery', 'Deliver a royal message', 1, 'active'),
  _Quest('Boss Battle', 'Defeat the dungeon boss', 5, 'completed'),
];

void main() {
  group('Sieve', () {
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    group('construction', () {
      test('creates with empty items', () {
        final s = Sieve<String>();
        expect(s.results.value, isEmpty);
        expect(s.resultCount.value, 0);
        expect(s.totalCount.value, 0);
      });

      test('creates with initial items', () {
        final s = Sieve<String>(items: ['a', 'b', 'c']);
        expect(s.results.value, ['a', 'b', 'c']);
        expect(s.resultCount.value, 3);
        expect(s.totalCount.value, 3);
      });

      test('creates with name', () {
        final s = Sieve<String>(items: ['a'], name: 'test');
        expect(s.name, 'test');
        expect(s.toString(), contains('test'));
      });
    });

    // -----------------------------------------------------------------------
    // Source data
    // -----------------------------------------------------------------------

    group('source data', () {
      test('setItems updates the dataset', () {
        final s = Sieve<int>(items: [1, 2, 3]);
        expect(s.resultCount.value, 3);

        s.setItems([10, 20, 30, 40]);
        expect(s.resultCount.value, 4);
        expect(s.results.value, [10, 20, 30, 40]);
      });

      test('items Core is reactive', () {
        final s = Sieve<int>(items: [1, 2]);
        expect(s.totalCount.value, 2);

        s.items.value = [1, 2, 3, 4, 5];
        expect(s.totalCount.value, 5);
        expect(s.resultCount.value, 5);
      });
    });

    // -----------------------------------------------------------------------
    // Text search
    // -----------------------------------------------------------------------

    group('text search', () {
      late Sieve<_Quest> s;

      setUp(() {
        s = Sieve<_Quest>(
          items: _quests,
          textFields: [(q) => q.title, (q) => q.description],
        );
      });

      test('returns all items when query is empty', () {
        expect(s.resultCount.value, _quests.length);
      });

      test('filters by title match', () {
        s.query.value = 'dragon';
        expect(s.resultCount.value, 2); // Dragon Hunt, Dragon Egg
        expect(
          s.results.value.map((q) => q.title),
          containsAll(['Dragon Hunt', 'Dragon Egg']),
        );
      });

      test('filters by description match', () {
        s.query.value = 'healing';
        expect(s.resultCount.value, 1);
        expect(s.results.value.first.title, 'Herb Gathering');
      });

      test('search is case-insensitive', () {
        s.query.value = 'DRAGON';
        expect(s.resultCount.value, 2);
      });

      test('search matches partial substrings', () {
        s.query.value = 'rag';
        // Matches 'Dragon Hunt', 'Dragon Egg' (both contain 'rag')
        expect(s.resultCount.value, 2);
      });

      test('clearQuery removes search', () {
        s.query.value = 'dragon';
        expect(s.resultCount.value, 2);

        s.clearQuery();
        expect(s.resultCount.value, _quests.length);
      });

      test('search with no textFields returns all items', () {
        final noText = Sieve<_Quest>(items: _quests);
        noText.query.value = 'dragon';
        // No text fields configured, search has no effect
        expect(noText.resultCount.value, _quests.length);
      });
    });

    // -----------------------------------------------------------------------
    // Predicate filters
    // -----------------------------------------------------------------------

    group('predicate filters', () {
      late Sieve<_Quest> s;

      setUp(() {
        s = Sieve<_Quest>(items: _quests);
      });

      test('where adds a filter', () {
        s.where('active', (q) => q.status == 'active');
        expect(s.resultCount.value, 5); // 5 active quests
      });

      test('multiple filters use AND logic', () {
        s.where('active', (q) => q.status == 'active');
        s.where('hard', (q) => q.difficulty >= 4);
        // Active AND hard: Dragon Hunt (5), Dragon Egg (4)
        expect(s.resultCount.value, 2);
      });

      test('removeWhere removes a specific filter', () {
        s.where('active', (q) => q.status == 'active');
        s.where('hard', (q) => q.difficulty >= 4);
        expect(s.resultCount.value, 2);

        s.removeWhere('hard');
        expect(s.resultCount.value, 5); // Back to just active filter
      });

      test('removeWhere is no-op for unknown key', () {
        s.where('active', (q) => q.status == 'active');
        s.removeWhere('nonexistent');
        expect(s.resultCount.value, 5); // Unchanged
      });

      test('clearFilters removes all filters', () {
        s.where('active', (q) => q.status == 'active');
        s.where('hard', (q) => q.difficulty >= 4);
        expect(s.resultCount.value, 2);

        s.clearFilters();
        expect(s.resultCount.value, _quests.length);
      });

      test('clearFilters is no-op when empty', () {
        s.clearFilters(); // Should not throw
        expect(s.resultCount.value, _quests.length);
      });

      test('replacing a filter updates results', () {
        s.where('difficulty', (q) => q.difficulty >= 4);
        expect(s.resultCount.value, 3); // 4, 5, 5

        s.where('difficulty', (q) => q.difficulty == 5);
        expect(s.resultCount.value, 2); // 5, 5
      });

      test('filterKeys returns active filter names', () {
        s.where('a', (q) => true);
        s.where('b', (q) => true);
        expect(s.filterKeys, containsAll(['a', 'b']));
      });

      test('hasFilter checks filter existence', () {
        expect(s.hasFilter('active'), false);
        s.where('active', (q) => q.status == 'active');
        expect(s.hasFilter('active'), true);
      });

      test('filterCount returns active filter count', () {
        expect(s.filterCount, 0);
        s.where('a', (q) => true);
        s.where('b', (q) => true);
        expect(s.filterCount, 2);
      });
    });

    // -----------------------------------------------------------------------
    // Combined search + filters
    // -----------------------------------------------------------------------

    group('combined search and filters', () {
      test('search AND filter stack together', () {
        final s = Sieve<_Quest>(items: _quests, textFields: [(q) => q.title]);

        s.query.value = 'dragon';
        s.where('active', (q) => q.status == 'active');

        // Dragon Hunt (active) + Dragon Egg (active)
        expect(s.resultCount.value, 2);
      });

      test('filter narrows search results', () {
        final s = Sieve<_Quest>(items: _quests, textFields: [(q) => q.title]);

        s.query.value = 'dragon';
        s.where('easy', (q) => q.difficulty <= 3);

        // No dragon quest is easy (Dragon Hunt=5, Dragon Egg=4)
        expect(s.resultCount.value, 0);
      });
    });

    // -----------------------------------------------------------------------
    // Sort
    // -----------------------------------------------------------------------

    group('sort', () {
      test('sortBy orders results', () {
        final s = Sieve<_Quest>(items: _quests);
        s.sortBy((a, b) => a.difficulty.compareTo(b.difficulty));

        final difficulties = s.results.value.map((q) => q.difficulty).toList();
        expect(difficulties, [1, 1, 2, 3, 3, 4, 5, 5]);
      });

      test('sortBy descending', () {
        final s = Sieve<_Quest>(items: _quests);
        s.sortBy((a, b) => b.difficulty.compareTo(a.difficulty));

        final difficulties = s.results.value.map((q) => q.difficulty).toList();
        expect(difficulties, [5, 5, 4, 3, 3, 2, 1, 1]);
      });

      test('sortBy with null removes sorting', () {
        final s = Sieve<int>(items: [3, 1, 2]);
        s.sortBy((a, b) => a.compareTo(b));
        expect(s.results.value, [1, 2, 3]);

        s.sortBy(null);
        expect(s.results.value, [3, 1, 2]); // Source order
      });

      test('sort applies after filter', () {
        final s = Sieve<_Quest>(items: _quests);
        s.where('active', (q) => q.status == 'active');
        s.sortBy((a, b) => a.difficulty.compareTo(b.difficulty));

        final titles = s.results.value.map((q) => q.title).toList();
        // Active sorted by difficulty: Herb(1), Royal(1), Cave(3), Egg(4), Dragon(5)
        expect(titles.first, 'Herb Gathering');
        expect(titles.last, 'Dragon Hunt');
      });
    });

    // -----------------------------------------------------------------------
    // Reset
    // -----------------------------------------------------------------------

    group('reset', () {
      test('reset clears everything', () {
        final s = Sieve<_Quest>(items: _quests, textFields: [(q) => q.title]);

        s.query.value = 'dragon';
        s.where('active', (q) => q.status == 'active');
        s.sortBy((a, b) => a.difficulty.compareTo(b.difficulty));
        expect(s.resultCount.value, 2);

        s.reset();
        expect(s.resultCount.value, _quests.length);
        expect(s.query.value, '');
        expect(s.filterCount, 0);
      });
    });

    // -----------------------------------------------------------------------
    // Reactive state
    // -----------------------------------------------------------------------

    group('reactive state', () {
      test('isFiltered tracks filter/search state', () {
        final s = Sieve<_Quest>(items: _quests, textFields: [(q) => q.title]);

        expect(s.isFiltered.value, false);

        s.query.value = 'dragon';
        expect(s.isFiltered.value, true);

        s.clearQuery();
        expect(s.isFiltered.value, false);

        s.where('active', (q) => q.status == 'active');
        expect(s.isFiltered.value, true);

        s.clearFilters();
        expect(s.isFiltered.value, false);
      });

      test('totalCount reflects source size', () {
        final s = Sieve<int>(items: [1, 2, 3]);
        expect(s.totalCount.value, 3);

        s.setItems([1, 2, 3, 4, 5]);
        expect(s.totalCount.value, 5);
      });

      test('resultCount tracks filtered count', () {
        final s = Sieve<int>(items: [1, 2, 3, 4, 5]);
        s.where('even', (n) => n.isEven);
        expect(s.resultCount.value, 2); // 2, 4
      });

      test('results returns a copy, not the original', () {
        final s = Sieve<int>(items: [1, 2, 3]);
        final result = s.results.value;
        // Modification shouldn't affect the source
        expect(result, isNot(same(s.items.value)));
      });
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    group('Pillar integration', () {
      test('managedNodes contains all reactive nodes', () {
        final s = Sieve<String>(items: ['a', 'b']);
        final nodes = s.managedNodes.toList();
        // items, query, filterVersion, results, resultCount, totalCount, isFiltered
        expect(nodes.length, 7);
      });

      test('sieve() extension creates managed instance', () {
        final pillar = _TestPillar();

        expect(pillar.questSearch.resultCount.value, 3);
        pillar.questSearch.query.value = 'dragon';
        expect(pillar.questSearch.resultCount.value, 1);

        pillar.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    group('edge cases', () {
      test('empty source with filters returns empty', () {
        final s = Sieve<int>();
        s.where('positive', (n) => n > 0);
        expect(s.results.value, isEmpty);
      });

      test('filter that matches nothing returns empty', () {
        final s = Sieve<int>(items: [1, 2, 3]);
        s.where('impossible', (n) => n > 100);
        expect(s.resultCount.value, 0);
      });

      test('filter that matches everything returns all', () {
        final s = Sieve<int>(items: [1, 2, 3]);
        s.where('all', (n) => true);
        expect(s.resultCount.value, 3);
      });

      test('search with empty textFields ignores query', () {
        final s = Sieve<_Quest>(items: _quests);
        s.query.value = 'dragon';
        expect(s.resultCount.value, _quests.length);
      });

      test('rapid filter changes produce correct results', () {
        final s = Sieve<int>(items: List.generate(100, (i) => i));

        for (var threshold = 0; threshold < 100; threshold += 10) {
          s.where('min', (n) => n >= threshold);
          expect(s.resultCount.value, 100 - threshold);
        }
      });

      test('toString shows counts', () {
        final s = Sieve<int>(items: [1, 2, 3], name: 'nums');
        s.where('even', (n) => n.isEven);
        expect(s.toString(), 'Sieve "nums"(3 items, 1 results, 1 filters)');
      });

      test('large dataset performance', () {
        final items = List.generate(10000, (i) => 'item-$i');
        final s = Sieve<String>(items: items, textFields: [(s) => s]);

        s.query.value = 'item-99';
        // Matches: item-99, item-990, ..., item-9999
        expect(s.resultCount.value, greaterThan(0));
        expect(s.resultCount.value, lessThan(items.length));
      });
    });
  });
}

// Test pillar for integration testing
class _TestPillar extends Pillar {
  late final questSearch = sieve<_Quest>(
    items: const [
      _Quest('Dragon Hunt', 'Slay the dragon', 5, 'active'),
      _Quest('Herb Gathering', 'Collect herbs', 1, 'active'),
      _Quest('Escort', 'Guard the merchant', 2, 'completed'),
    ],
    textFields: [(q) => q.title, (q) => q.description],
    name: 'quests',
  );

  @override
  void onInit() {
    questSearch;
  }
}
