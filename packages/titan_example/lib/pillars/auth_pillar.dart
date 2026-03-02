import 'package:titan_argus/titan_argus.dart';

// ---------------------------------------------------------------------------
// Auth Pillar — authentication state management
// ---------------------------------------------------------------------------

/// Manages user authentication state for the Questboard app.
///
/// Extends [Argus] — the Titan auth base class — which provides:
/// - [isLoggedIn] Core signal (inherited)
/// - [authCores] for CoreRefresh (inherited)
/// - [guard] convenience factory for reactive Atlas routing
///
/// When [isLoggedIn] changes, the `CoreRefresh` bridge in main.dart
/// notifies Atlas, which re-evaluates Sentinels and redirects
/// accordingly — no manual `Atlas.reset()` calls needed.
class AuthPillar extends Argus {
  // --------------- Core State ---------------

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

  // --------------- Strikes (Argus overrides) ---------------

  /// Signs in the user with the given credentials.
  ///
  /// Implements [Argus.signIn]. After this completes, `CoreRefresh`
  /// will notify Atlas, which re-evaluates the guestOnly Sentinel
  /// and redirects from /login.
  @override
  void signIn([Map<String, dynamic>? credentials]) {
    strike(() {
      username.value = credentials?['name'] as String?;
      isLoggedIn.value = true;
    });
  }

  /// Signs out the user.
  ///
  /// Overrides [Argus.signOut]. After this completes, `CoreRefresh`
  /// will notify Atlas, which re-evaluates the authGuard Sentinel
  /// and redirects to /login.
  @override
  void signOut() {
    strike(() {
      isLoggedIn.value = false;
      username.value = null;
    });
  }

  /// Convenience method for sign in with a hero name.
  void signInAs(String name) => signIn({'name': name});
}
