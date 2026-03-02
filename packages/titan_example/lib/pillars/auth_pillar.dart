import 'package:titan_bastion/titan_bastion.dart';

// ---------------------------------------------------------------------------
// Auth Pillar — authentication state management
// ---------------------------------------------------------------------------

/// Manages user authentication state for the Questboard app.
///
/// Demonstrates: Core, Derived, CoreRefresh integration with Atlas.
///
/// When [isLoggedIn] changes, the `CoreRefresh` bridge in main.dart
/// notifies Atlas, which re-evaluates Sentinels and redirects
/// accordingly — no manual `Atlas.reset()` calls needed.
class AuthPillar extends Pillar {
  // --------------- Core State ---------------

  /// Whether the user is currently authenticated.
  late final isLoggedIn = core(false, name: 'isLoggedIn');

  /// The authenticated user's display name.
  late final username = core<String?>(null, name: 'username');

  // --------------- Derived State ---------------

  /// A greeting message for the authenticated user.
  late final greeting = derived(() {
    final name = username.value;
    if (name == null) return 'Welcome, stranger';
    return 'Welcome, $name';
  }, name: 'greeting');

  // --------------- Lifecycle ---------------

  @override
  void onInit() {
    super.onInit();

    // Log auth state changes
    watch(() {
      final loggedIn = isLoggedIn.value;
      log.info('Auth state changed: ${loggedIn ? "signed in" : "signed out"}');
    }, immediate: false);
  }

  // --------------- Strikes ---------------

  /// Signs in the user with the given [name].
  ///
  /// After this completes, `CoreRefresh` will notify Atlas, which
  /// re-evaluates the guestOnly Sentinel and redirects from /login.
  void signIn(String name) {
    strike(() {
      username.value = name;
      isLoggedIn.value = true;
    });
  }

  /// Signs out the user.
  ///
  /// After this completes, `CoreRefresh` will notify Atlas, which
  /// re-evaluates the authGuard Sentinel and redirects to /login.
  void signOut() {
    strike(() {
      isLoggedIn.value = false;
      username.value = null;
    });
  }
}
