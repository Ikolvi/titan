import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

class _TestWidget extends StatefulWidget {
  final TitanState<int> counter;

  const _TestWidget({required this.counter});

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> with TitanStateMixin {
  @override
  void initState() {
    super.initState();
    watch(() {
      widget.counter.value; // track dependency
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text('${widget.counter.value}');
  }
}

class _EffectWidget extends StatefulWidget {
  final TitanState<int> counter;
  final void Function(int) onEffect;

  const _EffectWidget({required this.counter, required this.onEffect});

  @override
  State<_EffectWidget> createState() => _EffectWidgetState();
}

class _EffectWidgetState extends State<_EffectWidget> with TitanStateMixin {
  @override
  void initState() {
    super.initState();
    titanEffect(() {
      widget.onEffect(widget.counter.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

void main() {
  group('TitanStateMixin', () {
    testWidgets('watch triggers rebuild on state change', (tester) async {
      final counter = TitanState(0);

      await tester.pumpWidget(MaterialApp(home: _TestWidget(counter: counter)));

      expect(find.text('0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      counter.dispose();
    });

    testWidgets('effects are disposed when widget is disposed', (tester) async {
      final counter = TitanState(0);
      final values = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: _EffectWidget(counter: counter, onEffect: values.add),
        ),
      );

      expect(values, [0]); // fireImmediately triggers once

      counter.value = 1;
      expect(values, [0, 1]);

      // Remove widget from tree → dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // After dispose, changing state should NOT trigger effect
      counter.value = 2;
      expect(values, [0, 1]); // No new entry

      counter.dispose();
    });

    testWidgets('titanEffect runs side effect without rebuild', (tester) async {
      final counter = TitanState(0);
      final values = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: _EffectWidget(counter: counter, onEffect: values.add),
        ),
      );

      // Effect fires immediately
      expect(values, [0]);

      counter.value = 42;
      expect(values, [0, 42]);

      counter.dispose();
    });

    testWidgets('multiple watches are all disposed', (tester) async {
      final a = TitanState(0);
      final b = TitanState('hello');

      await tester.pumpWidget(
        MaterialApp(
          home: _MultiWatchWidget(a: a, b: b),
        ),
      );

      expect(find.text('0 hello'), findsOneWidget);

      a.value = 1;
      await tester.pumpAndSettle();
      expect(find.text('1 hello'), findsOneWidget);

      b.value = 'world';
      await tester.pumpAndSettle();
      expect(find.text('1 world'), findsOneWidget);

      // Dispose widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Changes should have no effect after dispose
      a.value = 99;
      b.value = 'gone';

      a.dispose();
      b.dispose();
    });
  });
}

class _MultiWatchWidget extends StatefulWidget {
  final TitanState<int> a;
  final TitanState<String> b;

  const _MultiWatchWidget({required this.a, required this.b});

  @override
  State<_MultiWatchWidget> createState() => _MultiWatchWidgetState();
}

class _MultiWatchWidgetState extends State<_MultiWatchWidget>
    with TitanStateMixin {
  @override
  void initState() {
    super.initState();
    watch(() {
      widget.a.value;
    });
    watch(() {
      widget.b.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text('${widget.a.value} ${widget.b.value}');
  }
}
