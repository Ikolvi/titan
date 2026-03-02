/// Garrison — Authentication flow helpers for Atlas routing.
///
/// Garrison provides pre-built Sentinel factories and auth flow utilities
/// for common authentication patterns: login redirect, role-based access,
/// session expiry, and onboarding flows.
///
/// ## Why "Garrison"?
///
/// A garrison is a fortified post with guards stationed to protect it.
/// Titan's Garrison provides pre-configured Sentinels for auth workflows.
///
/// ## Usage
///
/// ```dart
/// // Simple auth guard
/// Atlas(
///   passages: [...],
///   sentinels: [
///     Garrison.authGuard(
///       isAuthenticated: () => authPillar.isLoggedIn.value,
///       loginPath: '/login',
///       publicPaths: {'/login', '/register', '/forgot-password'},
///     ),
///   ],
/// )
///
/// // Role-based access
/// Atlas(
///   passages: [...],
///   sentinels: [
///     Garrison.roleGuard(
///       getRole: () => authPillar.role.value,
///       rules: {
///         '/admin': {'admin'},
///         '/billing': {'admin', 'manager'},
///       },
///       fallbackPath: '/unauthorized',
///     ),
///   ],
/// )
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:titan/titan.dart';

import 'core_refresh.dart';
import 'sentinel.dart';

/// Pre-built authentication Sentinel factories.
///
/// Garrison eliminates boilerplate around common auth route guarding
/// patterns. Each factory returns a [Sentinel] that can be used directly
/// in Atlas configuration.
class Garrison {
  Garrison._();

  // ---------------------------------------------------------------------------
  // Auth Guard
  // ---------------------------------------------------------------------------

  /// Create a Sentinel that redirects unauthenticated users to a login page.
  ///
  /// The [isAuthenticated] callback is evaluated on each navigation.
  /// [publicPaths] are exempt from the guard. Optionally, [publicPrefixes]
  /// allows entire path segments to be public (e.g., `/public/`).
  ///
  /// When redirecting, the original path is stored in the `redirect` query
  /// parameter unless [preserveRedirect] is false.
  ///
  /// ```dart
  /// Garrison.authGuard(
  ///   isAuthenticated: () => authPillar.isLoggedIn.value,
  ///   loginPath: '/login',
  ///   publicPaths: {'/login', '/register', '/'},
  /// )
  /// ```
  static Sentinel authGuard({
    required bool Function() isAuthenticated,
    required String loginPath,
    Set<String> publicPaths = const {},
    Set<String> publicPrefixes = const {},
    bool preserveRedirect = true,
  }) {
    return Sentinel((path, waypoint) {
      // Allow public paths
      if (publicPaths.contains(path)) return null;

      // Allow public prefixes
      for (final prefix in publicPrefixes) {
        if (path.startsWith(prefix)) return null;
      }

      // Allow if authenticated
      if (isAuthenticated()) return null;

      // Redirect to login
      if (preserveRedirect && path != loginPath) {
        return '$loginPath?redirect=${Uri.encodeComponent(path)}';
      }
      return loginPath;
    });
  }

  // ---------------------------------------------------------------------------
  // Role Guard
  // ---------------------------------------------------------------------------

  /// Create a Sentinel that restricts access based on user roles.
  ///
  /// [getRole] returns the current user's role. [rules] maps path patterns
  /// to allowed role sets. Paths not in [rules] are allowed by default.
  ///
  /// ```dart
  /// Garrison.roleGuard(
  ///   getRole: () => authPillar.role.value,
  ///   rules: {
  ///     '/admin': {'admin'},
  ///     '/settings': {'admin', 'editor'},
  ///   },
  ///   fallbackPath: '/unauthorized',
  /// )
  /// ```
  static Sentinel roleGuard({
    required String Function() getRole,
    required Map<String, Set<String>> rules,
    String fallbackPath = '/unauthorized',
  }) {
    return Sentinel((path, waypoint) {
      // Find matching rule
      for (final entry in rules.entries) {
        if (path == entry.key || path.startsWith('${entry.key}/')) {
          final allowedRoles = entry.value;
          final currentRole = getRole();
          if (!allowedRoles.contains(currentRole)) {
            return fallbackPath;
          }
          return null; // Role matches
        }
      }
      return null; // No rule = allowed
    });
  }

  /// Create a Sentinel that restricts access based on multiple roles.
  ///
  /// [getRoles] returns the current user's roles as a set.
  ///
  /// ```dart
  /// Garrison.rolesGuard(
  ///   getRoles: () => authPillar.roles.value,
  ///   rules: {'/admin': {'admin', 'superadmin'}},
  /// )
  /// ```
  static Sentinel rolesGuard({
    required Set<String> Function() getRoles,
    required Map<String, Set<String>> rules,
    String fallbackPath = '/unauthorized',
  }) {
    return Sentinel((path, waypoint) {
      for (final entry in rules.entries) {
        if (path == entry.key || path.startsWith('${entry.key}/')) {
          final allowedRoles = entry.value;
          final currentRoles = getRoles();
          if (currentRoles.intersection(allowedRoles).isEmpty) {
            return fallbackPath;
          }
          return null;
        }
      }
      return null;
    });
  }

  // ---------------------------------------------------------------------------
  // Onboarding Guard
  // ---------------------------------------------------------------------------

  /// Create a Sentinel that redirects users who haven't completed onboarding.
  ///
  /// ```dart
  /// Garrison.onboardingGuard(
  ///   isOnboarded: () => userPillar.hasCompletedSetup.value,
  ///   onboardingPath: '/onboarding',
  ///   exemptPaths: {'/onboarding', '/logout'},
  /// )
  /// ```
  static Sentinel onboardingGuard({
    required bool Function() isOnboarded,
    required String onboardingPath,
    Set<String> exemptPaths = const {},
  }) {
    return Sentinel((path, waypoint) {
      if (exemptPaths.contains(path)) return null;
      if (path == onboardingPath) return null;
      if (isOnboarded()) return null;
      return onboardingPath;
    });
  }

  // ---------------------------------------------------------------------------
  // Composite Guard
  // ---------------------------------------------------------------------------

  /// Combine multiple guard conditions into a single Sentinel.
  ///
  /// Each condition is evaluated in order. The first non-null redirect wins.
  ///
  /// ```dart
  /// Garrison.composite([
  ///   (path, wp) => isLoggedIn ? null : '/login',
  ///   (path, wp) => isVerified ? null : '/verify-email',
  ///   (path, wp) => isOnboarded ? null : '/onboarding',
  /// ])
  /// ```
  static Sentinel composite(List<SentinelGuard> guards) {
    return Sentinel((path, waypoint) {
      for (final guard in guards) {
        final redirect = guard(path, waypoint);
        if (redirect != null) return redirect;
      }
      return null;
    });
  }

  /// Combine multiple guard conditions asynchronously.
  ///
  /// ```dart
  /// Garrison.compositeAsync([
  ///   (path, wp) async => await checkAuth() ? null : '/login',
  ///   (path, wp) async => await checkPermission(path) ? null : '/403',
  /// ])
  /// ```
  static Sentinel compositeAsync(List<AsyncSentinelGuard> guards) {
    return Sentinel.async((path, waypoint) async {
      for (final guard in guards) {
        final redirect = await guard(path, waypoint);
        if (redirect != null) return redirect;
      }
      return null;
    });
  }

  // ---------------------------------------------------------------------------
  // Guest-only Guard
  // ---------------------------------------------------------------------------

  /// Create a Sentinel that blocks authenticated users from guest-only pages.
  ///
  /// Use this to prevent logged-in users from accessing login/register pages.
  ///
  /// ```dart
  /// Garrison.guestOnly(
  ///   isAuthenticated: () => authPillar.isLoggedIn.value,
  ///   guestPaths: {'/login', '/register'},
  ///   redirectPath: '/dashboard',
  /// )
  /// ```
  static Sentinel guestOnly({
    required bool Function() isAuthenticated,
    required Set<String> guestPaths,
    required String redirectPath,
  }) {
    return Sentinel((path, waypoint) {
      if (!guestPaths.contains(path)) return null;
      if (isAuthenticated()) return redirectPath;
      return null;
    });
  }

  // ---------------------------------------------------------------------------
  // Refresh Auth — combined auth + guest + CoreRefresh
  // ---------------------------------------------------------------------------

  /// Create a complete reactive authentication flow in one call.
  ///
  /// Returns a [GarrisonAuth] containing both the Sentinels and the
  /// [CoreRefresh] listenable needed for fully reactive auth routing.
  ///
  /// This combines [authGuard], [guestOnly], and [CoreRefresh] into a
  /// single convenience factory — no manual wiring required.
  ///
  /// ```dart
  /// final auth = Garrison.refreshAuth(
  ///   isAuthenticated: () => authPillar.isLoggedIn.value,
  ///   cores: [authPillar.isLoggedIn],
  ///   loginPath: '/login',
  ///   guestPaths: {'/login', '/register'},
  ///   homePath: '/',
  /// );
  ///
  /// Atlas(
  ///   passages: [...],
  ///   sentinels: auth.sentinels,
  ///   refreshListenable: auth.refresh,
  /// );
  /// ```
  ///
  /// When the [cores] values change, Atlas automatically re-evaluates
  /// the Sentinels and redirects accordingly — sign-in redirects away
  /// from guest pages, sign-out redirects to login.
  static GarrisonAuth refreshAuth({
    required bool Function() isAuthenticated,
    required List<ReactiveNode> cores,
    required String loginPath,
    required String homePath,
    Set<String> publicPaths = const {},
    Set<String> publicPrefixes = const {},
    Set<String>? guestPaths,
    bool preserveRedirect = true,
  }) {
    // Build the auth guard sentinel
    final authSentinel = authGuard(
      isAuthenticated: isAuthenticated,
      loginPath: loginPath,
      publicPaths: {...publicPaths, loginPath, ...?guestPaths},
      publicPrefixes: publicPrefixes,
      preserveRedirect: preserveRedirect,
    );

    // Build sentinel list
    final sentinels = [authSentinel];

    // Add guest-only sentinel if guest paths are specified
    if (guestPaths != null && guestPaths.isNotEmpty) {
      sentinels.add(
        guestOnly(
          isAuthenticated: isAuthenticated,
          guestPaths: guestPaths,
          redirectPath: homePath,
        ),
      );
    }

    // Create the CoreRefresh bridge
    final refresh = CoreRefresh(cores);

    return GarrisonAuth._(sentinels: sentinels, refresh: refresh);
  }
}

/// The result of [Garrison.refreshAuth] — contains everything needed
/// for reactive auth routing.
///
/// Pass [sentinels] to `Atlas(sentinels:)` and [refresh] to
/// `Atlas(refreshListenable:)` for a complete reactive auth flow.
///
/// ```dart
/// final auth = Garrison.refreshAuth(...);
/// Atlas(
///   passages: [...],
///   sentinels: auth.sentinels,
///   refreshListenable: auth.refresh,
/// );
/// ```
class GarrisonAuth {
  /// The Sentinels to pass to Atlas.
  final List<Sentinel> sentinels;

  /// The [CoreRefresh] listenable to pass to Atlas's `refreshListenable`.
  final Listenable refresh;

  const GarrisonAuth._({required this.sentinels, required this.refresh});
}
