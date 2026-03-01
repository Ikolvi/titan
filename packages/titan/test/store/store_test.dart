import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _TestStore extends TitanStore {
  late final count = createState(0, name: 'count');
  late final doubled = createComputed(
    () => count.value * 2,
    name: 'doubled',
  );

  void increment() => count.value++;
  void decrement() => count.value--;
}

class _InitStore extends TitanStore {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  void onInit() {
    initCalled = true;
  }

  @override
  void onDispose() {
    disposeCalled = true;
  }
}

void main() {
  group('TitanStore', () {
    test('creates and manages state', () {
      final store = _TestStore();
      expect(store.count.value, 0);
      expect(store.doubled.value, 0);

      store.increment();
      expect(store.count.value, 1);
      expect(store.doubled.value, 2);

      store.dispose();
    });

    test('disposes all managed nodes on dispose', () {
      final store = _TestStore();
      store.count.value;
      store.doubled.value;

      store.dispose();
      expect(store.isDisposed, true);
      expect(store.count.isDisposed, true);
      expect(store.doubled.isDisposed, true);
    });

    test('calls onInit when initialized', () {
      final store = _InitStore();
      expect(store.initCalled, false);

      store.initialize();
      expect(store.initCalled, true);
      expect(store.isInitialized, true);
    });

    test('calls onDispose when disposed', () {
      final store = _InitStore();
      store.initialize();

      expect(store.disposeCalled, false);
      store.dispose();
      expect(store.disposeCalled, true);
    });

    test('only initializes once', () {
      final store = _InitStore();
      store.initialize();
      store.initialize(); // Should not throw or re-initialize
      expect(store.isInitialized, true);
    });
  });
}
