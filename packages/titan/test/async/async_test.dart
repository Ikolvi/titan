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
        value.maybeWhen(onData: (v) => 'data', orElse: () => 'fallback'),
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
      final async = TitanAsyncState<int>(initialValue: const AsyncData(42));
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
      final async = TitanAsyncState<int>(initialValue: const AsyncData(1));

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
      final async = TitanAsyncState<int>(initialValue: const AsyncData(42));
      async.reset();
      expect(async.isLoading, true);
    });

    test('setError sets error state', () {
      final async = TitanAsyncState<int>();
      final error = Exception('boom');
      async.setError(error);

      expect(async.hasError, true);
      expect(async.value.errorOrNull, error);
    });

    test('setError with stack trace', () {
      final async = TitanAsyncState<int>();
      final error = Exception('boom');
      final trace = StackTrace.current;
      async.setError(error, trace);

      expect(async.hasError, true);
      final err = async.value as AsyncError<int>;
      expect(err.stackTrace, trace);
    });

    test('dispose disposes underlying state', () {
      final async = TitanAsyncState<int>();
      async.dispose();
      expect(async.state.isDisposed, true);
    });
  });

  group('AsyncValue — additional coverage', () {
    test('factory constructors', () {
      const d = AsyncValue<int>.data(42);
      const l = AsyncValue<int>.loading();
      final e = AsyncValue<int>.error(Exception('x'));

      expect(d, isA<AsyncData<int>>());
      expect(l, isA<AsyncLoading<int>>());
      expect(e, isA<AsyncError<int>>());
    });

    test('maybeWhen matches onData', () {
      const value = AsyncData<int>(42);
      final result = value.maybeWhen(
        onData: (v) => 'data: $v',
        orElse: () => 'fallback',
      );
      expect(result, 'data: 42');
    });

    test('maybeWhen matches onError', () {
      final value = AsyncError<int>(Exception('oops'));
      final result = value.maybeWhen(
        onError: (e, s) => 'error',
        orElse: () => 'fallback',
      );
      expect(result, 'error');
    });

    test('maybeWhen matches onLoading', () {
      const value = AsyncLoading<int>();
      final result = value.maybeWhen(
        onLoading: () => 'loading',
        orElse: () => 'fallback',
      );
      expect(result, 'loading');
    });

    test('AsyncError equality', () {
      final ex = Exception('a');
      final e1 = AsyncError<int>(ex);
      final e2 = AsyncError<int>(ex);
      final e3 = AsyncError<int>(Exception('b'));

      expect(e1, equals(e2));
      expect(e1, isNot(equals(e3)));
    });

    test('AsyncError with stack trace', () {
      final trace = StackTrace.current;
      final err = AsyncError<int>(Exception('x'), trace);
      expect(err.stackTrace, trace);
    });

    test('toString on all subtypes', () {
      expect(const AsyncData(42).toString(), 'AsyncData<int>(42)');
      expect(const AsyncLoading<int>().toString(), 'AsyncLoading<int>()');
      expect(
        AsyncError<int>(Exception('x')).toString(),
        contains('AsyncError<int>'),
      );
    });

    test('hashCode consistency', () {
      expect(const AsyncData(42).hashCode, const AsyncData(42).hashCode);
      expect(
        const AsyncLoading<int>().hashCode,
        const AsyncLoading<int>().hashCode,
      );
      // Same error → same hashCode
      final ex = Exception('x');
      expect(AsyncError<int>(ex).hashCode, AsyncError<int>(ex).hashCode);
    });
  });
}
