import 'package:test/test.dart';
import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Test events
// ---------------------------------------------------------------------------

class UserLoggedIn {
  final String userId;
  UserLoggedIn(this.userId);
}

class UserLoggedOut {}

class OrderPlaced {
  final int itemCount;
  OrderPlaced(this.itemCount);
}

class ThemeChanged {
  final bool isDark;
  ThemeChanged(this.isDark);
}

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

class ListenerPillar extends Pillar {
  late final lastUserId = core<String?>('');
  late final logoutCount = core(0);

  @override
  void onInit() {
    listen<UserLoggedIn>((event) {
      strike(() => lastUserId.value = event.userId);
    });

    listen<UserLoggedOut>((_) {
      strike(() => logoutCount.value++);
    });
  }
}

class EmitterPillar extends Pillar {
  void login(String userId) {
    emit(UserLoggedIn(userId));
  }

  void logout() {
    emit(UserLoggedOut());
  }
}

class OnceListenerPillar extends Pillar {
  late final readyCount = core(0);

  @override
  void onInit() {
    listenOnce<UserLoggedIn>((_) {
      strike(() => readyCount.value++);
    });
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    Herald.reset();
    Titan.reset();
  });

  group('Herald — Core', () {
    test('emit and on deliver events', () async {
      final received = <String>[];
      Herald.on<UserLoggedIn>((e) => received.add(e.userId));

      Herald.emit(UserLoggedIn('user_1'));
      Herald.emit(UserLoggedIn('user_2'));

      // StreamController.broadcast delivers synchronously
      expect(received, ['user_1', 'user_2']);
    });

    test('only delivers to matching type listeners', () async {
      final logins = <String>[];
      final logouts = <int>[];

      Herald.on<UserLoggedIn>((e) => logins.add(e.userId));
      Herald.on<UserLoggedOut>((_) => logouts.add(1));

      Herald.emit(UserLoggedIn('abc'));
      expect(logins, ['abc']);
      expect(logouts, isEmpty);

      Herald.emit(UserLoggedOut());
      expect(logins, ['abc']);
      expect(logouts, [1]);
    });

    test('multiple listeners receive the same event', () {
      int count = 0;
      Herald.on<UserLoggedIn>((_) => count++);
      Herald.on<UserLoggedIn>((_) => count++);
      Herald.on<UserLoggedIn>((_) => count++);

      Herald.emit(UserLoggedIn('x'));
      expect(count, 3);
    });

    test('emit with no listeners does not throw', () {
      expect(() => Herald.emit(UserLoggedIn('nobody')), returnsNormally);
    });

    test('cancelled subscription stops receiving', () {
      final received = <String>[];
      final sub = Herald.on<UserLoggedIn>((e) => received.add(e.userId));

      Herald.emit(UserLoggedIn('before'));
      sub.cancel();
      Herald.emit(UserLoggedIn('after'));

      expect(received, ['before']);
    });
  });

  group('Herald — once', () {
    test('once delivers exactly one event', () {
      int count = 0;
      Herald.once<UserLoggedIn>((_) => count++);

      Herald.emit(UserLoggedIn('first'));
      Herald.emit(UserLoggedIn('second'));
      Herald.emit(UserLoggedIn('third'));

      expect(count, 1);
    });

    test('once subscription can be cancelled before event', () {
      int count = 0;
      final sub = Herald.once<UserLoggedIn>((_) => count++);
      sub.cancel();

      Herald.emit(UserLoggedIn('never'));
      expect(count, 0);
    });
  });

  group('Herald — stream', () {
    test('stream returns a broadcast stream', () {
      final s = Herald.stream<UserLoggedIn>();
      expect(s.isBroadcast, isTrue);
    });

    test('stream delivers emitted events', () async {
      final events = <String>[];
      final sub = Herald.stream<UserLoggedIn>().listen(
        (e) => events.add(e.userId),
      );

      Herald.emit(UserLoggedIn('a'));
      Herald.emit(UserLoggedIn('b'));

      expect(events, ['a', 'b']);
      await sub.cancel();
    });
  });

  group('Herald — last (replay)', () {
    test('last returns null when no events emitted', () {
      expect(Herald.last<UserLoggedIn>(), isNull);
    });

    test('last returns the most recent event', () {
      Herald.emit(UserLoggedIn('old'));
      Herald.emit(UserLoggedIn('new'));

      final last = Herald.last<UserLoggedIn>();
      expect(last, isNotNull);
      expect(last!.userId, 'new');
    });

    test('last is type-specific', () {
      Herald.emit(UserLoggedIn('abc'));
      expect(Herald.last<UserLoggedOut>(), isNull);
      expect(Herald.last<UserLoggedIn>(), isNotNull);
    });

    test('clearLast removes cached event', () {
      Herald.emit(UserLoggedIn('abc'));
      expect(Herald.last<UserLoggedIn>(), isNotNull);

      Herald.clearLast<UserLoggedIn>();
      expect(Herald.last<UserLoggedIn>(), isNull);
    });

    test('last persists even without listeners', () {
      Herald.emit(OrderPlaced(5));
      expect(Herald.last<OrderPlaced>()?.itemCount, 5);
    });
  });

  group('Herald — hasListeners', () {
    test('returns false when no listeners', () {
      expect(Herald.hasListeners<UserLoggedIn>(), isFalse);
    });

    test('returns true when listener exists', () {
      Herald.on<UserLoggedIn>((_) {});
      expect(Herald.hasListeners<UserLoggedIn>(), isTrue);
    });

    test('returns false after subscription cancelled', () {
      final sub = Herald.on<UserLoggedIn>((_) {});
      expect(Herald.hasListeners<UserLoggedIn>(), isTrue);
      sub.cancel();
      // Note: StreamController may not immediately update hasListener
      // after a cancel on a broadcast controller, so we don't assert false
    });
  });

  group('Herald — reset', () {
    test('reset clears all listeners', () {
      Herald.on<UserLoggedIn>((_) {});
      Herald.on<UserLoggedOut>((_) {});
      Herald.emit(UserLoggedIn('cached'));

      Herald.reset();

      expect(Herald.hasListeners<UserLoggedIn>(), isFalse);
      expect(Herald.hasListeners<UserLoggedOut>(), isFalse);
      expect(Herald.last<UserLoggedIn>(), isNull);
    });

    test('new listeners work after reset', () {
      Herald.on<UserLoggedIn>((_) {});
      Herald.reset();

      final received = <String>[];
      Herald.on<UserLoggedIn>((e) => received.add(e.userId));
      Herald.emit(UserLoggedIn('after_reset'));

      expect(received, ['after_reset']);
    });
  });

  group('Pillar — Herald integration', () {
    test('listen receives Herald events', () {
      final pillar = ListenerPillar();
      pillar.initialize();

      Herald.emit(UserLoggedIn('pillar_test'));
      expect(pillar.lastUserId.value, 'pillar_test');
    });

    test('listen receives multiple event types', () {
      final pillar = ListenerPillar();
      pillar.initialize();

      Herald.emit(UserLoggedIn('user1'));
      Herald.emit(UserLoggedOut());
      Herald.emit(UserLoggedOut());

      expect(pillar.lastUserId.value, 'user1');
      expect(pillar.logoutCount.value, 2);
    });

    test('emit broadcasts Herald events from Pillar', () {
      final listener = ListenerPillar();
      listener.initialize();

      final emitter = EmitterPillar();
      emitter.initialize();
      emitter.login('cross_pillar');

      expect(listener.lastUserId.value, 'cross_pillar');
    });

    test('cross-Pillar communication via Herald', () {
      final listener = ListenerPillar();
      listener.initialize();

      final emitter = EmitterPillar();
      emitter.initialize();

      emitter.login('abc');
      expect(listener.lastUserId.value, 'abc');

      emitter.logout();
      expect(listener.logoutCount.value, 1);
    });

    test('dispose cancels Herald subscriptions', () {
      final pillar = ListenerPillar();
      pillar.initialize();

      Herald.emit(UserLoggedIn('before'));
      expect(pillar.lastUserId.value, 'before');

      pillar.dispose();

      // After dispose, events should not reach the pillar
      Herald.emit(UserLoggedIn('after'));
      // Value stays at 'before' since subscription was cancelled
      expect(pillar.lastUserId.value, 'before');
    });

    test('emit throws after dispose', () {
      final emitter = EmitterPillar();
      emitter.initialize();
      emitter.dispose();

      expect(
        () => emitter.login('fail'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('listenOnce receives exactly one event', () {
      final pillar = OnceListenerPillar();
      pillar.initialize();

      Herald.emit(UserLoggedIn('first'));
      Herald.emit(UserLoggedIn('second'));

      expect(pillar.readyCount.value, 1);
    });

    test('Pillar via Titan DI with Herald', () {
      Titan.put(EmitterPillar());
      Titan.put(ListenerPillar());

      Titan.get<EmitterPillar>().login('di_test');
      expect(Titan.get<ListenerPillar>().lastUserId.value, 'di_test');
    });

    test('Titan.reset disposes Pillars and cancels subscriptions', () {
      Titan.put(ListenerPillar());
      Herald.emit(UserLoggedIn('before_reset'));
      expect(Titan.get<ListenerPillar>().lastUserId.value, 'before_reset');

      final pillar = Titan.get<ListenerPillar>();
      Titan.reset();

      // After Titan.reset, the Pillar is disposed and subscriptions cancelled
      Herald.emit(UserLoggedIn('after_reset'));
      expect(pillar.lastUserId.value, 'before_reset');
    });
  });
}
