import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Quarry — Data Fetching', () {
    test('initial state has no data', () {
      final q = Quarry<String>(fetcher: () async => 'hello');
      expect(q.data.value, isNull);
      expect(q.isLoading.value, false);
      expect(q.isFetching.value, false);
      expect(q.error.value, isNull);
      expect(q.hasData, false);
      expect(q.hasError, false);
      expect(q.isStale, true);
      q.dispose();
    });

    test('fetch() loads data', () async {
      final q = Quarry<String>(fetcher: () async => 'hello');
      await q.fetch();
      expect(q.data.value, 'hello');
      expect(q.hasData, true);
      expect(q.isLoading.value, false);
      expect(q.error.value, isNull);
      q.dispose();
    });

    test('fetch() sets isLoading during initial load', () async {
      bool wasLoading = false;
      final q = Quarry<String>(
        fetcher: () async {
          // Will check isLoading state from test after completing
          await Future<void>.delayed(Duration.zero);
          return 'data';
        },
      );
      // Listen for isLoading changes
      q.isLoading.addListener(() {
        if (q.isLoading.value) wasLoading = true;
      });
      await q.fetch();
      expect(wasLoading, true);
      expect(q.isLoading.value, false); // Should be false after completion
      q.dispose();
    });

    test('fetch() captures error', () async {
      final q = Quarry<String>(fetcher: () async => throw Exception('fail'));
      await q.fetch();
      expect(q.hasError, true);
      expect(q.error.value, isA<Exception>());
      expect(q.hasData, false);
      q.dispose();
    });

    test('staleTime prevents refetch when fresh', () async {
      int callCount = 0;
      final q = Quarry<String>(
        fetcher: () async {
          callCount++;
          return 'data_$callCount';
        },
        staleTime: const Duration(minutes: 5),
      );

      await q.fetch();
      expect(callCount, 1);
      expect(q.data.value, 'data_1');

      // Second fetch should skip — data is fresh
      await q.fetch();
      expect(callCount, 1);
      expect(q.data.value, 'data_1');
      q.dispose();
    });

    test('null staleTime means always stale', () async {
      int callCount = 0;
      final q = Quarry<String>(
        fetcher: () async {
          callCount++;
          return 'data_$callCount';
        },
        // staleTime: null (default)
      );

      await q.fetch();
      expect(callCount, 1);

      // Should refetch — always stale when staleTime is null
      await q.fetch();
      expect(callCount, 2);
      q.dispose();
    });

    test('refetch() forces a refetch regardless of freshness', () async {
      int callCount = 0;
      final q = Quarry<String>(
        fetcher: () async {
          callCount++;
          return 'data_$callCount';
        },
        staleTime: const Duration(minutes: 5),
      );

      await q.fetch();
      expect(callCount, 1);

      await q.refetch();
      expect(callCount, 2);
      expect(q.data.value, 'data_2');
      q.dispose();
    });

    test('invalidate() marks data stale without refetching', () async {
      int callCount = 0;
      final q = Quarry<String>(
        fetcher: () async {
          callCount++;
          return 'data_$callCount';
        },
        staleTime: const Duration(minutes: 5),
      );

      await q.fetch();
      expect(callCount, 1);
      expect(q.isStale, false);

      q.invalidate();
      expect(q.isStale, true);
      expect(callCount, 1); // Not refetched yet

      await q.fetch();
      expect(callCount, 2); // Now refetched
      q.dispose();
    });

    test('setData() performs optimistic update', () async {
      final q = Quarry<String>(
        fetcher: () async => 'server_data',
        staleTime: const Duration(minutes: 5),
      );

      q.setData('optimistic_data');
      expect(q.data.value, 'optimistic_data');
      expect(q.hasData, true);
      expect(q.isStale, false); // Fresh after optimistic update
      q.dispose();
    });

    test('reset() clears all state', () async {
      final q = Quarry<String>(fetcher: () async => 'data');
      await q.fetch();
      expect(q.hasData, true);

      q.reset();
      expect(q.data.value, isNull);
      expect(q.isLoading.value, false);
      expect(q.isFetching.value, false);
      expect(q.error.value, isNull);
      expect(q.isStale, true);
      q.dispose();
    });

    test(
      'stale-while-revalidate uses isFetching instead of isLoading',
      () async {
        bool sawFetching = false;
        bool sawLoading = false;
        final q = Quarry<String>(fetcher: () async => 'data');

        await q.fetch(); // Initial fetch

        q.isFetching.addListener(() {
          if (q.isFetching.value) sawFetching = true;
        });
        q.isLoading.addListener(() {
          if (q.isLoading.value) sawLoading = true;
        });

        // Second fetch — data exists but is stale (staleTime is null)
        await q.fetch();
        expect(sawFetching, true); // Background refetch indicator
        expect(sawLoading, false); // Not shown as loading
        q.dispose();
      },
    );

    test('retry with backoff retries on failure', () async {
      int attempts = 0;
      final q = Quarry<String>(
        fetcher: () async {
          attempts++;
          if (attempts < 3) throw Exception('fail $attempts');
          return 'success';
        },
        retry: const QuarryRetry(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      await q.fetch();
      expect(attempts, 3);
      expect(q.data.value, 'success');
      expect(q.hasError, false);
      q.dispose();
    });

    test('retry gives up after maxAttempts', () async {
      int attempts = 0;
      final q = Quarry<String>(
        fetcher: () async {
          attempts++;
          throw Exception('always fails');
        },
        retry: const QuarryRetry(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      await q.fetch();
      expect(attempts, 2);
      expect(q.hasError, true);
      q.dispose();
    });

    test('managedNodes contains all reactive state', () {
      final q = Quarry<String>(fetcher: () async => 'data');
      expect(q.managedNodes.length, 4); // data, isLoading, isFetching, error
      q.dispose();
    });

    test('fetch deduplicates concurrent calls', () async {
      int callCount = 0;
      final q = Quarry<String>(
        fetcher: () async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'data';
        },
      );

      // Launch two fetches concurrently
      final f1 = q.fetch();
      final f2 = q.fetch();
      await Future.wait([f1, f2]);

      expect(callCount, 1); // Only one actual fetch
      expect(q.data.value, 'data');
      q.dispose();
    });

    test('dispose() disposes all managed nodes', () {
      final q = Quarry<String>(fetcher: () async => 'data');
      q.dispose();

      for (final node in q.managedNodes) {
        expect(node.isDisposed, isTrue);
      }
    });

    test('QuarryRetry defaults are maxAttempts=3 and baseDelay=1s', () {
      const retry = QuarryRetry();
      expect(retry.maxAttempts, 3);
      expect(retry.baseDelay, const Duration(seconds: 1));
    });

    test('Quarry default retry has maxAttempts=0 (no retry)', () async {
      var callCount = 0;
      final q = Quarry<String>(
        fetcher: () async {
          callCount++;
          throw Exception('fail');
        },
      );

      await q.fetch();
      expect(callCount, 1); // No retries — just one attempt
      expect(q.hasError, true);
      q.dispose();
    });

    test('reset() clears all state', () async {
      final q = Quarry<String>(fetcher: () async => 'hello');
      await q.fetch();
      expect(q.hasData, true);

      q.reset();
      expect(q.data.value, isNull);
      expect(q.error.value, isNull);
      expect(q.isLoading.value, false);
      expect(q.isFetching.value, false);
      expect(q.isStale, true);
      q.dispose();
    });

    test('setData() manually sets data', () {
      final q = Quarry<String>(fetcher: () async => 'from-fetch');
      q.setData('manual');
      expect(q.data.value, 'manual');
      expect(q.hasData, true);
      q.dispose();
    });

    test('invalidate() marks data as stale', () async {
      final q = Quarry<String>(
        fetcher: () async => 'data',
        staleTime: const Duration(hours: 1),
      );
      await q.fetch();
      expect(q.isStale, false);

      q.invalidate();
      expect(q.isStale, true);
      q.dispose();
    });
  });

  group('Quarry — Pillar integration', () {
    late _DataPillar pillar;

    setUp(() {
      pillar = _DataPillar();
      pillar.initialize();
    });

    tearDown(() {
      pillar.dispose();
      Titan.reset();
    });

    test('quarry() creates managed Quarry', () {
      expect(pillar.userQuery.data.value, isNull);
    });

    test('quarry fetches data through Pillar', () async {
      await pillar.userQuery.fetch();
      expect(pillar.userQuery.data.value, 'Kael');
    });

    test('Pillar disposal cleans up quarry nodes', () {
      pillar.dispose();
      // Should not throw
    });
  });

  group('Quarry — Polling', () {
    test('isPolling is false initially', () {
      final q = Quarry<int>(fetcher: () async => 1);
      expect(q.isPolling, false);
      q.dispose();
    });

    test('startPolling activates periodic refetch', () async {
      var fetchCount = 0;
      final q = Quarry<int>(
        fetcher: () async {
          fetchCount++;
          return fetchCount;
        },
      );

      await q.startPolling(Duration(milliseconds: 50), fetchImmediately: true);
      expect(q.isPolling, true);
      expect(fetchCount, 1); // Immediate fetch

      // Wait for 2-3 polling ticks
      await Future<void>.delayed(Duration(milliseconds: 130));
      expect(fetchCount, greaterThanOrEqualTo(3));

      q.stopPolling();
      expect(q.isPolling, false);
      q.dispose();
    });

    test('stopPolling halts periodic fetch', () async {
      var fetchCount = 0;
      final q = Quarry<int>(
        fetcher: () async {
          fetchCount++;
          return fetchCount;
        },
      );

      await q.startPolling(Duration(milliseconds: 50));
      q.stopPolling();
      final countAfterStop = fetchCount;

      await Future<void>.delayed(Duration(milliseconds: 120));
      expect(fetchCount, countAfterStop); // No more fetches
      q.dispose();
    });

    test(
      'startPolling with fetchImmediately false skips initial fetch',
      () async {
        var fetchCount = 0;
        final q = Quarry<int>(
          fetcher: () async {
            fetchCount++;
            return fetchCount;
          },
        );

        await q.startPolling(
          Duration(milliseconds: 200),
          fetchImmediately: false,
        );
        expect(fetchCount, 0); // No immediate fetch
        q.stopPolling();
        q.dispose();
      },
    );

    test('dispose stops polling', () async {
      var fetchCount = 0;
      final q = Quarry<int>(
        fetcher: () async {
          fetchCount++;
          return fetchCount;
        },
      );

      await q.startPolling(Duration(milliseconds: 50));
      q.dispose();
      final countAfterDispose = fetchCount;

      await Future<void>.delayed(Duration(milliseconds: 120));
      expect(fetchCount, countAfterDispose);
    });

    test('reset stops polling', () async {
      var fetchCount = 0;
      final q = Quarry<int>(
        fetcher: () async {
          fetchCount++;
          return fetchCount;
        },
      );

      await q.startPolling(Duration(milliseconds: 50));
      q.reset();
      expect(q.isPolling, false);
      q.dispose();
    });

    test('restarting polling resets interval', () async {
      var fetchCount = 0;
      final q = Quarry<int>(
        fetcher: () async {
          fetchCount++;
          return fetchCount;
        },
      );

      await q.startPolling(Duration(milliseconds: 1000));
      // Restart with shorter interval
      await q.startPolling(Duration(milliseconds: 50));
      expect(q.isPolling, true);

      await Future<void>.delayed(Duration(milliseconds: 130));
      // Should have multiple fetches from the short interval
      expect(fetchCount, greaterThanOrEqualTo(3));

      q.stopPolling();
      q.dispose();
    });
  });

  group('Quarry — Callbacks', () {
    test('onSuccess is called after successful fetch', () async {
      String? successValue;
      final q = Quarry<String>(
        fetcher: () async => 'data',
        onSuccess: (d) => successValue = d,
      );
      await q.fetch();
      expect(successValue, 'data');
      q.dispose();
    });

    test('onError is called after failed fetch', () async {
      Object? errorValue;
      final q = Quarry<String>(
        fetcher: () async => throw Exception('fail'),
        onError: (e) => errorValue = e,
      );
      await q.fetch();
      expect(errorValue, isA<Exception>());
      q.dispose();
    });

    test('onSuccess not called when cancelled', () async {
      String? successValue;
      final q = Quarry<String>(
        fetcher: () async {
          await Future<void>.delayed(Duration(milliseconds: 50));
          return 'data';
        },
        onSuccess: (d) => successValue = d,
      );
      q.fetch(); // Don't await
      q.cancel();
      await Future<void>.delayed(Duration(milliseconds: 80));
      expect(successValue, isNull);
      q.dispose();
    });
  });

  group('Quarry — Cancellation', () {
    test('cancel discards in-flight result', () async {
      final q = Quarry<String>(
        fetcher: () async {
          await Future<void>.delayed(Duration(milliseconds: 50));
          return 'should_be_discarded';
        },
      );
      q.fetch();
      q.cancel();
      await Future<void>.delayed(Duration(milliseconds: 80));
      expect(q.data.value, isNull); // Result discarded
      expect(q.isLoading.value, false);
      q.dispose();
    });

    test('cancel resets loading indicators immediately', () async {
      final q = Quarry<String>(
        fetcher: () async {
          await Future<void>.delayed(Duration(milliseconds: 100));
          return 'data';
        },
      );
      q.fetch();
      // Let it start loading
      await Future<void>.delayed(Duration(milliseconds: 10));
      expect(q.isLoading.value, true);
      q.cancel();
      expect(q.isLoading.value, false);
      q.dispose();
    });

    test('can fetch again after cancel', () async {
      var count = 0;
      final q = Quarry<int>(
        fetcher: () async {
          count++;
          await Future<void>.delayed(Duration(milliseconds: 20));
          return count;
        },
      );
      q.fetch();
      q.cancel();
      await q.fetch();
      // Second fetch should succeed (first was cancelled)
      expect(q.data.value, isNotNull);
      q.dispose();
    });
  });
}

class _DataPillar extends Pillar {
  late final userQuery = quarry<String>(
    fetcher: () async => 'Kael',
    staleTime: const Duration(minutes: 5),
    name: 'user',
  );
}
