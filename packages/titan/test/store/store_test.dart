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

    test('addMiddleware and removeMiddleware', () {
      final store = _TestStore();
      final mw = _RecordingMiddleware();

      store.addMiddleware(mw);
      // Middleware list is internal; verify remove doesn't throw
      store.removeMiddleware(mw);

      // Re-add and dispose — dispose clears middleware list
      store.addMiddleware(mw);
      store.dispose();
      // After dispose, middleware list is cleared
      expect(store.isDisposed, true);
    });

    test('createEffect is managed and disposed with store', () {
      final store = _EffectStore();
      store.initialize();

      // Effect should have fired immediately
      expect(store.effectRanCount, 1);

      store.counter.value = 5;
      expect(store.effectRanCount, 2);

      store.dispose();
      expect(store.isDisposed, true);
    });

    test('only disposes once', () {
      final store = _TestStore();
      store.dispose();
      store.dispose(); // Should not throw
      expect(store.isDisposed, true);
    });
  });
}

class _RecordingMiddleware extends TitanMiddleware {
  final List<StateChangeEvent> events = [];

  @override
  void onStateChange(StateChangeEvent event) {
    events.add(event);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {}
}

class _EffectStore extends TitanStore {
  late final counter = createState(0, name: 'counter');
  int effectRanCount = 0;
  late final _trackEffect = createEffect(() {
    counter.value; // track dependency
    effectRanCount++;
  }, name: 'trackEffect');

  @override
  void onInit() {
    // Access the late field to trigger initialization
    _trackEffect;
  }
}
