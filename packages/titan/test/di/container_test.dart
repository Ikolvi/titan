import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _CounterStore extends TitanStore {
  late final count = createState(0, name: 'count');
  void increment() => count.value++;
}

class _UserStore extends TitanStore {
  late final name = createState('Guest', name: 'name');
}

void main() {
  group('TitanContainer', () {
    late TitanContainer container;

    setUp(() {
      container = TitanContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('registers and retrieves stores', () {
      container.register(() => _CounterStore());

      final store = container.get<_CounterStore>();
      expect(store, isA<_CounterStore>());
      expect(store.count.value, 0);
    });

    test('returns the same instance on subsequent gets', () {
      container.register(() => _CounterStore());

      final store1 = container.get<_CounterStore>();
      final store2 = container.get<_CounterStore>();
      expect(identical(store1, store2), true);
    });

    test('lazy instantiation by default', () {
      bool factoryCalled = false;
      container.register(() {
        factoryCalled = true;
        return _CounterStore();
      });

      expect(factoryCalled, false);
      container.get<_CounterStore>();
      expect(factoryCalled, true);
    });

    test('eager instantiation when lazy is false', () {
      bool factoryCalled = false;
      container.register(() {
        factoryCalled = true;
        return _CounterStore();
      }, lazy: false);

      expect(factoryCalled, true);
    });

    test('initializes store on first get', () {
      container.register(() => _CounterStore());
      final store = container.get<_CounterStore>();
      expect(store.isInitialized, true);
    });

    test('throws when store not registered', () {
      expect(() => container.get<_CounterStore>(), throwsA(isA<StateError>()));
    });

    test('has() checks registration', () {
      expect(container.has<_CounterStore>(), false);
      container.register(() => _CounterStore());
      expect(container.has<_CounterStore>(), true);
    });

    test('disposes all stores on dispose', () {
      container.register(() => _CounterStore());
      container.register(() => _UserStore());

      final counter = container.get<_CounterStore>();
      final user = container.get<_UserStore>();

      container.dispose();

      expect(counter.isDisposed, true);
      expect(user.isDisposed, true);
    });

    test('child container inherits parent registrations', () {
      container.register(() => _CounterStore());

      final child = container.createChild();
      final store = child.get<_CounterStore>();
      expect(store, isA<_CounterStore>());

      child.dispose();
    });

    test('child container can override parent registrations', () {
      container.register(() => _CounterStore());

      final child = container.createChild();
      child.register(() {
        final store = _CounterStore();
        store.count.silent(99);
        return store;
      });

      final parentStore = container.get<_CounterStore>();
      final childStore = child.get<_CounterStore>();

      expect(parentStore.count.peek(), 0);
      expect(childStore.count.peek(), 99);

      child.dispose();
    });

    test('disposing parent disposes children', () {
      container.register(() => _CounterStore());

      final child = container.createChild();
      child.register(() => _UserStore());

      final userStore = child.get<_UserStore>();

      container.dispose();
      expect(userStore.isDisposed, true);
    });

    test('has() checks parent container', () {
      container.register(() => _CounterStore());

      final child = container.createChild();
      // Child has no local registration but parent does
      expect(child.has<_CounterStore>(), true);
      // Neither child nor parent has this
      expect(child.has<_UserStore>(), false);

      child.dispose();
    });

    test('double dispose is safe', () {
      container.register(() => _CounterStore());
      container.get<_CounterStore>();

      container.dispose();
      container.dispose(); // Should not throw
    });
  });
}
