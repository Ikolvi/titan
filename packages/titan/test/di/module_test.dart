import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _CounterStore extends TitanStore {
  late final count = createState(0, name: 'count');
  void increment() => count.value++;
}

class _UserStore extends TitanStore {
  late final name = createState('Guest', name: 'name');
}

class _AuthModule extends TitanModule {
  @override
  void register(TitanContainer container) {
    container.register(() => _CounterStore());
    container.register(() => _UserStore());
  }
}

void main() {
  group('TitanModule', () {
    late TitanContainer container;

    setUp(() {
      container = TitanContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('custom module registers stores into container', () {
      final module = _AuthModule();
      module.register(container);

      expect(container.has<_CounterStore>(), true);
      expect(container.has<_UserStore>(), true);
    });

    test('stores from module are lazily created and initialized', () {
      _AuthModule().register(container);

      final counter = container.get<_CounterStore>();
      expect(counter.isInitialized, true);
      expect(counter.count.value, 0);
    });

    test('stores from module are disposed with container', () {
      _AuthModule().register(container);

      final counter = container.get<_CounterStore>();
      final user = container.get<_UserStore>();

      container.dispose();

      expect(counter.isDisposed, true);
      expect(user.isDisposed, true);
    });
  });

  group('TitanSimpleModule', () {
    late TitanContainer container;

    setUp(() {
      container = TitanContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('creates module from factory list', () {
      final module = TitanSimpleModule([() => _CounterStore()]);

      module.register(container);

      // TitanSimpleModule registers under TitanStore type
      // since the factory list is List<TitanStore Function()>
      expect(container.has<TitanStore>(), true);
    });

    test('factories are called lazily on get', () {
      int callCount = 0;
      final module = TitanSimpleModule([
        () {
          callCount++;
          return _CounterStore();
        },
      ]);

      module.register(container);
      expect(callCount, 0);

      container.get<TitanStore>();
      expect(callCount, 1);
    });

    test('empty factory list registers nothing', () {
      final module = TitanSimpleModule([]);
      module.register(container);

      expect(container.has<_CounterStore>(), false);
    });

    test('module works with child containers', () {
      _AuthModule().register(container);

      final child = container.createChild();
      // Child inherits parent registrations
      final counter = child.get<_CounterStore>();
      expect(counter.isInitialized, true);

      child.dispose();
    });
  });
}
