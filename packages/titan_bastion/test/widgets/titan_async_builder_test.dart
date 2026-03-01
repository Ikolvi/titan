import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

void main() {
  group('TitanAsyncBuilder', () {
    testWidgets('renders data builder when state has data', (tester) async {
      final async = TitanAsyncState<String>(
        initialValue: const AsyncData('hello'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TitanAsyncBuilder<String>(
            state: async,
            data: (context, data) => Text(data),
          ),
        ),
      );

      expect(find.text('hello'), findsOneWidget);
      async.dispose();
    });

    testWidgets('renders loading builder when loading', (tester) async {
      final async = TitanAsyncState<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: TitanAsyncBuilder<String>(
            state: async,
            data: (context, data) => Text(data),
            loading: (context) => const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      async.dispose();
    });

    testWidgets('renders error builder when error', (tester) async {
      final async = TitanAsyncState<String>();
      async.setError(Exception('boom'));

      await tester.pumpWidget(
        MaterialApp(
          home: TitanAsyncBuilder<String>(
            state: async,
            data: (context, data) => Text(data),
            error: (context, error, stackTrace) => Text('Error: $error'),
          ),
        ),
      );

      expect(find.textContaining('Error:'), findsOneWidget);
      async.dispose();
    });

    testWidgets('falls back to SizedBox.shrink when loading builder is null', (
      tester,
    ) async {
      final async = TitanAsyncState<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: TitanAsyncBuilder<String>(
            state: async,
            data: (context, data) => Text(data),
            // No loading builder
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      async.dispose();
    });

    testWidgets('falls back to SizedBox.shrink when error builder is null', (
      tester,
    ) async {
      final async = TitanAsyncState<String>();
      async.setError(Exception('x'));

      await tester.pumpWidget(
        MaterialApp(
          home: TitanAsyncBuilder<String>(
            state: async,
            data: (context, data) => Text(data),
            // No error builder
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      async.dispose();
    });

    testWidgets('rebuilds when async state changes', (tester) async {
      final async = TitanAsyncState<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: TitanAsyncBuilder<String>(
            state: async,
            data: (context, data) => Text(data),
            loading: (context) => const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      async.setValue('done');
      await tester.pumpAndSettle();

      expect(find.text('done'), findsOneWidget);
      async.dispose();
    });

    testWidgets('transitions from data to error', (tester) async {
      final async = TitanAsyncState<int>(initialValue: const AsyncData(42));

      await tester.pumpWidget(
        MaterialApp(
          home: TitanAsyncBuilder<int>(
            state: async,
            data: (context, data) => Text('Data: $data'),
            error: (context, error, _) => Text('Error: $error'),
          ),
        ),
      );

      expect(find.text('Data: 42'), findsOneWidget);

      async.setError(Exception('fail'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error:'), findsOneWidget);
      async.dispose();
    });
  });
}
