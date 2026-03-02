/// CoreRefresh — bridges Titan's reactive signals to Flutter's Listenable.
///
/// Creates a [ChangeNotifier] that fires whenever any of the provided
/// reactive [Core] values (or any [ReactiveNode]) changes. Use with
/// Atlas's `refreshListenable` parameter to trigger automatic re-evaluation
/// of Sentinels and Drift when auth or other state changes.
///
/// ## Why CoreRefresh?
///
/// Atlas Sentinels normally only evaluate during navigation. When auth
/// state changes (e.g., sign-in or token expiry), Sentinels aren't
/// automatically re-evaluated. `CoreRefresh` bridges this gap by
/// converting Titan's reactive signals into a Flutter [Listenable] that
/// Atlas can observe.
///
/// ## Usage
///
/// ```dart
/// class AuthPillar extends Argus {
///   late final role = core<String?>(null);
///
///   @override
///   List<ReactiveNode> get authCores => [isLoggedIn, role];
///
///   @override
///   void signIn([Map<String, dynamic>? credentials]) {
///     strike(() {
///       isLoggedIn.value = true;
///     });
///   }
/// }
///
/// final authPillar = Titan.get<AuthPillar>();
///
/// final atlas = Atlas(
///   passages: [
///     Passage('/', (_) => HomeScreen()),
///     Passage('/login', (_) => LoginScreen()),
///   ],
///   sentinels: [
///     Garrison.authGuard(
///       isAuthenticated: () => authPillar.isLoggedIn.value,
///       loginPath: '/login',
///       publicPaths: {'/login', '/register'},
///     ),
///     Garrison.guestOnly(
///       isAuthenticated: () => authPillar.isLoggedIn.value,
///       redirectPath: '/',
///       guestPaths: {'/login', '/register'},
///     ),
///   ],
///   // Re-evaluate Sentinels when auth state changes
///   refreshListenable: CoreRefresh(authPillar.authCores),
/// );
/// ```
///
/// ## Multiple Signals
///
/// ```dart
/// // Re-evaluate when auth OR role changes
/// CoreRefresh([authPillar.isLoggedIn, authPillar.role])
/// ```
///
/// ## Lifecycle
///
/// `CoreRefresh` is disposed automatically when Atlas is replaced by a
/// new instance. If you create one outside of Atlas, call [dispose] when
/// it is no longer needed to prevent memory leaks.
library;

import 'package:flutter/foundation.dart';
import 'package:titan/titan.dart';

/// **CoreRefresh** — Converts Titan reactive signals to a Flutter
/// [Listenable] for use with Atlas's `refreshListenable`.
///
/// Listens to one or more [ReactiveNode] values (typically [Core] or
/// [Derived]) and fires [notifyListeners] whenever any of them change.
///
/// ```dart
/// final refresh = CoreRefresh([authPillar.isLoggedIn]);
/// Atlas(refreshListenable: refresh, ...);
/// ```
class CoreRefresh extends ChangeNotifier {
  final List<void Function()> _unsubscribers = [];

  /// Creates a [CoreRefresh] that notifies listeners when any of the
  /// provided [cores] change.
  ///
  /// Each element must be a [ReactiveNode] — typically a [Core] or
  /// [Derived] from a Pillar.
  ///
  /// ```dart
  /// CoreRefresh([authPillar.isLoggedIn, authPillar.role])
  /// ```
  CoreRefresh(List<ReactiveNode> cores) {
    for (final core in cores) {
      void listener() => notifyListeners();
      core.addListener(listener);
      _unsubscribers.add(() => core.removeListener(listener));
    }
  }

  @override
  void dispose() {
    for (final unsub in _unsubscribers) {
      unsub();
    }
    _unsubscribers.clear();
    super.dispose();
  }
}
