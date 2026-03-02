import 'package:test/test.dart';
import 'package:titan/titan.dart';

// Test enums
enum TrafficLight { red, green, yellow }

enum TrafficEvent { next }

enum AuthState { unauthenticated, authenticating, authenticated, error }

enum AuthEvent { login, success, failure, logout }

// Test Pillar with Loom
class _TrafficPillar extends Pillar {
  late final light = loom<TrafficLight, TrafficEvent>(
    initial: TrafficLight.red,
    transitions: {
      (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
      (TrafficLight.green, TrafficEvent.next): TrafficLight.yellow,
      (TrafficLight.yellow, TrafficEvent.next): TrafficLight.red,
    },
    name: 'traffic',
  );
}

void main() {
  setUp(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  tearDown(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  group('Loom', () {
    test('starts with initial state', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
        },
      );

      expect(loom.current, TrafficLight.red);
      expect(loom.isIn(TrafficLight.red), isTrue);
      expect(loom.isIn(TrafficLight.green), isFalse);
    });

    test('send() transitions on valid event', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
          (TrafficLight.green, TrafficEvent.next): TrafficLight.yellow,
          (TrafficLight.yellow, TrafficEvent.next): TrafficLight.red,
        },
      );

      expect(loom.send(TrafficEvent.next), isTrue);
      expect(loom.current, TrafficLight.green);

      expect(loom.send(TrafficEvent.next), isTrue);
      expect(loom.current, TrafficLight.yellow);

      expect(loom.send(TrafficEvent.next), isTrue);
      expect(loom.current, TrafficLight.red);
    });

    test('send() returns false for invalid transition', () {
      final loom = Loom<AuthState, AuthEvent>(
        initial: AuthState.unauthenticated,
        transitions: {
          (AuthState.unauthenticated, AuthEvent.login):
              AuthState.authenticating,
          (AuthState.authenticating, AuthEvent.success):
              AuthState.authenticated,
        },
      );

      // success is not valid from unauthenticated
      expect(loom.send(AuthEvent.success), isFalse);
      expect(loom.current, AuthState.unauthenticated);
    });

    test('canSend() checks transition validity', () {
      final loom = Loom<AuthState, AuthEvent>(
        initial: AuthState.unauthenticated,
        transitions: {
          (AuthState.unauthenticated, AuthEvent.login):
              AuthState.authenticating,
          (AuthState.authenticating, AuthEvent.success):
              AuthState.authenticated,
          (AuthState.authenticated, AuthEvent.logout):
              AuthState.unauthenticated,
        },
      );

      expect(loom.canSend(AuthEvent.login), isTrue);
      expect(loom.canSend(AuthEvent.success), isFalse);
      expect(loom.canSend(AuthEvent.logout), isFalse);
    });

    test('allowedEvents returns valid events for current state', () {
      final loom = Loom<AuthState, AuthEvent>(
        initial: AuthState.authenticating,
        transitions: {
          (AuthState.unauthenticated, AuthEvent.login):
              AuthState.authenticating,
          (AuthState.authenticating, AuthEvent.success):
              AuthState.authenticated,
          (AuthState.authenticating, AuthEvent.failure): AuthState.error,
          (AuthState.authenticated, AuthEvent.logout):
              AuthState.unauthenticated,
        },
      );

      expect(loom.allowedEvents, {AuthEvent.success, AuthEvent.failure});
    });

    test('sendOrThrow() throws on invalid transition', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {},
      );

      expect(() => loom.sendOrThrow(TrafficEvent.next), throwsStateError);
    });

    test('onEnter/onExit callbacks fire correctly', () {
      final log = <String>[];

      final loom = Loom<AuthState, AuthEvent>(
        initial: AuthState.unauthenticated,
        transitions: {
          (AuthState.unauthenticated, AuthEvent.login):
              AuthState.authenticating,
          (AuthState.authenticating, AuthEvent.success):
              AuthState.authenticated,
        },
        onEnter: {
          AuthState.authenticating: () => log.add('enter:authenticating'),
          AuthState.authenticated: () => log.add('enter:authenticated'),
        },
        onExit: {
          AuthState.unauthenticated: () => log.add('exit:unauthenticated'),
          AuthState.authenticating: () => log.add('exit:authenticating'),
        },
      );

      loom.send(AuthEvent.login);
      expect(log, ['exit:unauthenticated', 'enter:authenticating']);

      log.clear();
      loom.send(AuthEvent.success);
      expect(log, ['exit:authenticating', 'enter:authenticated']);
    });

    test('onTransition callback fires on every transition', () {
      final transitions = <String>[];

      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
          (TrafficLight.green, TrafficEvent.next): TrafficLight.yellow,
        },
        onTransition: (from, event, to) {
          transitions.add('$from->$to');
        },
      );

      loom.send(TrafficEvent.next);
      loom.send(TrafficEvent.next);

      expect(transitions, [
        'TrafficLight.red->TrafficLight.green',
        'TrafficLight.green->TrafficLight.yellow',
      ]);
    });

    test('history records transitions', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
          (TrafficLight.green, TrafficEvent.next): TrafficLight.yellow,
        },
      );

      loom.send(TrafficEvent.next);
      loom.send(TrafficEvent.next);

      expect(loom.history, hasLength(2));
      expect(loom.history[0].from, TrafficLight.red);
      expect(loom.history[0].to, TrafficLight.green);
      expect(loom.history[1].from, TrafficLight.green);
      expect(loom.history[1].to, TrafficLight.yellow);
    });

    test('history respects maxHistory limit', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
          (TrafficLight.green, TrafficEvent.next): TrafficLight.yellow,
          (TrafficLight.yellow, TrafficEvent.next): TrafficLight.red,
        },
        maxHistory: 2,
      );

      loom.send(TrafficEvent.next); // red→green
      loom.send(TrafficEvent.next); // green→yellow
      loom.send(TrafficEvent.next); // yellow→red

      expect(loom.history, hasLength(2));
      // Oldest entry dropped
      expect(loom.history[0].from, TrafficLight.green);
    });

    test('reset() sets state and clears history', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
        },
      );

      loom.send(TrafficEvent.next);
      expect(loom.current, TrafficLight.green);
      expect(loom.history, hasLength(1));

      loom.reset(TrafficLight.red);
      expect(loom.current, TrafficLight.red);
      expect(loom.history, isEmpty);
    });

    test('state Core is reactive', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
        },
      );

      final values = <TrafficLight>[];
      loom.state.listen((v) => values.add(v));

      loom.send(TrafficEvent.next);
      expect(values, [TrafficLight.green]);
    });

    test('previousValue tracks on state Core', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {
          (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
        },
      );

      loom.send(TrafficEvent.next);
      expect(loom.state.previousValue, TrafficLight.red);
    });

    test('toString() includes state info', () {
      final loom = Loom<TrafficLight, TrafficEvent>(
        initial: TrafficLight.red,
        transitions: {},
        name: 'test',
      );

      expect(loom.toString(), contains('Loom'));
      expect(loom.toString(), contains('test'));
    });
  });

  group('Loom in Pillar', () {
    test('Pillar.loom() creates managed state machine', () {
      final pillar = _TrafficPillar();
      pillar.initialize();

      expect(pillar.light.current, TrafficLight.red);
      pillar.light.send(TrafficEvent.next);
      expect(pillar.light.current, TrafficLight.green);

      pillar.dispose();
    });

    test('Loom state is disposed with Pillar', () {
      final pillar = _TrafficPillar();
      pillar.initialize();

      final state = pillar.light.state;
      pillar.dispose();

      expect(state.isDisposed, isTrue);
    });

    test('Loom cycles through full transition loop', () {
      final pillar = _TrafficPillar();
      pillar.initialize();

      pillar.light.send(TrafficEvent.next); // red→green
      pillar.light.send(TrafficEvent.next); // green→yellow
      pillar.light.send(TrafficEvent.next); // yellow→red

      expect(pillar.light.current, TrafficLight.red);
      expect(pillar.light.history, hasLength(3));

      pillar.dispose();
    });
  });
}
