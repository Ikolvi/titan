import 'package:titan_bastion/titan_bastion.dart';

import '../models/hero.dart';
import 'questboard_pillar.dart';

/// Hero Registration Pillar — form validation with Scroll.
///
/// Demonstrates: Scroll (form fields), ScrollGroup (aggregate validation),
/// Herald (emitting hero updated event), Chronicle (logging).
class HeroRegistrationPillar extends Pillar {
  // --------------- Scroll Fields ---------------

  late final name = scroll<String>(
    '',
    validator: (v) {
      if (v.isEmpty) return 'Name is required';
      if (v.length < 2) return 'Name must be at least 2 characters';
      if (v.length > 30) return 'Name must be 30 characters or less';
      return null;
    },
    name: 'name',
  );

  late final email = scroll<String>(
    '',
    validator: (v) {
      if (v.isEmpty) return 'Email is required';
      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
      return null;
    },
    name: 'email',
  );

  late final heroClass = scroll<HeroClass>(HeroClass.scout, name: 'heroClass');

  late final bio = scroll<String>(
    '',
    validator: (v) {
      if (v.length > 200) return 'Bio must be 200 characters or less';
      return null;
    },
    name: 'bio',
  );

  // --------------- ScrollGroup ---------------

  late final form = ScrollGroup([name, email, heroClass, bio]);

  // --------------- Actions ---------------

  /// Submit the registration form.
  ///
  /// Returns `true` if the form was valid and submitted.
  bool submit() {
    form.touchAll();

    if (!form.validateAll()) {
      log.warning('Registration form has errors');
      return false;
    }

    // Build the hero from validated fields
    final hero = Hero(
      id: 'hero-${DateTime.now().millisecondsSinceEpoch}',
      name: name.value,
      email: email.value,
      heroClass: heroClass.value,
      bio: bio.value,
    );

    // Notify other Pillars
    emit(HeroUpdatedEvent(hero));
    log.info('Hero registered: ${hero.name} (${hero.heroClass.label})');

    return true;
  }

  /// Reset all form fields.
  void resetForm() {
    form.resetAll();
    log.debug('Registration form reset');
  }
}
