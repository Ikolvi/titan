import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  setUp(() {
    Sigil.reset();
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  tearDown(() {
    Sigil.reset();
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  group('Sigil', () {
    test('register and read a flag', () {
      Sigil.register('darkMode', true);
      expect(Sigil.isEnabled('darkMode'), isTrue);
      expect(Sigil.isDisabled('darkMode'), isFalse);
    });

    test('unregistered flag returns false', () {
      expect(Sigil.isEnabled('nonexistent'), isFalse);
    });

    test('register updates existing flag', () {
      Sigil.register('flag', true);
      expect(Sigil.isEnabled('flag'), isTrue);

      Sigil.register('flag', false);
      expect(Sigil.isEnabled('flag'), isFalse);
    });

    test('enable and disable', () {
      Sigil.register('feature', false);
      expect(Sigil.isEnabled('feature'), isFalse);

      Sigil.enable('feature');
      expect(Sigil.isEnabled('feature'), isTrue);

      Sigil.disable('feature');
      expect(Sigil.isEnabled('feature'), isFalse);
    });

    test('toggle returns new value', () {
      Sigil.register('toggle', false);

      final v1 = Sigil.toggle('toggle');
      expect(v1, isTrue);
      expect(Sigil.isEnabled('toggle'), isTrue);

      final v2 = Sigil.toggle('toggle');
      expect(v2, isFalse);
      expect(Sigil.isEnabled('toggle'), isFalse);
    });

    test('set updates value', () {
      Sigil.register('setTest', false);
      Sigil.set('setTest', true);
      expect(Sigil.isEnabled('setTest'), isTrue);
    });

    test('loadAll registers multiple flags', () {
      Sigil.loadAll({'a': true, 'b': false, 'c': true});

      expect(Sigil.isEnabled('a'), isTrue);
      expect(Sigil.isEnabled('b'), isFalse);
      expect(Sigil.isEnabled('c'), isTrue);
    });

    test('unregister removes flag', () {
      Sigil.register('temp', true);
      expect(Sigil.has('temp'), isTrue);

      final removed = Sigil.unregister('temp');
      expect(removed, isTrue);
      expect(Sigil.has('temp'), isFalse);
      expect(Sigil.isEnabled('temp'), isFalse);
    });

    test('unregister returns false for non-existent flag', () {
      expect(Sigil.unregister('ghost'), isFalse);
    });

    test('has checks registration', () {
      expect(Sigil.has('x'), isFalse);
      Sigil.register('x', true);
      expect(Sigil.has('x'), isTrue);
    });

    test('names returns all flag names', () {
      Sigil.loadAll({'alpha': true, 'beta': false, 'gamma': true});
      expect(Sigil.names, containsAll(['alpha', 'beta', 'gamma']));
    });

    test('peek reads without reactivity', () {
      Sigil.register('peekFlag', true);
      expect(Sigil.peek('peekFlag'), isTrue);
    });

    test('peek returns false for unregistered', () {
      expect(Sigil.peek('ghost'), isFalse);
    });

    test('coreOf returns the reactive Core', () {
      Sigil.register('coreFlag', true);
      final core = Sigil.coreOf('coreFlag');
      expect(core, isNotNull);
      expect(core!.value, isTrue);
    });

    test('coreOf returns null for unregistered', () {
      expect(Sigil.coreOf('ghost'), isNull);
    });

    test('isEnabled is reactive', () {
      Sigil.register('reactive', false);
      final values = <bool>[];

      TitanEffect(() {
        values.add(Sigil.isEnabled('reactive'));
      });

      expect(values, [false]);

      Sigil.enable('reactive');
      expect(values, [false, true]);

      Sigil.disable('reactive');
      expect(values, [false, true, false]);
    });

    test('override takes precedence over Core', () {
      Sigil.register('over', false);
      Sigil.override('over', true);

      expect(Sigil.isEnabled('over'), isTrue);
      // Underlying Core is still false
      expect(Sigil.coreOf('over')!.peek(), isFalse);
    });

    test('clearOverride restores Core value', () {
      Sigil.register('over2', false);
      Sigil.override('over2', true);
      expect(Sigil.isEnabled('over2'), isTrue);

      Sigil.clearOverride('over2');
      expect(Sigil.isEnabled('over2'), isFalse);
    });

    test('clearOverrides removes all overrides', () {
      Sigil.loadAll({'a': false, 'b': false});
      Sigil.override('a', true);
      Sigil.override('b', true);
      expect(Sigil.isEnabled('a'), isTrue);
      expect(Sigil.isEnabled('b'), isTrue);

      Sigil.clearOverrides();
      expect(Sigil.isEnabled('a'), isFalse);
      expect(Sigil.isEnabled('b'), isFalse);
    });

    test('enable throws for unregistered flag', () {
      expect(() => Sigil.enable('ghost'), throwsStateError);
    });

    test('disable throws for unregistered flag', () {
      expect(() => Sigil.disable('ghost'), throwsStateError);
    });

    test('toggle throws for unregistered flag', () {
      expect(() => Sigil.toggle('ghost'), throwsStateError);
    });

    test('set throws for unregistered flag', () {
      expect(() => Sigil.set('ghost', true), throwsStateError);
    });

    test('reset clears all flags and overrides', () {
      Sigil.loadAll({'a': true, 'b': true});
      Sigil.override('a', false);

      Sigil.reset();

      expect(Sigil.has('a'), isFalse);
      expect(Sigil.has('b'), isFalse);
      expect(Sigil.names, isEmpty);
    });

    test('override works for unregistered flag on peek', () {
      Sigil.override('unregistered', true);
      expect(Sigil.peek('unregistered'), isTrue);
    });
  });
}
