import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('AsyncValue', () {
    test('AsyncData holds data', () {
      const value = AsyncData<int>(42);
      expect(value.isData, true);
      expect(value.isLoading, false);
      expect(value.isError, false);
      expect(value.dataOrNull, 42);
      expect(value.errorOrNull, null);
    });

    test('AsyncLoading represents loading state', () {
      const value = AsyncLoading<int>();
      expect(value.isData, false);
      expect(value.isLoading, true);
      expect(value.isError, false);
      expect(value.dataOrNull, null);
    });

    test('AsyncError holds error and stack trace', () {
      final error = Exception('test');
      final value = AsyncError<int>(error);
      expect(value.isData, false);
      expect(value.isLoading, false);
      expect(value.isError, true);
      expect(value.errorOrNull, error);
    });

    test('when pattern matches correctly', () {
      const data = AsyncData<int>(42);
      const loading = AsyncLoading<int>();
      final error = AsyncError<int>(Exception('oops'));

      expect(
        data.when(
          onData: (v) => 'data: $v',
          onLoading: () => 'loading',
          onError: (e, s) => 'error',
        ),
        'data: 42',
      );

      expect(
        loading.when(
          onData: (v) => 'data',
          onLoading: () => 'loading',
          onError: (e, s) => 'error',
        ),
        'loading',
      );

      expect(
        error.when(
          onData: (v) => 'data',
          onLoading: () => 'loading',
          onError: (e, s) => 'error: $e',
        ),
        contains('error'),
      );
    });

    test('maybeWhen falls back to orElse', () {
      const value = AsyncLoading<int>();

      expect(
        value.maybeWhen(
          onData: (v) => 'data',
          orElse: () => 'fallback',
        ),
        'fallback',
      );
    });

    test('equality works correctly', () {
      expect(const AsyncData(42), equals(const AsyncData(42)));
      expect(const AsyncData(42), isNot(equals(const AsyncData(43))));
      expect(const AsyncLoading<int>(), equals(const AsyncLoading<int>()));
    });
  });

  group('TitanAsyncState', () {
    test('starts in loading state by default', () {
      final async = TitanAsyncState<int>();
      expect(async.isLoading, true);
      expect(async.hasData, false);
    });

    test('starts with initial value if provided', () {
      final async = TitanAsyncState<int>(
        initialValue: const AsyncData(42),
      );
      expect(async.hasData, true);
      expect(async.data, 42);
    });

    test('load transitions through states', () async {
      final async = TitanAsyncState<String>(name: 'test');

      await async.load(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'hello';
      });

      expect(async.hasData, true);
      expect(async.data, 'hello');
    });

    test('load handles errors', () async {
      final async = TitanAsyncState<String>();

      await async.load(() async {
        throw Exception('fail');
      });

      expect(async.hasError, true);
      expect(async.value.errorOrNull, isA<Exception>());
    });

    test('refresh does not show loading', () async {
      final async = TitanAsyncState<int>(
        initialValue: const AsyncData(1),
      );

      // Track states during refresh
      final states = <bool>[];
      async.state.addListener(() {
        states.add(async.isLoading);
      });

      await async.refresh(() async => 2);

      // Should never have been in loading state
      expect(states, isNot(contains(true)));
      expect(async.data, 2);
    });

    test('setValue sets data directly', () {
      final async = TitanAsyncState<int>();
      async.setValue(99);
      expect(async.data, 99);
    });

    test('reset returns to loading', () {
      final async = TitanAsyncState<int>(
        initialValue: const AsyncData(42),
      );
      async.reset();
      expect(async.isLoading, true);
    });
  });
}
