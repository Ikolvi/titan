import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Scroll — Form Field Management', () {
    late Scroll<String> field;

    setUp(() {
      field = Scroll<String>(
        '',
        validator: (v) => v.isEmpty ? 'Required' : null,
      );
    });

    tearDown(() {
      field.dispose();
      for (final node in field.managedNodes) {
        node.dispose();
      }
    });

    test('initial value is set', () {
      expect(field.value, '');
    });

    test('isDirty is false initially', () {
      expect(field.isDirty, false);
    });

    test('isPristine is true initially', () {
      expect(field.isPristine, true);
    });

    test('isDirty becomes true after value change', () {
      field.value = 'hello';
      expect(field.isDirty, true);
      expect(field.isPristine, false);
    });

    test('isTouched is false initially', () {
      expect(field.isTouched, false);
    });

    test('touch() sets isTouched to true', () {
      field.touch();
      expect(field.isTouched, true);
    });

    test('validate() returns true when valid', () {
      field.value = 'hello';
      expect(field.validate(), true);
      expect(field.isValid, true);
      expect(field.error, isNull);
    });

    test('validate() returns false when invalid', () {
      expect(field.validate(), false);
      expect(field.isValid, false);
      expect(field.error, 'Required');
    });

    test('validate() does not auto-touch the field', () {
      field.validate();
      expect(field.isTouched, false);
    });

    test('setError() sets a manual error', () {
      field.setError('Custom error');
      expect(field.error, 'Custom error');
      expect(field.isValid, false);
    });

    test('clearError() clears the error', () {
      field.setError('Something');
      field.clearError();
      expect(field.error, isNull);
      expect(field.isValid, true);
    });

    test('reset() restores initial value and clears state', () {
      field.value = 'changed';
      field.touch();
      field.validate();
      field.reset();

      expect(field.value, '');
      expect(field.isDirty, false);
      expect(field.isTouched, false);
      expect(field.error, isNull);
    });

    test('works without validator', () {
      final noValidator = Scroll<int>(42);
      expect(noValidator.validate(), true);
      expect(noValidator.isValid, true);
      noValidator.dispose();
      for (final node in noValidator.managedNodes) {
        node.dispose();
      }
    });

    test('managedNodes returns error and touched nodes', () {
      expect(field.managedNodes.length, 2);
    });
  });

  group('ScrollGroup — Form Group Management', () {
    late Scroll<String> name;
    late Scroll<String> email;
    late ScrollGroup group;

    setUp(() {
      name = Scroll<String>(
        '',
        validator: (v) => v.isEmpty ? 'Required' : null,
      );
      email = Scroll<String>(
        '',
        validator: (v) => v.contains('@') ? null : 'Invalid email',
      );
      group = ScrollGroup([name, email]);
    });

    tearDown(() {
      name.dispose();
      email.dispose();
      for (final node in name.managedNodes) {
        node.dispose();
      }
      for (final node in email.managedNodes) {
        node.dispose();
      }
    });

    test('isValid returns false when any field is invalid', () {
      expect(group.validateAll(), false);
      expect(group.isValid, false);
    });

    test('isValid returns true when all fields are valid', () {
      name.value = 'Kael';
      email.value = 'kael@titan.io';
      expect(group.validateAll(), true);
      expect(group.isValid, true);
    });

    test('isDirty returns true when any field is dirty', () {
      name.value = 'Kael';
      expect(group.isDirty, true);
    });

    test('isPristine returns true when no fields are dirty', () {
      expect(group.isPristine, true);
    });

    test('isTouched returns true when any field is touched', () {
      email.touch();
      expect(group.isTouched, true);
    });

    test('touchAll() touches all fields', () {
      group.touchAll();
      expect(name.isTouched, true);
      expect(email.isTouched, true);
    });

    test('resetAll() resets all fields', () {
      name.value = 'Kael';
      email.value = 'kael@titan.io';
      group.touchAll();
      group.validateAll();

      group.resetAll();

      expect(name.value, '');
      expect(email.value, '');
      expect(name.isTouched, false);
      expect(email.isTouched, false);
    });

    test('clearAllErrors() clears errors on all fields', () {
      group.validateAll(); // Both fields invalid — triggers errors
      expect(name.error, isNotNull);
      expect(email.error, isNotNull);

      group.clearAllErrors();
      expect(name.error, isNull);
      expect(email.error, isNull);
    });

    test('invalidFields returns only fields with errors', () {
      group.validateAll(); // Both empty, both invalid
      expect(group.invalidFields.length, 2);

      name.value = 'Kael';
      group.validateAll();
      expect(group.invalidFields.length, 1);
      expect(group.invalidFields.first, same(email));
    });

    test('fieldCount returns correct count', () {
      expect(group.fieldCount, 2);
    });
  });

  group('Scroll — Pillar integration', () {
    late _FormPillar pillar;

    setUp(() {
      pillar = _FormPillar();
      pillar.initialize();
    });

    tearDown(() {
      pillar.dispose();
      Titan.reset();
    });

    test('scroll() creates managed Scroll field', () {
      expect(pillar.username.value, '');
      expect(pillar.username.isValid, true); // Not validated yet
    });

    test('scroll fields track dirty state', () {
      pillar.setUsername('Kael');
      expect(pillar.username.isDirty, true);
    });

    test('scroll fields validate', () {
      expect(pillar.username.validate(), false);
      expect(pillar.username.error, 'Required');

      pillar.setUsername('Kael');
      expect(pillar.username.validate(), true);
    });

    test('Pillar disposal cleans up scroll nodes', () {
      pillar.dispose();
      // Should not throw — nodes are properly cleaned up
    });
  });
}

class _FormPillar extends Pillar {
  late final username = scroll<String>(
    '',
    validator: (v) => v.isEmpty ? 'Required' : null,
    name: 'username',
  );

  void setUsername(String value) => strike(() => username.value = value);
}
