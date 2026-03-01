import 'package:titan/titan.dart';

import '../core/atlas_observer.dart';
import '../core/waypoint.dart';

// ---------------------------------------------------------------------------
// Atlas Herald Events — emitted during navigation lifecycle
// ---------------------------------------------------------------------------

/// Emitted when a route change occurs (navigate, pop, replace, reset).
///
/// ```dart
/// Herald.on<AtlasRouteChanged>((event) {
///   analytics.trackPageView(event.to.path);
/// });
/// ```
class AtlasRouteChanged {
  /// The waypoint before the change (null for reset with no history).
  final Waypoint? from;

  /// The waypoint after the change.
  final Waypoint to;

  /// The type of navigation that triggered this event.
  final AtlasNavigationType type;

  /// Creates an [AtlasRouteChanged] event.
  const AtlasRouteChanged({
    this.from,
    required this.to,
    required this.type,
  });

  @override
  String toString() =>
      'AtlasRouteChanged(${type.name}: ${from?.path ?? 'none'} → ${to.path})';
}

/// The type of navigation action.
enum AtlasNavigationType {
  /// Forward navigation via `Atlas.to()`.
  push,

  /// Backward navigation via `Atlas.back()`.
  pop,

  /// Replace current route via `Atlas.replace()`.
  replace,

  /// Reset stack via `Atlas.reset()`.
  reset,
}

/// Emitted when a Sentinel (route guard) redirects navigation.
///
/// ```dart
/// Herald.on<AtlasGuardRedirect>((event) {
///   log.warning('Guard redirected ${event.originalPath} → ${event.redirectPath}');
/// });
/// ```
class AtlasGuardRedirect {
  /// The originally requested path.
  final String originalPath;

  /// The path the guard redirected to.
  final String redirectPath;

  /// Creates an [AtlasGuardRedirect] event.
  const AtlasGuardRedirect({
    required this.originalPath,
    required this.redirectPath,
  });

  @override
  String toString() =>
      'AtlasGuardRedirect($originalPath → $redirectPath)';
}

/// Emitted when a Drift (global redirect) redirects navigation.
///
/// ```dart
/// Herald.on<AtlasDriftRedirect>((event) {
///   log.info('Drift: ${event.originalPath} → ${event.redirectPath}');
/// });
/// ```
class AtlasDriftRedirect {
  /// The originally requested path.
  final String originalPath;

  /// The path the drift redirected to.
  final String redirectPath;

  /// Creates an [AtlasDriftRedirect] event.
  const AtlasDriftRedirect({
    required this.originalPath,
    required this.redirectPath,
  });

  @override
  String toString() =>
      'AtlasDriftRedirect($originalPath → $redirectPath)';
}

/// Emitted when no Passage matches the requested path (404).
///
/// ```dart
/// Herald.on<AtlasRouteNotFound>((event) {
///   log.error('Route not found: ${event.path}');
///   analytics.track('404', {'path': event.path});
/// });
/// ```
class AtlasRouteNotFound {
  /// The path that had no matching Passage.
  final String path;

  /// Creates an [AtlasRouteNotFound] event.
  const AtlasRouteNotFound({required this.path});

  @override
  String toString() => 'AtlasRouteNotFound($path)';
}

// ---------------------------------------------------------------------------
// HeraldAtlasObserver — Bridges Atlas lifecycle to Herald events
// ---------------------------------------------------------------------------

/// An [AtlasObserver] that emits [Herald] events for all navigation actions.
///
/// Add this to your Atlas configuration to broadcast route lifecycle events
/// across your entire application via Herald:
///
/// ```dart
/// Atlas(
///   passages: [...],
///   observers: [HeraldAtlasObserver()],
/// );
/// ```
///
/// Then listen anywhere:
///
/// ```dart
/// class AnalyticsPillar extends Pillar {
///   @override
///   void onInit() {
///     listen<AtlasRouteChanged>((event) {
///       analytics.trackPageView(event.to.path);
///     });
///
///     listen<AtlasRouteNotFound>((event) {
///       analytics.track('404', {'path': event.path});
///     });
///   }
/// }
/// ```
class HeraldAtlasObserver extends AtlasObserver {
  // We import Herald dynamically to avoid hard coupling within titan_atlas.
  // Since titan_atlas already depends on `titan`, Herald is available.

  @override
  void onNavigate(Waypoint from, Waypoint to) {
    _emit(AtlasRouteChanged(
      from: from,
      to: to,
      type: AtlasNavigationType.push,
    ));
  }

  @override
  void onReplace(Waypoint from, Waypoint to) {
    _emit(AtlasRouteChanged(
      from: from,
      to: to,
      type: AtlasNavigationType.replace,
    ));
  }

  @override
  void onPop(Waypoint from, Waypoint to) {
    _emit(AtlasRouteChanged(
      from: from,
      to: to,
      type: AtlasNavigationType.pop,
    ));
  }

  @override
  void onReset(Waypoint to) {
    _emit(AtlasRouteChanged(
      to: to,
      type: AtlasNavigationType.reset,
    ));
  }

  @override
  void onGuardRedirect(String originalPath, String redirectPath) {
    _emit(AtlasGuardRedirect(
      originalPath: originalPath,
      redirectPath: redirectPath,
    ));
  }

  @override
  void onDriftRedirect(String originalPath, String redirectPath) {
    _emit(AtlasDriftRedirect(
      originalPath: originalPath,
      redirectPath: redirectPath,
    ));
  }

  @override
  void onNotFound(String path) {
    _emit(AtlasRouteNotFound(path: path));
  }

  /// Emit via Herald.
  void _emit<T>(T event) {
    Herald.emit<T>(event);
  }
}
