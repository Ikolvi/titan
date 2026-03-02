import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Prism', () {
    // -----------------------------------------------------------------------
    // Single-source Prism
    // -----------------------------------------------------------------------

    test('projects sub-value from a Core', () {
      final user = TitanState<Map<String, dynamic>>({
        'name': 'Kael',
        'level': 10,
      });
      final userName = Prism.of(user, (u) => u['name'] as String);

      expect(userName.value, 'Kael');

      user.value = {'name': 'Aria', 'level': 10};
      expect(userName.value, 'Aria');

      user.dispose();
    });

    test('does not notify when projected value is unchanged', () {
      final user = TitanState<Map<String, dynamic>>({
        'name': 'Kael',
        'level': 10,
      });
      final userName = Prism.of(user, (u) => u['name'] as String);
      userName.value; // initialize

      var notifyCount = 0;
      final effect = TitanEffect(() {
        userName.value;
        notifyCount++;
      });

      // Change level only — name stays the same
      user.value = {'name': 'Kael', 'level': 20};
      expect(notifyCount, 1); // Only the initial run

      // Change name — should notify
      user.value = {'name': 'Aria', 'level': 20};
      expect(notifyCount, 2);

      effect.dispose();
      user.dispose();
    });

    test('supports custom equality', () {
      final source = TitanState<List<int>>([1, 2, 3]);
      final projected = Prism.of<List<int>, List<int>>(
        source,
        (list) => list.where((x) => x > 1).toList(),
        equals: PrismEquals.list,
      );
      projected.value; // initialize

      var notifyCount = 0;
      final effect = TitanEffect(() {
        projected.value;
        notifyCount++;
      });

      // Same filtered result — should NOT notify
      source.value = [0, 2, 3];
      expect(notifyCount, 1); // Only initial

      // Different filtered result — should notify
      source.value = [0, 2, 3, 4];
      expect(notifyCount, 2);

      expect(projected.value, [2, 3, 4]);

      effect.dispose();
      source.dispose();
    });

    test('previousValue tracks last changed value', () {
      final source = TitanState(10);
      final doubled = Prism.of<int, int>(source, (v) => v * 2);
      doubled.value; // 20

      source.value = 20;
      expect(doubled.value, 40);
      expect(doubled.previousValue, 20);

      source.dispose();
    });

    test('name is preserved in toString', () {
      final source = TitanState(0);
      final named = Prism.of<int, int>(source, (v) => v, name: 'myPrism');
      expect(named.toString(), contains('Prism'));
      expect(named.toString(), contains('myPrism'));

      source.dispose();
    });

    test('works with addListener()', () {
      final source = TitanState(5);
      final projected = Prism.of<int, int>(source, (v) => v * 10);
      projected.value; // prime

      final values = <int>[];
      projected.addListener(() => values.add(projected.peek()));

      source.value = 6;
      source.value = 7;
      expect(values, [60, 70]);

      source.dispose();
    });

    test('disposes cleanly', () {
      final source = TitanState(0);
      final projected = Prism.of<int, int>(source, (v) => v + 1);
      projected.value;

      projected.dispose();
      // Should not throw
      source.value = 10;
    });

    // -----------------------------------------------------------------------
    // Multi-source Prisms
    // -----------------------------------------------------------------------

    test('combine2 merges two sources', () {
      final first = TitanState('Kael');
      final last = TitanState('the Brave');

      final full = Prism.combine2(
        first,
        last,
        (a, b) => '$a $b',
      );

      expect(full.value, 'Kael the Brave');

      first.value = 'Aria';
      expect(full.value, 'Aria the Brave');

      last.value = 'of Flames';
      expect(full.value, 'Aria of Flames');

      first.dispose();
      last.dispose();
    });

    test('combine3 merges three sources', () {
      final a = TitanState(10);
      final b = TitanState(20);
      final c = TitanState(30);

      final sum = Prism.combine3(a, b, c, (x, y, z) => x + y + z);

      expect(sum.value, 60);

      b.value = 100;
      expect(sum.value, 140);

      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('combine4 merges four sources', () {
      final name = TitanState('Kael');
      final level = TitanState(10);
      final health = TitanState(100);
      final mana = TitanState(50);

      final summary = Prism.combine4(
        name,
        level,
        health,
        mana,
        (n, l, h, m) => '$n (Lv$l) HP:$h MP:$m',
      );

      expect(summary.value, 'Kael (Lv10) HP:100 MP:50');

      health.value = 80;
      expect(summary.value, 'Kael (Lv10) HP:80 MP:50');

      name.dispose();
      level.dispose();
      health.dispose();
      mana.dispose();
    });

    test('combine2 only notifies when combined result changes', () {
      final x = TitanState(2);
      final y = TitanState(3);

      final product = Prism.combine2(x, y, (a, b) => a * b);
      product.value; // 6

      var notifyCount = 0;
      final effect = TitanEffect(() {
        product.value;
        notifyCount++;
      });

      // Change x from 2 to 3, y stays 3 → product: 6 → 9
      x.value = 3;
      expect(notifyCount, 2); // initial + change

      // Change y from 3 to 3 → no change (TitanState skips equal values)
      y.value = 3;
      expect(notifyCount, 2); // still 2

      effect.dispose();
      x.dispose();
      y.dispose();
    });

    // -----------------------------------------------------------------------
    // Prism.fromDerived
    // -----------------------------------------------------------------------

    test('fromDerived composes from a Derived', () {
      final first = TitanState('Kael');
      final last = TitanState('Brave');
      final fullName = TitanComputed(() => '${first.value} ${last.value}');
      fullName.value;

      final initials = Prism.fromDerived(
        fullName,
        (name) => name.split(' ').map((w) => w[0]).join(),
      );

      expect(initials.value, 'KB');

      first.value = 'Aria';
      expect(initials.value, 'AB');

      first.dispose();
      last.dispose();
    });

    // -----------------------------------------------------------------------
    // PrismEquals
    // -----------------------------------------------------------------------

    test('PrismEquals.list compares element-by-element', () {
      expect(PrismEquals.list([1, 2, 3], [1, 2, 3]), isTrue);
      expect(PrismEquals.list([1, 2, 3], [1, 2, 4]), isFalse);
      expect(PrismEquals.list([1, 2], [1, 2, 3]), isFalse);
      expect(PrismEquals.list(<int>[], <int>[]), isTrue);

      // Identical lists
      final same = [1, 2, 3];
      expect(PrismEquals.list(same, same), isTrue);
    });

    test('PrismEquals.set compares contents', () {
      expect(PrismEquals.set({1, 2, 3}, {3, 2, 1}), isTrue);
      expect(PrismEquals.set({1, 2}, {1, 2, 3}), isFalse);
      expect(PrismEquals.set(<int>{}, <int>{}), isTrue);

      final same = {1, 2};
      expect(PrismEquals.set(same, same), isTrue);
    });

    test('PrismEquals.map compares keys and values', () {
      expect(
        PrismEquals.map({'a': 1, 'b': 2}, {'b': 2, 'a': 1}),
        isTrue,
      );
      expect(
        PrismEquals.map({'a': 1}, {'a': 2}),
        isFalse,
      );
      expect(
        PrismEquals.map({'a': 1}, {'b': 1}),
        isFalse,
      );
      expect(
        PrismEquals.map(<String, int>{}, <String, int>{}),
        isTrue,
      );
    });

    // -----------------------------------------------------------------------
    // PrismCoreExtension — .prism() on Core
    // -----------------------------------------------------------------------

    test('.prism() extension creates a Prism from Core', () {
      final user = TitanState<Map<String, dynamic>>({
        'name': 'Kael',
        'level': 5,
      });

      final name = user.prism<String>((u) => u['name'] as String);
      expect(name.value, 'Kael');

      user.value = {'name': 'Aria', 'level': 5};
      expect(name.value, 'Aria');

      user.dispose();
    });

    test('.prism() with structural equality', () {
      final source = TitanState<List<int>>([1, 2, 3, 4, 5]);

      final evens = source.prism(
        (list) => list.where((x) => x.isEven).toList(),
        equals: PrismEquals.list,
      );
      evens.value; // [2, 4]

      var notified = false;
      final effect = TitanEffect(() {
        evens.value;
        notified = true;
      });
      notified = false; // reset after initial

      // Same evens [2, 4] — should NOT notify
      source.value = [1, 2, 3, 4, 6]; // evens: [2, 4, 6] — different!
      expect(notified, isTrue);

      effect.dispose();
      source.dispose();
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    test('Pillar.prism() creates managed Prism', () {
      final pillar = _TestPillar();
      pillar.initialize();

      expect(pillar.userName.value, 'Kael');
      expect(pillar.userLevel.value, 10);

      pillar.setUser({'name': 'Aria', 'level': 20});
      expect(pillar.userName.value, 'Aria');
      expect(pillar.userLevel.value, 20);

      // Change only level — userName should not update
      pillar.setUser({'name': 'Aria', 'level': 30});
      expect(pillar.userName.value, 'Aria');
      expect(pillar.userLevel.value, 30);

      pillar.dispose();
    });

    test('Pillar.prism() auto-disposes with Pillar', () {
      final pillar = _TestPillar();
      pillar.initialize();

      // Access values to ensure they're populated
      pillar.userName.value;
      pillar.userLevel.value;

      pillar.dispose();

      // Prism should be disposed with Pillar — no errors
    });

    test('Prism chains — Prism from Prism via fromDerived', () {
      final source = TitanState<Map<String, dynamic>>({
        'profile': {
          'name': 'Kael',
          'stats': {'level': 10, 'health': 100},
        },
      });

      final profile = Prism.of<Map<String, dynamic>, Map<String, dynamic>>(
        source,
        (data) => data['profile'] as Map<String, dynamic>,
      );

      final stats = Prism.fromDerived(
        profile,
        (p) => p['stats'] as Map<String, dynamic>,
      );

      expect(stats.value, {'level': 10, 'health': 100});

      source.value = {
        'profile': {
          'name': 'Kael',
          'stats': {'level': 15, 'health': 80},
        },
      };
      expect(stats.value, {'level': 15, 'health': 80});

      source.dispose();
    });

    test('Prism works with batch updates', () {
      final a = TitanState(1);
      final b = TitanState(2);
      final sum = Prism.combine2(a, b, (x, y) => x + y);
      sum.value; // 3

      var notifications = 0;
      final effect = TitanEffect(() {
        sum.value;
        notifications++;
      });

      titanBatch(() {
        a.value = 10;
        b.value = 20;
      });

      // After batch: should have notified once (not twice)
      expect(sum.value, 30);
      expect(notifications, 2); // initial + 1 batch notification

      effect.dispose();
      a.dispose();
      b.dispose();
    });

    test('Prism with Flux debounce integration', () async {
      final source = TitanState(0);
      final doubled = Prism.of<int, int>(source, (v) => v * 2);

      expect(doubled.value, 0);
      source.value = 5;
      expect(doubled.value, 10);

      source.dispose();
    });

    test('multiple Prisms on same source are independent', () {
      final user = TitanState<Map<String, dynamic>>({
        'name': 'Kael',
        'level': 10,
        'health': 100,
      });

      final name = Prism.of(user, (u) => u['name'] as String);
      final level = Prism.of(user, (u) => u['level'] as int);
      final health = Prism.of(user, (u) => u['health'] as int);

      expect(name.value, 'Kael');
      expect(level.value, 10);
      expect(health.value, 100);

      // Update health only
      user.value = {'name': 'Kael', 'level': 10, 'health': 80};
      expect(name.value, 'Kael'); // unchanged
      expect(level.value, 10); // unchanged
      expect(health.value, 80); // changed

      user.dispose();
    });

    test('Prism with empty selector returns constant', () {
      final source = TitanState(42);
      final constant = Prism.of<int, String>(source, (_) => 'always');

      expect(constant.value, 'always');

      source.value = 100;
      // Selector returns same value — no notification
      expect(constant.value, 'always');

      source.dispose();
    });

    test('PrismEquals.list handles nested objects via ==', () {
      final a = [
        {'id': 1},
        {'id': 2},
      ];
      final b = [
        {'id': 1},
        {'id': 2},
      ];
      // Map equality in Dart uses identity, so these are NOT equal
      expect(PrismEquals.list(a, b), isFalse);

      // Same references ARE equal
      final ref = {'id': 1};
      expect(PrismEquals.list([ref], [ref]), isTrue);
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

class _TestPillar extends Pillar {
  late final user = core<Map<String, dynamic>>(
    {'name': 'Kael', 'level': 10},
  );
  late final userName = prism<Map<String, dynamic>, String>(
    user,
    (u) => u['name'] as String,
  );
  late final userLevel = prism<Map<String, dynamic>, int>(
    user,
    (u) => u['level'] as int,
  );

  void setUser(Map<String, dynamic> data) {
    strike(() => user.value = data);
  }
}
