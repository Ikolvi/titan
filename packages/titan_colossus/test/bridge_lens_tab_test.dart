import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BridgeLensTab', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      ColossusBastion.disconnect();
      ColossusBasalt.disconnectAll();
      ColossusArgus.disconnect();
      TitanObserver.clearObservers();
      Colossus.shutdown();
    });

    test('has correct title and icon', () {
      final tab = BridgeLensTab(colossus);
      expect(tab.title, 'Bridge');
      expect(tab.icon, Icons.sync_alt);
    });

    test('implements LensPlugin', () {
      final tab = BridgeLensTab(colossus);
      expect(tab, isA<LensPlugin>());
    });

    testWidgets('renders empty state when no events', (tester) async {
      final tab = BridgeLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('No bridge events yet.'), findsOneWidget);
    });

    testWidgets('renders events tab with tracked events', (tester) async {
      colossus.trackEvent({
        'source': 'atlas',
        'type': 'navigate',
        'from': '/home',
        'to': '/profile',
        'timestamp': '2025-01-01T12:00:00Z',
      });
      colossus.trackEvent({
        'source': 'basalt',
        'type': 'circuit_trip',
        'name': 'api-breaker',
        'failureCount': 3,
        'timestamp': '2025-01-01T12:00:01Z',
      });

      final tab = BridgeLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      // Should show source badges
      expect(find.text('ATLAS'), findsOneWidget);
      expect(find.text('BASALT'), findsOneWidget);

      // Should show event types
      expect(find.text('navigate'), findsOneWidget);
      expect(find.text('circuit trip'), findsOneWidget);
    });

    testWidgets('status tab shows connection state', (tester) async {
      ColossusBastion.connect();

      final tab = BridgeLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      // Navigate to Status tab
      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();

      // Should show connection names
      expect(find.text('Argus (Auth)'), findsOneWidget);
      expect(find.text('Bastion (Reactive)'), findsOneWidget);
      expect(find.text('Basalt (Resilience)'), findsOneWidget);
      expect(find.text('Atlas (Routing)'), findsOneWidget);
    });

    testWidgets('heat map tab shows empty state when not connected', (
      tester,
    ) async {
      final tab = BridgeLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      // Navigate to Heat Map tab
      await tester.tap(find.text('Heat Map'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Bastion bridge not connected.'),
        findsOneWidget,
      );
    });

    test('can be registered and unregistered with Lens', () {
      final tab = BridgeLensTab(colossus);
      Lens.registerPlugin(tab);
      expect(Lens.plugins, contains(tab));

      Lens.unregisterPlugin(tab);
      expect(Lens.plugins, isNot(contains(tab)));
    });

    test('Colossus.init registers BridgeLensTab when enableLensTab true', () {
      Colossus.shutdown();
      Colossus.init(enableLensTab: true);

      final bridgeTabs = Lens.plugins.whereType<BridgeLensTab>().toList();
      expect(bridgeTabs, hasLength(1));
    });

    test('Colossus.shutdown unregisters BridgeLensTab', () {
      Colossus.shutdown();
      Colossus.init(enableLensTab: true);

      expect(Lens.plugins.whereType<BridgeLensTab>(), isNotEmpty);

      Colossus.shutdown();
      expect(Lens.plugins.whereType<BridgeLensTab>(), isEmpty);
    });
  });
}
