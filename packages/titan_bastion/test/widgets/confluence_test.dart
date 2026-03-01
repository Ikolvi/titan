import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

class _CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
}

class _NamePillar extends Pillar {
  late final name = core('Kael');
  void setName(String value) => strike(() => name.value = value);
}

class _ThemePillar extends Pillar {
  late final isDark = core(false);
  void toggleDark() => strike(() => isDark.value = !isDark.value);
}

class _SettingsPillar extends Pillar {
  late final locale = core('en');
}

void main() {
  setUp(() => Titan.reset());
  tearDown(() => Titan.reset());

  group('Confluence2 — Two-Pillar Consumer', () {
    testWidgets('renders with two Pillars from Titan registry', (tester) async {
      Titan.put(_CounterPillar());
      Titan.put(_NamePillar());

      await tester.pumpWidget(
        MaterialApp(
          home: Confluence2<_CounterPillar, _NamePillar>(
            builder: (context, counter, name) =>
                Text('${name.name.value}: ${counter.count.value}'),
          ),
        ),
      );

      expect(find.text('Kael: 0'), findsOneWidget);
    });

    testWidgets('rebuilds when first Pillar state changes', (tester) async {
      Titan.put(_CounterPillar());
      Titan.put(_NamePillar());

      await tester.pumpWidget(
        MaterialApp(
          home: Confluence2<_CounterPillar, _NamePillar>(
            builder: (context, counter, name) =>
                Text('${name.name.value}: ${counter.count.value}'),
          ),
        ),
      );

      Titan.get<_CounterPillar>().increment();
      await tester.pump();

      expect(find.text('Kael: 1'), findsOneWidget);
    });

    testWidgets('rebuilds when second Pillar state changes', (tester) async {
      Titan.put(_CounterPillar());
      Titan.put(_NamePillar());

      await tester.pumpWidget(
        MaterialApp(
          home: Confluence2<_CounterPillar, _NamePillar>(
            builder: (context, counter, name) =>
                Text('${name.name.value}: ${counter.count.value}'),
          ),
        ),
      );

      Titan.get<_NamePillar>().setName('Atlas');
      await tester.pump();

      expect(find.text('Atlas: 0'), findsOneWidget);
    });

    testWidgets('resolves Pillars from Beacon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_CounterPillar.new, _NamePillar.new],
            child: Confluence2<_CounterPillar, _NamePillar>(
              builder: (context, counter, name) =>
                  Text('${name.name.value}: ${counter.count.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Kael: 0'), findsOneWidget);
    });

    testWidgets('throws when Pillar is not found', (tester) async {
      Titan.put(_CounterPillar());
      // _NamePillar NOT registered

      await tester.pumpWidget(
        MaterialApp(
          home: Confluence2<_CounterPillar, _NamePillar>(
            builder: (context, counter, name) => const Text('ok'),
          ),
        ),
      );

      expect(tester.takeException(), isA<FlutterError>());
    });
  });

  group('Confluence3 — Three-Pillar Consumer', () {
    testWidgets('renders with three Pillars', (tester) async {
      Titan.put(_CounterPillar());
      Titan.put(_NamePillar());
      Titan.put(_ThemePillar());

      await tester.pumpWidget(
        MaterialApp(
          home: Confluence3<_CounterPillar, _NamePillar, _ThemePillar>(
            builder: (context, counter, name, theme) => Text(
              '${name.name.value}:${counter.count.value}:${theme.isDark.value}',
            ),
          ),
        ),
      );

      expect(find.text('Kael:0:false'), findsOneWidget);
    });

    testWidgets('rebuilds when any Pillar changes', (tester) async {
      Titan.put(_CounterPillar());
      Titan.put(_NamePillar());
      Titan.put(_ThemePillar());

      await tester.pumpWidget(
        MaterialApp(
          home: Confluence3<_CounterPillar, _NamePillar, _ThemePillar>(
            builder: (context, counter, name, theme) => Text(
              '${name.name.value}:${counter.count.value}:${theme.isDark.value}',
            ),
          ),
        ),
      );

      Titan.get<_ThemePillar>().toggleDark();
      await tester.pump();

      expect(find.text('Kael:0:true'), findsOneWidget);
    });
  });

  group('Confluence4 — Four-Pillar Consumer', () {
    testWidgets('renders with four Pillars', (tester) async {
      Titan.put(_CounterPillar());
      Titan.put(_NamePillar());
      Titan.put(_ThemePillar());
      Titan.put(_SettingsPillar());

      await tester.pumpWidget(
        MaterialApp(
          home:
              Confluence4<
                _CounterPillar,
                _NamePillar,
                _ThemePillar,
                _SettingsPillar
              >(
                builder: (context, counter, name, theme, settings) => Text(
                  '${name.name.value}:${counter.count.value}:'
                  '${theme.isDark.value}:${settings.locale.value}',
                ),
              ),
        ),
      );

      expect(find.text('Kael:0:false:en'), findsOneWidget);
    });
  });
}
