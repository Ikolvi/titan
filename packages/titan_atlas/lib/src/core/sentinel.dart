/// Sentinel — Route guards that protect Passages.
///
/// Sentinels intercept navigation and can redirect, block, or allow passage.
/// They integrate naturally with Titan's Pillar system.
///
/// ```dart
/// // Simple auth guard
/// Sentinel((path, waypoint) {
///   final auth = Titan.get<AuthPillar>();
///   if (!auth.isLoggedIn.value) return '/login';
///   return null; // Allow passage
/// })
///
/// // Guard specific paths
/// Sentinel.only(
///   paths: ['/settings', '/profile'],
///   guard: (path, waypoint) => isLoggedIn ? null : '/login',
/// )
///
/// // Async guard (e.g., check remote permissions)
/// Sentinel.async((path, waypoint) async {
///   final canAccess = await checkPermission(path);
///   return canAccess ? null : '/403';
/// })
/// ```
library;

import 'waypoint.dart';

/// Function that guards a route. Returns a redirect path, or null to allow.
typedef SentinelGuard = String? Function(String path, Waypoint waypoint);

/// Async version of [SentinelGuard].
typedef AsyncSentinelGuard = Future<String?> Function(
    String path, Waypoint waypoint);

/// **Sentinel** — A route guard that protects Passages.
///
/// Returns a redirect path to block navigation, or null to allow it.
///
/// ```dart
/// Atlas(
///   passages: [...],
///   sentinels: [
///     Sentinel((path, _) => isLoggedIn ? null : '/login'),
///   ],
/// )
/// ```
class Sentinel {
  final SentinelGuard? _syncGuard;
  final AsyncSentinelGuard? _asyncGuard;
  final Set<String>? _paths;
  final Set<String>? _excludePaths;

  /// Create a Sentinel with a synchronous guard.
  ///
  /// ```dart
  /// Sentinel((path, waypoint) {
  ///   if (path.startsWith('/admin')) {
  ///     return isAdmin ? null : '/403';
  ///   }
  ///   return null;
  /// })
  /// ```
  const Sentinel(SentinelGuard guard)
      : _syncGuard = guard,
        _asyncGuard = null,
        _paths = null,
        _excludePaths = null;

  /// Create a Sentinel that only guards specific paths.
  ///
  /// ```dart
  /// Sentinel.only(
  ///   paths: {'/settings', '/billing'},
  ///   guard: (path, _) => isLoggedIn ? null : '/login',
  /// )
  /// ```
  const Sentinel.only({
    required Set<String> paths,
    required SentinelGuard guard,
  })  : _syncGuard = guard,
        _asyncGuard = null,
        _paths = paths,
        _excludePaths = null;

  /// Create a Sentinel that guards all paths except specified ones.
  ///
  /// ```dart
  /// Sentinel.except(
  ///   paths: {'/login', '/register', '/'},
  ///   guard: (path, _) => isLoggedIn ? null : '/login',
  /// )
  /// ```
  const Sentinel.except({
    required Set<String> paths,
    required SentinelGuard guard,
  })  : _syncGuard = guard,
        _asyncGuard = null,
        _paths = null,
        _excludePaths = paths;

  /// Create a Sentinel with an async guard.
  ///
  /// ```dart
  /// Sentinel.async((path, waypoint) async {
  ///   final allowed = await api.checkAccess(path);
  ///   return allowed ? null : '/no-access';
  /// })
  /// ```
  const Sentinel.async(AsyncSentinelGuard guard)
      : _syncGuard = null,
        _asyncGuard = guard,
        _paths = null,
        _excludePaths = null;

  /// Whether this sentinel applies to the given path.
  bool appliesTo(String path) {
    if (_excludePaths != null && _excludePaths.contains(path)) return false;
    if (_paths != null) return _paths.contains(path);
    return true;
  }

  /// Evaluate this sentinel synchronously.
  /// Returns redirect path or null.
  String? evaluate(String path, Waypoint waypoint) {
    if (!appliesTo(path)) return null;
    return _syncGuard?.call(path, waypoint);
  }

  /// Evaluate this sentinel asynchronously.
  /// Returns redirect path or null.
  Future<String?> evaluateAsync(String path, Waypoint waypoint) async {
    if (!appliesTo(path)) return null;
    if (_asyncGuard != null) return _asyncGuard.call(path, waypoint);
    return _syncGuard?.call(path, waypoint);
  }

  /// Whether this sentinel has an async guard.
  bool get isAsync => _asyncGuard != null;
}
