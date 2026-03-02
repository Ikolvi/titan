/// Argus — Authentication state management Pillar.
///
/// Named after Argus Panoptes, the all-seeing guardian of Greek mythology,
/// [Argus] provides a Pillar base class for managing authentication state
/// with reactive signals that integrate with Atlas routing via [CoreRefresh]
/// and [Garrison].
///
/// ## Why Argus?
///
/// Argus Panoptes (the "all-seeing") was the watchful guardian who never
/// slept, with a hundred eyes always keeping vigil. Titan's Argus watches
/// over your app's authentication state, automatically triggering route
/// re-evaluation when auth changes.
///
/// ## Usage
///
/// ```dart
/// class AuthPillar extends Argus {
///   late final username = core<String?>(null);
///   late final role = core<String?>('user');
///
///   // Include role in auth signals for role-based route guards
///   @override
///   List<ReactiveNode> get authCores => [isLoggedIn, role];
///
///   @override
///   void signIn([Map<String, dynamic>? credentials]) {
///     strike(() {
///       username.value = credentials?['name'] as String?;
///       isLoggedIn.value = true;
///     });
///   }
///
///   @override
///   void signOut() {
///     strike(() {
///       isLoggedIn.value = false;
///       username.value = null;
///       role.value = null;
///     });
///   }
/// }
/// ```
///
/// ## Atlas Integration
///
/// Use [guard] to create a complete reactive auth flow in one call:
///
/// ```dart
/// final auth = Titan.get<AuthPillar>();
/// final garrisonAuth = auth.guard(
///   loginPath: '/login',
///   homePath: '/',
///   guestPaths: {'/login', '/register'},
/// );
///
/// Atlas(
///   passages: [...],
///   sentinels: garrisonAuth.sentinels,
///   refreshListenable: garrisonAuth.refresh,
/// );
/// ```
library;

import 'package:titan/titan.dart';
import 'package:titan_atlas/titan_atlas.dart';

import 'core_refresh.dart';
import 'garrison.dart';

/// **Argus** — Authentication state management base class.
///
/// Extend [Argus] to create an authentication state manager that
/// integrates with Atlas routing via [CoreRefresh] and [Garrison].
///
/// Provides:
/// - [isLoggedIn] — a reactive Core signal for auth state
/// - [authCores] — signals that trigger route re-evaluation
/// - [signIn] / [signOut] — abstract lifecycle methods
/// - [guard] — one-call factory for reactive auth routing
///
/// ```dart
/// class AuthPillar extends Argus {
///   late final username = core<String?>(null);
///
///   @override
///   void signIn([Map<String, dynamic>? credentials]) {
///     strike(() {
///       username.value = credentials?['name'] as String?;
///       isLoggedIn.value = true;
///     });
///   }
///
///   @override
///   void signOut() {
///     strike(() {
///       isLoggedIn.value = false;
///       username.value = null;
///     });
///   }
/// }
/// ```
abstract class Argus extends Pillar {
  /// Whether the user is currently authenticated.
  ///
  /// This [Core] signal integrates with [Garrison] and [CoreRefresh]
  /// for automatic route re-evaluation when auth state changes.
  late final isLoggedIn = core(false, name: 'isLoggedIn');

  /// The reactive nodes that trigger route re-evaluation.
  ///
  /// Override to include additional signals (e.g., `role`, `permissions`).
  /// By default, returns `[isLoggedIn]`.
  ///
  /// ```dart
  /// @override
  /// List<ReactiveNode> get authCores => [isLoggedIn, role];
  /// ```
  List<ReactiveNode> get authCores => [isLoggedIn];

  /// Sign in the user.
  ///
  /// Override to set [isLoggedIn] to `true` and any additional auth state.
  /// The optional [credentials] map provides login data.
  ///
  /// ```dart
  /// @override
  /// void signIn([Map<String, dynamic>? credentials]) {
  ///   strike(() {
  ///     username.value = credentials?['name'] as String?;
  ///     isLoggedIn.value = true;
  ///   });
  /// }
  /// ```
  void signIn([Map<String, dynamic>? credentials]);

  /// Sign out the user.
  ///
  /// Override to clear auth state. Default implementation sets
  /// [isLoggedIn] to `false`.
  void signOut() {
    isLoggedIn.value = false;
  }

  /// Creates a [GarrisonAuth] for reactive auth routing.
  ///
  /// Combines [Garrison.authGuard], [Garrison.guestOnly], and
  /// [CoreRefresh] into a single configuration for Atlas.
  ///
  /// ```dart
  /// final auth = Titan.get<AuthPillar>();
  /// final garrisonAuth = auth.guard(
  ///   loginPath: '/login',
  ///   homePath: '/',
  ///   guestPaths: {'/login', '/register'},
  /// );
  ///
  /// Atlas(
  ///   sentinels: garrisonAuth.sentinels,
  ///   refreshListenable: garrisonAuth.refresh,
  /// );
  /// ```
  GarrisonAuth guard({
    required String loginPath,
    required String homePath,
    Set<String> publicPaths = const {},
    Set<String> publicPrefixes = const {},
    Set<String>? guestPaths,
    bool preserveRedirect = true,
  }) {
    return Garrison.refreshAuth(
      isAuthenticated: () => isLoggedIn.value,
      cores: authCores,
      loginPath: loginPath,
      homePath: homePath,
      publicPaths: publicPaths,
      publicPrefixes: publicPrefixes,
      guestPaths: guestPaths,
      preserveRedirect: preserveRedirect,
    );
  }
}
