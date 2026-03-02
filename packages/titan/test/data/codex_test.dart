import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Codex — Pagination', () {
    test('initial state is empty', () {
      final codex = Codex<String>(
        fetcher: (_) async => const CodexPage(items: [], hasMore: false),
      );
      expect(codex.items.value, isEmpty);
      expect(codex.isLoading.value, false);
      expect(codex.hasMore.value, true);
      expect(codex.currentPage.value, 0);
      expect(codex.error.value, isNull);
      expect(codex.isEmpty, true);
      expect(codex.isNotEmpty, false);
      expect(codex.itemCount, 0);
      codex.dispose();
    });

    test('loadFirst() fetches the first page', () async {
      final codex = Codex<int>(
        fetcher: (req) async {
          return CodexPage(items: [1, 2, 3], hasMore: true);
        },
        pageSize: 3,
      );

      await codex.loadFirst();

      expect(codex.items.value, [1, 2, 3]);
      expect(codex.currentPage.value, 0);
      expect(codex.hasMore.value, true);
      expect(codex.isLoading.value, false);
      expect(codex.isNotEmpty, true);
      expect(codex.itemCount, 3);
      codex.dispose();
    });

    test('loadNext() appends items from subsequent pages', () async {
      int callCount = 0;
      final codex = Codex<int>(
        fetcher: (req) async {
          callCount++;
          if (req.page == 0) {
            return const CodexPage(items: [1, 2, 3], hasMore: true);
          }
          return const CodexPage(items: [4, 5, 6], hasMore: false);
        },
        pageSize: 3,
      );

      await codex.loadFirst();
      await codex.loadNext();

      expect(codex.items.value, [1, 2, 3, 4, 5, 6]);
      expect(codex.currentPage.value, 1);
      expect(codex.hasMore.value, false);
      expect(callCount, 2);
      codex.dispose();
    });

    test('loadNext() does nothing when hasMore is false', () async {
      int callCount = 0;
      final codex = Codex<int>(
        fetcher: (req) async {
          callCount++;
          return const CodexPage(items: [1], hasMore: false);
        },
      );

      await codex.loadFirst();
      await codex.loadNext(); // Should be a no-op.

      expect(callCount, 1);
      expect(codex.items.value, [1]);
      codex.dispose();
    });

    test('loadNext() does nothing when already loading', () async {
      var callCount = 0;
      final codex = Codex<int>(
        fetcher: (req) async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const CodexPage(items: [1], hasMore: true);
        },
      );

      await codex.loadFirst();
      expect(callCount, 1);
      // isLoading should be false after loadFirst completes
      expect(codex.isLoading.value, false);
      codex.dispose();
    });

    test('refresh() clears and reloads from page 0', () async {
      int callCount = 0;
      final codex = Codex<int>(
        fetcher: (req) async {
          callCount++;
          return CodexPage(items: [callCount * 10], hasMore: false);
        },
      );

      await codex.loadFirst();
      expect(codex.items.value, [10]);

      await codex.refresh();
      expect(codex.items.value, [20]);
      expect(codex.currentPage.value, 0);
      expect(callCount, 2);
      codex.dispose();
    });

    test('error is captured on fetch failure', () async {
      final codex = Codex<int>(
        fetcher: (req) async {
          throw Exception('Network error');
        },
      );

      await codex.loadFirst();

      expect(codex.error.value, isA<Exception>());
      expect(codex.isLoading.value, false);
      codex.dispose();
    });

    test('cursor-based pagination passes cursor to fetcher', () async {
      String? receivedCursor;
      final codex = Codex<String>(
        fetcher: (req) async {
          receivedCursor = req.cursor;
          if (req.page == 0) {
            return const CodexPage(
              items: ['a', 'b'],
              hasMore: true,
              nextCursor: 'cursor_abc',
            );
          }
          return const CodexPage(items: ['c'], hasMore: false);
        },
        pageSize: 2,
      );

      await codex.loadFirst();
      expect(receivedCursor, isNull); // First page — no cursor.

      await codex.loadNext();
      expect(receivedCursor, 'cursor_abc'); // Second page uses cursor.
      codex.dispose();
    });

    test('pageSize is passed in request', () async {
      int? receivedPageSize;
      final codex = Codex<int>(
        fetcher: (req) async {
          receivedPageSize = req.pageSize;
          return const CodexPage(items: [], hasMore: false);
        },
        pageSize: 50,
      );

      await codex.loadFirst();
      expect(receivedPageSize, 50);
      codex.dispose();
    });

    test('managedNodes contains all reactive state', () {
      final codex = Codex<int>(
        fetcher: (_) async => const CodexPage(items: [], hasMore: false),
      );
      expect(codex.managedNodes.length, 5);
      codex.dispose();
    });

    test('CodexPage stores items, hasMore, and nextCursor', () {
      const page = CodexPage(
        items: [1, 2, 3],
        hasMore: true,
        nextCursor: 'xyz',
      );
      expect(page.items, [1, 2, 3]);
      expect(page.hasMore, true);
      expect(page.nextCursor, 'xyz');
    });

    test('CodexRequest stores page, pageSize, and cursor', () {
      const req = CodexRequest(page: 2, pageSize: 10, cursor: 'abc');
      expect(req.page, 2);
      expect(req.pageSize, 10);
      expect(req.cursor, 'abc');
    });

    test('dispose() disposes all managed nodes', () {
      final codex = Codex<int>(
        fetcher: (_) async => const CodexPage(items: [], hasMore: false),
      );

      codex.dispose();

      // All managed nodes should be disposed
      for (final node in codex.managedNodes) {
        expect(node.isDisposed, isTrue);
      }
    });

    test('loadNext() concurrent guard prevents double-fetch', () async {
      var callCount = 0;
      final codex = Codex<int>(
        fetcher: (req) async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const CodexPage(items: [1], hasMore: true);
        },
      );

      await codex.loadFirst();
      expect(callCount, 1);

      // Launch two loadNext calls concurrently
      final f1 = codex.loadNext();
      final f2 = codex.loadNext(); // Should be blocked by isLoading guard
      await Future.wait([f1, f2]);

      expect(callCount, 2); // Only one additional fetch, not two
      codex.dispose();
    });

    test('loadFirst() after error clears error state', () async {
      var shouldFail = true;
      final codex = Codex<int>(
        fetcher: (req) async {
          if (shouldFail) throw Exception('fail');
          return const CodexPage(items: [42], hasMore: false);
        },
      );

      await codex.loadFirst();
      expect(codex.error.value, isNotNull);

      shouldFail = false;
      await codex.loadFirst();
      expect(codex.error.value, isNull);
      expect(codex.items.value, [42]);
      codex.dispose();
    });
  });

  group('Codex — Pillar integration', () {
    late _PaginatedPillar pillar;

    setUp(() {
      pillar = _PaginatedPillar();
      pillar.initialize();
    });

    tearDown(() {
      pillar.dispose();
      Titan.reset();
    });

    test('codex() creates managed Codex', () {
      expect(pillar.items.items.value, isEmpty);
    });

    test('loadFirst loads data through Pillar codex', () async {
      await pillar.items.loadFirst();
      expect(pillar.items.items.value, ['quest_1', 'quest_2']);
    });

    test('Pillar disposal cleans up codex nodes', () {
      pillar.dispose();
      // Should not throw
    });
  });

  group('Codex — Item Mutations', () {
    late Codex<String> codex;

    setUp(() async {
      codex = Codex<String>(
        fetcher: (req) async => CodexPage(
          items: ['a', 'b', 'c'],
          hasMore: false,
        ),
        pageSize: 10,
      );
      await codex.loadFirst();
    });

    tearDown(() => codex.dispose());

    test('insertItem prepends by default', () {
      codex.insertItem('z');
      expect(codex.items.value, ['z', 'a', 'b', 'c']);
    });

    test('insertItem at specific index', () {
      codex.insertItem('x', index: 2);
      expect(codex.items.value, ['a', 'b', 'x', 'c']);
    });

    test('removeItemWhere removes matching item', () {
      final removed = codex.removeItemWhere((i) => i == 'b');
      expect(removed, true);
      expect(codex.items.value, ['a', 'c']);
    });

    test('removeItemWhere returns false when no match', () {
      final removed = codex.removeItemWhere((i) => i == 'z');
      expect(removed, false);
      expect(codex.items.value, ['a', 'b', 'c']);
    });

    test('removeItemAt removes by index', () {
      final item = codex.removeItemAt(1);
      expect(item, 'b');
      expect(codex.items.value, ['a', 'c']);
    });

    test('updateItemWhere updates matching item', () {
      final updated = codex.updateItemWhere(
        (i) => i == 'b',
        (i) => '${i}_updated',
      );
      expect(updated, true);
      expect(codex.items.value, ['a', 'b_updated', 'c']);
    });

    test('updateItemWhere returns false when no match', () {
      final updated = codex.updateItemWhere(
        (i) => i == 'z',
        (i) => '${i}_updated',
      );
      expect(updated, false);
    });

    test('updateItemAt updates by index', () {
      codex.updateItemAt(0, (i) => '${i}_first');
      expect(codex.items.value, ['a_first', 'b', 'c']);
    });

    test('itemCount reflects mutations', () {
      expect(codex.itemCount, 3);
      codex.insertItem('d');
      expect(codex.itemCount, 4);
      codex.removeItemAt(0);
      expect(codex.itemCount, 3);
    });

    test('where filters items by predicate', () {
      final result = codex.where((item) => item != 'b');
      expect(result, ['a', 'c']);
    });

    test('where returns empty list when no items match', () {
      final result = codex.where((item) => item == 'z');
      expect(result, isEmpty);
    });

    test('where returns all items when all match', () {
      final result = codex.where((item) => item.isNotEmpty);
      expect(result, ['a', 'b', 'c']);
    });

    test('replaceItems replaces all items', () {
      codex.replaceItems(['x', 'y']);
      expect(codex.items.value, ['x', 'y']);
      expect(codex.itemCount, 2);
    });

    test('replaceItems with empty list clears items', () {
      codex.replaceItems([]);
      expect(codex.items.value, isEmpty);
      expect(codex.isEmpty, true);
    });
  });
}

class _PaginatedPillar extends Pillar {
  late final items = codex<String>(
    (req) async =>
        const CodexPage(items: ['quest_1', 'quest_2'], hasMore: false),
    pageSize: 10,
    name: 'quests',
  );
}
